//! Filesystem and path helpers mirroring assorted Bash utilities
//! (`deleteDirChmod777`, `realpath -m`, `checkPathIsInsideOf`, ...).

use std::io;
use std::os::unix::fs::PermissionsExt;
use std::path::{Component, Path, PathBuf};
use std::process::Command;

use crate::args::cyan;
use crate::constants::WORKING_DIR_PARAM_PATTERN;
use crate::error::{Exit, GtResult};
use crate::log::{log_error, log_warning};

/// Lexically normalises `path` to an absolute path without requiring it to
/// exist -- the behaviour relied upon from `readlink -m` / `realpath -m`.
///
/// Relative paths are resolved against the current working directory; `.` and
/// `..` components are collapsed lexically. (Symlinks in existing prefixes are
/// not resolved; this matches what the `remote` command needs.)
pub fn normalize_path(path: &Path) -> io::Result<PathBuf> {
    let absolute = if path.is_absolute() {
        path.to_path_buf()
    } else {
        std::env::current_dir()?.join(path)
    };

    let mut normalized = PathBuf::new();
    for component in absolute.components() {
        match component {
            Component::Prefix(p) => normalized.push(p.as_os_str()),
            Component::RootDir => normalized.push(Component::RootDir.as_os_str()),
            Component::CurDir => {}
            Component::ParentDir => {
                normalized.pop();
            }
            Component::Normal(part) => normalized.push(part),
        }
    }
    Ok(normalized)
}

/// `checkPathIsInsideOf`: true if `path` resolves to a location inside `root`.
///
/// Mirrors the Bash quirk of comparing the normalised paths as raw strings with
/// a prefix check.
pub fn path_is_inside_of(path: &Path, root: &Path) -> io::Result<bool> {
    let path_abs = normalize_path(path)?;
    let root_abs = normalize_path(root)?;
    Ok(path_abs
        .to_string_lossy()
        .starts_with(root_abs.to_string_lossy().as_ref()))
}

/// `exitIfPathNamedIsOutsideOf`: fail (exit 1) if `path` is not inside `root`.
///
/// `name`/`path` are reported verbatim (the user-supplied values), `root` is the
/// absolute current directory.
pub fn exit_if_path_named_is_outside_of(path: &str, name: &str, root: &Path) -> GtResult {
    let inside = path_is_inside_of(Path::new(path), root).map_err(|_| Exit(1))?;
    if !inside {
        log_error(&format!(
            "the given {} {path} is not inside of {}",
            cyan(name),
            root.display()
        ));
        return Err(Exit(1));
    }
    Ok(())
}

/// `checkWorkingDirExists`: returns whether the working dir exists, logging the
/// same error + hint the Bash helper prints when it does not.
pub fn check_working_dir_exists(working_dir_absolute: &Path) -> bool {
    if !working_dir_absolute.is_dir() {
        log_error(&format!(
            "working directory {} does not exist",
            cyan(&working_dir_absolute.display().to_string())
        ));
        eprintln!(
            "Check for typos and/or use {} to specify another",
            WORKING_DIR_PARAM_PATTERN.join("|")
        );
        return false;
    }
    true
}

/// `exitIfWorkingDirDoesNotExist`: like [`check_working_dir_exists`] but exits 9.
pub fn exit_if_working_dir_does_not_exist(working_dir_absolute: &Path) -> GtResult {
    if !check_working_dir_exists(working_dir_absolute) {
        return Err(Exit(9));
    }
    Ok(())
}

/// `deleteDirChmod777`: best-effort `chmod -R 777` then remove the directory.
pub fn delete_dir_chmod_777(dir: &Path) -> io::Result<()> {
    // e.g. files in .git are write-protected; relax permissions first (ignore failures).
    let _ = chmod_recursive(dir, 0o777);
    std::fs::remove_dir_all(dir)
}

fn chmod_recursive(path: &Path, mode: u32) -> io::Result<()> {
    let metadata = std::fs::symlink_metadata(path)?;
    if !metadata.file_type().is_symlink() {
        let mut perms = metadata.permissions();
        perms.set_mode(mode);
        let _ = std::fs::set_permissions(path, perms);
    }
    if metadata.is_dir() {
        for entry in std::fs::read_dir(path)? {
            let entry = entry?;
            chmod_recursive(&entry.path(), mode)?;
        }
    }
    Ok(())
}

