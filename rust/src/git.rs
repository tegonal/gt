//! Thin wrappers around the `git` command line tool.
//!
//! The original Bash implementation shells out to `git`; we do the same to keep
//! behaviour identical (instead of re-implementing git in Rust).

use std::io::Write;
use std::path::Path;
use std::process::Command;

use crate::args::cyan;
use crate::die;
use crate::error::GtResult;
use crate::log::log_warning;

/// `initialiseGitDir`: create the repo directory and `git init` it.
pub fn initialise_git_dir(repo: &Path) -> GtResult {
    if std::fs::create_dir_all(repo).is_err() {
        die!("could not create the repo at {}", repo.display());
    }
    let git_dir = repo.join(".git");
    let status = Command::new("git")
        .arg(format!("--git-dir={}", git_dir.display()))
        .arg("init")
        .status();
    match status {
        Ok(s) if s.success() => Ok(()),
        _ => die!("could not git init the repo at {}", repo.display()),
    }
}

/// `git -C <repo> remote add <remote> <url>`.
pub fn remote_add(repo: &Path, remote: &str, url: &str) -> GtResult {
    let status = Command::new("git")
        .arg("-C")
        .arg(repo)
        .args(["remote", "add", remote, url])
        .status();
    match status {
        Ok(s) if s.success() => Ok(()),
        _ => die!("was not able to add remote {} with url {}", cyan(remote), url),
    }
}

/// `determineDefaultBranch`: resolve the remote's default branch via
/// `git ls-remote --symref <remote> HEAD`, falling back to `main`.
pub fn determine_default_branch(repo: &Path, remote: &str) -> String {
    let git_dir = repo.join(".git");
    let output = Command::new("git")
        .arg(format!("--git-dir={}", git_dir.display()))
        .args(["ls-remote", "--symref", remote, "HEAD"])
        .output();

    if let Ok(out) = output {
        if out.status.success() {
            let stdout = String::from_utf8_lossy(&out.stdout);
            for line in stdout.lines() {
                // match: "ref: refs/heads/<branch>\tHEAD"
                if let Some(rest) = line.strip_prefix("ref: refs/heads/") {
                    if let Some(branch) = rest.strip_suffix("\tHEAD") {
                        if !branch.is_empty() {
                            return branch.to_string();
                        }
                    }
                }
            }
        }
    }

    log_warning(&format!(
        "was not able to determine default branch for remote {}, going to use main",
        cyan(remote)
    ));
    "main".to_string()
}

/// `checkoutGtDir`: fetch the branch and check out only `default_working_dir`
/// from it, removing any sub-directories. Returns `Ok(true)` if the checkout
/// succeeded (i.e. the remote provides a `.gt` directory), `Ok(false)` otherwise.
///
/// A failing `git fetch` is fatal (mirrors the Bash `die`).
pub fn checkout_gt_dir(
    repo: &Path,
    remote: &str,
    branch: &str,
    default_working_dir: &str,
) -> Result<bool, crate::error::Exit> {
    let fetch = Command::new("git")
        .arg("-C")
        .arg(repo)
        .args(["fetch", "--depth", "1", remote, branch])
        .status();
    match fetch {
        Ok(s) if s.success() => {}
        _ => die!("was not able to {} from remote {}", cyan("git fetch"), cyan(remote)),
    }

    let checkout = Command::new("git")
        .arg("-C")
        .arg(repo)
        .args(["checkout", &format!("{remote}/{branch}"), "--", default_working_dir])
        .status();

    let checked_out = matches!(checkout, Ok(s) if s.success());
    if !checked_out {
        return Ok(false);
    }

    // remove all sub-directories of the checked-out working dir (keep only files)
    let gt_dir = repo.join(default_working_dir);
    if let Ok(entries) = std::fs::read_dir(&gt_dir) {
        for entry in entries.flatten() {
            if entry.path().is_dir() {
                let _ = crate::util::delete_dir_chmod_777(&entry.path());
            }
        }
    }
    Ok(true)
}

