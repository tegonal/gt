//! Filesystem and path helpers mirroring assorted Bash utilities
//! (`deleteDirChmod777`, `realpath -m`, `checkPathIsInsideOf`, ...).

use std::io;
use std::os::unix::fs::PermissionsExt;
use std::path::{Component, Path, PathBuf};

use crate::args::cyan;
use crate::constants::WORKING_DIR_PARAM_PATTERN;
use crate::error::{Exit, GtResult};
use crate::log::log_error;

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