/// Returns the current directory or fails (exit 1) like the Bash `die` call.
pub fn current_dir() -> Result<PathBuf, Exit> {
    std::env::current_dir().map_err(|_| {
        log_error("could not determine currentDir, maybe it does not exist anymore?");
        Exit(1)
    })
}

/// `sha512sum <file> | cut -d " " -f 1`: returns the hex digest.
pub fn sha512sum(path: &Path) -> Result<String, Exit> {
    let output = Command::new("sha512sum").arg(path).output();
    match output {
        Ok(o) if o.status.success() => {
            let s = String::from_utf8_lossy(&o.stdout);
            Ok(s.split_whitespace().next().unwrap_or("").to_string())
        }
        Ok(o) => {
            log_error(&format!(
                "sha512sum failed for {}: {}",
                path.display(),
                String::from_utf8_lossy(&o.stderr)
            ));
            Err(Exit(1))
        }
        Err(e) => {
            log_error(&format!("could not run sha512sum for {}: {e}", path.display()));
            Err(Exit(1))
        }
    }
}

/// Timestamp in milliseconds (best effort; falls back to seconds*1000).
pub fn timestamp_in_ms() -> u128 {
    if let Ok(o) = Command::new("date").args(["+%s%N"]).output() {
        if o.status.success() {
            let s = String::from_utf8_lossy(&o.stdout).trim().to_string();
            if let Ok(v) = s.parse::<u128>() {
                return v / 1_000_000; // nanos → millis
            }
        }
    }
    // fallback: seconds * 1000
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis())
        .unwrap_or(0)
}

/// Elapsed seconds as a string since `start_ms`. Returns the placeholder if
/// timestamps are unavailable.
pub fn elapsed_seconds(start_ms: u128) -> String {
    let now = timestamp_in_ms();
    if now >= start_ms {
        let elapsed = (now - start_ms) as f64 / 1000.0;
        format!("{elapsed:.2}")
    } else {
        "<could not determine elapsed time>".to_string()
    }
}

/// A simple char-diff display (mirrors `gitDiffChars`).
pub fn simple_diff_chars(old: &str, new: &str) {
    let max_len = old.chars().count().max(new.chars().count());
    let old_chars: Vec<char> = old.chars().collect();
    let new_chars: Vec<char> = new.chars().collect();
    let mut added = String::new();
    let mut removed = String::new();
    for i in 0..max_len {
        let old_c = old_chars.get(i);
        let new_c = new_chars.get(i);
        match (old_c, new_c) {
            (Some(a), Some(b)) if a == b => {
                added.push(*a);
                removed.push(*a);
            }
            (Some(a), Some(b)) => {
                added.push(*b);
                removed.push(*a);
            }
            (Some(a), None) => {
                removed.push(*a);
            }
            (None, Some(b)) => {
                added.push(*b);
            }
            (None, None) => {}
        }
    }
    if !removed.is_empty() || !added.is_empty() {
        eprintln!("diff-chars:");
        eprintln!("  {removed}");
        eprintln!("  {added}");
    }
}

/// `gt_pull_cleanupRepo`: remove all top-level directories inside `repo` except `.git`.
pub fn cleanup_repo(repo: &Path) {
    if let Ok(entries) = std::fs::read_dir(repo) {
        for entry in entries.flatten() {
            let path = entry.path();
            if path.is_dir() {
                let name = path.file_name().and_then(|n| n.to_str());
                if name != Some(".git") {
                    let _ = delete_dir_chmod_777(&path);
                }
            }
        }
    }
}

/// A scope-guard struct that cleans the repo on drop.
pub struct RepoCleanup<'a> {
    pub repo: &'a Path,
    pub active: bool,
}

impl<'a> RepoCleanup<'a> {
    pub fn new(repo: &'a Path) -> Self {
        RepoCleanup { repo, active: true }
    }
    pub fn disable(&mut self) {
        self.active = false;
    }
}