/// `latestRemoteTag`: list remote tags (via `git ls-remote --refs --tags`),
/// version-sort them, filter with `grep -E <tag_filter>`, and return the last
/// one (the latest). Fails if no tags exist or none match the filter.
pub fn latest_remote_tag(repo: &Path, remote: &str, tag_filter: &str) -> Result<String, crate::error::Exit> {
    let output = Command::new("git")
        .arg("-C")
        .arg(repo)
        .args(["ls-remote", "--refs", "--tags", remote])
        .output();

    let raw = match output {
        Ok(o) if o.status.success() => String::from_utf8_lossy(&o.stdout).into_owned(),
        Ok(_) | Err(_) => {
            return Err({
                log_warning(&format!("check your internet connection"));
                crate::error::Exit(1)
            });
        }
    };

    // Extract tag names: "<sha>\trefs/tags/<tag>" → <tag>
    let tags: Vec<String> = raw
        .lines()
        .filter_map(|l| l.split('\t').nth(1))
        .filter_map(|refn| refn.strip_prefix("refs/tags/"))
        .map(|s| s.to_string())
        .collect();

    if tags.is_empty() {
        return Err(crate::error::Exit(1));
    }

    // Pipe through `sort --version-sort` then `grep -E <filter>` then `tail -n 1`
    use std::process::Stdio;
    let mut sort = Command::new("sort")
        .arg("--version-sort")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn()
        .map_err(|_| crate::error::Exit(1))?;
    if let Some(mut stdin) = sort.stdin.take() {
        for tag in &tags {
            let _ = writeln!(stdin, "{tag}");
        }
    }
    let sorted = sort.wait_with_output().map_err(|_| crate::error::Exit(1))?;
    if !sorted.status.success() {
        return Err(crate::error::Exit(1));
    }

    let mut grep = Command::new("grep")
        .arg("-E")
        .arg(tag_filter)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn()
        .map_err(|_| crate::error::Exit(1))?;
    if let Some(mut stdin) = grep.stdin.take() {
        let _ = stdin.write_all(&sorted.stdout);
    }
    let filtered = grep.wait_with_output().map_err(|_| crate::error::Exit(1))?;

    let stdout = String::from_utf8_lossy(&filtered.stdout);
    let last = stdout.lines().last().unwrap_or("").to_string();
    if last.is_empty() {
        return Err(crate::error::Exit(1));
    }
    Ok(last)
}

/// `gitFetchTagFromRemote`: check if the tag exists locally, confirm it exists
/// remotely, and do a shallow fetch if needed.
pub fn fetch_tag_from_remote(repo: &Path, remote: &str, tag: &str) -> GtResult {
    let local_tags = Command::new("git").arg("-C").arg(repo).args(["tag"]).output();
    if let Ok(out) = local_tags {
        if out.status.success() {
            let stdout = String::from_utf8_lossy(&out.stdout);
            if stdout.lines().any(|l| l == tag) {
                crate::log::log_info(&format!(
                    "tag {} already exists locally, skipping fetching from remote {}",
                    cyan(tag),
                    cyan(remote)
                ));
                return Ok(());
            }
        }
    }

    // confirm the tag exists remotely
    let remote_tags = latest_remote_tag_list(repo, remote)?;
    if !remote_tags.lines().any(|l| l == tag) {
        crate::die!(
            "remote {} does not have the tag {}\nFollowing the available tags:\n{}",
            cyan(remote),
            cyan(tag),
            remote_tags
        );
    }

    let status = Command::new("git")
        .arg("-C")
        .arg(repo)
        .args([
            "fetch",
            "--depth",
            "1",
            remote,
            &format!("refs/tags/{tag}:refs/tags/{tag}"),
        ])
        .status();
    match status {
        Ok(s) if s.success() => Ok(()),
        _ => crate::die!("was not able to fetch tag {} from remote {}", cyan(tag), cyan(remote)),
    }
}

