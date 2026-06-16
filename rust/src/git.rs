//! Thin wrappers around the `git` command line tool.
//!
//! The original Bash implementation shells out to `git`; we do the same to keep
//! behaviour identical (instead of re-implementing git in Rust).

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