impl Drop for RepoCleanup<'_> {
    fn drop(&mut self) {
        if self.active {
            cleanup_repo(self.repo);
        }
    }
}

/// Check that the remote directory exists; exits 9 if not.
pub fn exit_if_remote_dir_does_not_exist(working_dir: &Path, remote: &str) -> GtResult {
    let remote_dir = working_dir.join("remotes").join(remote);
    if !remote_dir.is_dir() {
        log_error(&format!("remote {} does not exist, check for typos.", cyan(remote)));
        log_warning(&format!("Following the remotes which exist (if any):"));
        if let Ok(entries) = std::fs::read_dir(working_dir.join("remotes")) {
            for entry in entries.flatten() {
                if entry.path().is_dir() {
                    if let Some(name) = entry.file_name().to_str() {
                        eprintln!("{name}");
                    }
                }
            }
        }
        return Err(Exit(9));
    }
    Ok(())
}

/// Shell out to `realpath --relative-to=<base> <path>`.
pub fn realpath_relative_to(path: &Path, base: &Path) -> Result<PathBuf, Exit> {
    let output = Command::new("realpath")
        .arg(format!("--relative-to={}", base.display()))
        .arg(path)
        .output();
    match output {
        Ok(o) if o.status.success() => {
            let s = String::from_utf8_lossy(&o.stdout).trim().to_string();
            Ok(Path::new(&s).to_path_buf())
        }
        Ok(o) => {
            log_error(&format!(
                "realpath --relative-to failed for {}: {}",
                path.display(),
                String::from_utf8_lossy(&o.stderr)
            ));
            Err(Exit(1))
        }
        Err(e) => {
            log_error(&format!("could not run realpath for {}: {e}", path.display()));
            Err(Exit(1))
        }
    }
}

/// Read a `pull.args` file into a `Vec<String>` usable by `parse_arguments`.
pub fn read_pull_args(path: &Path) -> Vec<String> {
    let mut args = Vec::new();
    let content = match std::fs::read_to_string(path) {
        Ok(c) => c,
        Err(_) => return args,
    };
    for line in content.lines() {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with('#') {
            continue;
        }
        // pull.args lines are shell-quoted argument pairs, e.g.:
        // --directory "lib/myremote"
        // We need to split into tokens respecting quotes.
        // Simple approach: split by whitespace, then strip quotes.
        let mut tokens = Vec::new();
        let mut current = String::new();
        let mut in_quotes = false;
        for ch in trimmed.chars() {
            if ch == '"' {
                if in_quotes {
                    tokens.push(current.clone());
                    current.clear();
                    in_quotes = false;
                } else {
                    if !current.is_empty() {
                        tokens.push(current.clone());
                        current.clear();
                    }
                    in_quotes = true;
                }
            } else if ch.is_whitespace() && !in_quotes {
                if !current.is_empty() {
                    tokens.push(current.clone());
                    current.clear();
                }
            } else {
                current.push(ch);
            }
        }
        if !current.is_empty() {
            tokens.push(current);
        }
        for t in tokens {
            args.push(t);
        }
    }
    args
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn normalize_collapses_dot_and_dotdot() {
        let p = normalize_path(Path::new("/a/b/../c/./d")).unwrap();
        assert_eq!(p, PathBuf::from("/a/c/d"));
    }

    #[test]
    fn normalize_makes_relative_absolute() {
        let p = normalize_path(Path::new("foo/bar")).unwrap();
        assert!(p.is_absolute());
        assert!(p.ends_with("foo/bar"));
    }

    #[test]
    fn inside_of_uses_prefix_semantics() {
        assert!(path_is_inside_of(Path::new("/root/a/b"), Path::new("/root")).unwrap());
        assert!(path_is_inside_of(Path::new("/root"), Path::new("/root")).unwrap());
        assert!(!path_is_inside_of(Path::new("/other"), Path::new("/root")).unwrap());
        // the Bash quirk: a raw string prefix counts as "inside"
        assert!(path_is_inside_of(Path::new("/rootx"), Path::new("/root")).unwrap());
    }
}