fn latest_remote_tag_list(repo: &Path, remote: &str) -> Result<String, crate::error::Exit> {
    let output = Command::new("git")
        .arg("-C")
        .arg(repo)
        .args(["ls-remote", "--refs", "--tags", remote])
        .output();
    match output {
        Ok(o) if o.status.success() => {
            let raw = String::from_utf8_lossy(&o.stdout);
            let tags: Vec<String> = raw
                .lines()
                .filter_map(|l| l.split('\t').nth(1))
                .filter_map(|refn| refn.strip_prefix("refs/tags/"))
                .map(|s| s.to_string())
                .collect();
            let mut sort = Command::new("sort")
                .arg("--version-sort")
                .stdin(std::process::Stdio::piped())
                .stdout(std::process::Stdio::piped())
                .spawn()
                .map_err(|_| crate::error::Exit(1))?;
            if let Some(mut stdin) = sort.stdin.take() {
                for tag in &tags {
                    let _ = writeln!(stdin, "{tag}");
                }
            }
            let sorted = sort.wait_with_output().map_err(|_| crate::error::Exit(1))?;
            Ok(String::from_utf8_lossy(&sorted.stdout).into_owned())
        }
        Ok(_) | Err(_) => Err(crate::error::Exit(1)),
    }
}

/// `git -C repo checkout tags/<tag> -- <path>`.
pub fn checkout_tag_path(repo: &Path, tag: &str, path: &str) -> GtResult {
    let status = Command::new("git")
        .arg("-C")
        .arg(repo)
        .args(["checkout", &format!("tags/{tag}"), "--", path])
        .status();
    match status {
        Ok(s) if s.success() => Ok(()),
        _ => crate::die!("was not able to checkout tags/{} and path {}", tag, path),
    }
}

/// `git -C repo show tags/<tag>:<path>` — returns the file contents.
pub fn show_tag_file(repo: &Path, tag: &str, path: &str) -> Result<String, crate::error::Exit> {
    let output = Command::new("git")
        .arg("-C")
        .arg(repo)
        .args(["--no-pager", "show", &format!("tags/{tag}:{path}")])
        .output();
    match output {
        Ok(o) if o.status.success() => Ok(String::from_utf8_lossy(&o.stdout).into_owned()),
        Ok(o) => {
            let stderr = String::from_utf8_lossy(&o.stderr);
            crate::die!("git show tags/{}:{} failed: {}", tag, path, stderr.trim());
        }
        Err(e) => crate::die!("git show tags/{}:{} failed: {}", tag, path, e),
    }
}

/// Re-initialise the repo from a stored gitconfig (used when .git is missing/broken).
pub fn re_initialise_git_dir(repo: &Path, gitconfig: &Path) -> GtResult {
    if std::fs::create_dir_all(repo).is_err() {
        crate::die!("could not create the repo at {}", repo.display());
    }
    let git_dir = repo.join(".git");
    let status = Command::new("git")
        .arg(format!("--git-dir={}", git_dir.display()))
        .arg("init")
        .status();
    match status {
        Ok(s) if s.success() => {}
        _ => crate::die!("could not git init the repo at {}", repo.display()),
    }
    if std::fs::copy(gitconfig, repo.join(".git").join("config")).is_err() {
        crate::die!(
            "could not copy {} to {}",
            gitconfig.display(),
            repo.join(".git").join("config").display()
        );
    }
    Ok(())
}

/// Check whether `repo/.git/config` lists `remote` as a remote.
pub fn repo_has_remote(repo: &Path, remote: &str) -> bool {
    let git_dir = repo.join(".git");
    let output = Command::new("git")
        .arg(format!("--git-dir={}", git_dir.display()))
        .args(["remote"])
        .output();
    match output {
        Ok(o) if o.status.success() => {
            let stdout = String::from_utf8_lossy(&o.stdout);
            stdout.lines().any(|l| l == remote)
        }
        _ => false,
    }
}
