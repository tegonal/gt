//! Thin wrappers around the `git` command line tool.
//!
//! The original Bash implementation shells out to `git`; we do the same to keep
//! behaviour identical (instead of re-implementing git in Rust).

use std::io::Write;
use std::path::Path;
use std::process::{Command, Stdio};

use crate::args::cyan;
use crate::error::{Exit, GtResult};
use crate::log::log_warning;
use crate::{die, exit_with};

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

/// `currentGitBranch`: `git -C <repo> rev-parse --abbrev-ref HEAD`.
///
/// Returns the trimmed branch name; dies on failure (mirrors the trivial Bash
/// wrapper, where a non-zero `git` exit would propagate via `set -e`).
pub fn current_git_branch(repo: &Path) -> Result<String, Exit> {
    let output = Command::new("git")
        .arg("-C")
        .arg(repo)
        .args(["rev-parse", "--abbrev-ref", "HEAD"])
        .output();
    match output {
        Ok(out) if out.status.success() => Ok(String::from_utf8_lossy(&out.stdout).trim().to_string()),
        _ => die!("could not determine the current git branch in {}", repo.display()),
    }
}

/// `latestRemoteTag`: the latest tag of `remote`, after filtering by `tag_filter`.
///
/// Mirrors `remoteTagsSorted "$remote" | grep -E "$tagFilter" | tail -n 1`:
/// `git ls-remote --refs --tags`, take the tag name (third `/`-separated field),
/// version-sort via GNU `sort --version-sort`, keep lines matching `tag_filter`
/// and return the last one. Dies if there is no matching tag (as the Bash does).
pub fn latest_remote_tag(repo: &Path, remote: &str, tag_filter: &str) -> Result<String, Exit> {
    let git_dir = repo.join(".git");
    let output = Command::new("git")
        .arg(format!("--git-dir={}", git_dir.display()))
        .args(["ls-remote", "--refs", "--tags", remote])
        .output();
    let stdout = match output {
        Ok(out) if out.status.success() => String::from_utf8_lossy(&out.stdout).into_owned(),
        _ => exit_with!(
            1,
            "could not get remote tags sorted for remote {}, see above",
            cyan(remote)
        ),
    };

    let tags = tag_names(&stdout);
    let sorted = version_sort(&tags)?;
    let filtered = grep_e(&sorted, tag_filter)?;
    let tag = filtered.last().cloned();

    match tag {
        Some(tag) if !tag.is_empty() => Ok(tag),
        _ => exit_with!(1, "looks like remote {} does not have a tag yet.", cyan(remote)),
    }
}

/// Extracts the tag names from `git ls-remote --refs --tags` output, mirroring
/// `cut --delimiter='/' --fields=3` (third `/`-separated field of each line).
fn tag_names(ls_remote_output: &str) -> Vec<String> {
    ls_remote_output
        .lines()
        .filter_map(|line| line.split('/').nth(2))
        .filter(|s| !s.is_empty())
        .map(|s| s.to_string())
        .collect()
}

/// Sorts the given tags using GNU `sort --version-sort` to stay byte-for-byte
/// compatible with the original `remoteTagsSorted`.
fn version_sort(tags: &[String]) -> Result<Vec<String>, Exit> {
    if tags.is_empty() {
        return Ok(Vec::new());
    }
    let mut input = tags.join("\n");
    input.push('\n');

    let mut child = Command::new("sort")
        .arg("--version-sort")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .map_err(|_| {
            crate::log::log_error("could not run 'sort --version-sort'");
            Exit(1)
        })?;
    if let Some(stdin) = child.stdin.take() {
        let mut stdin = stdin;
        let _ = stdin.write_all(input.as_bytes());
    }
    let output = child.wait_with_output().map_err(|_| {
        crate::log::log_error("could not read output of 'sort --version-sort'");
        Exit(1)
    })?;
    if !output.status.success() {
        crate::log::log_error("'sort --version-sort' failed");
        return Err(Exit(1));
    }
    Ok(String::from_utf8_lossy(&output.stdout)
        .lines()
        .map(|s| s.to_string())
        .collect())
}

/// Mirrors `grep -E "$tagFilter"`. The default filter `.*` (and the empty filter)
/// matches everything, so we short-circuit; otherwise we shell out to `grep -E`
/// to stay compatible with the original regex semantics without pulling in a
/// regex crate.
fn grep_e(lines: &[String], tag_filter: &str) -> Result<Vec<String>, Exit> {
    if tag_filter == ".*" || tag_filter.is_empty() || lines.is_empty() {
        return Ok(lines.to_vec());
    }
    let mut input = lines.join("\n");
    input.push('\n');

    let mut child = Command::new("grep")
        .arg("-E")
        .arg(tag_filter)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .map_err(|_| {
            crate::log::log_error("could not run 'grep -E'");
            Exit(1)
        })?;
    if let Some(stdin) = child.stdin.take() {
        let mut stdin = stdin;
        let _ = stdin.write_all(input.as_bytes());
    }
    let output = child.wait_with_output().map_err(|_| {
        crate::log::log_error("could not read output of 'grep -E'");
        Exit(1)
    })?;
    // grep exits 1 when there are no matches; that is not an error for us.
    Ok(String::from_utf8_lossy(&output.stdout)
        .lines()
        .map(|s| s.to_string())
        .collect())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn tag_names_extracts_third_field() {
        let out = "abc123\trefs/tags/v1.0.0\n\
deadbeef\trefs/tags/v1.2.0\n\
cafe\trefs/tags/v2.0.0-RC1\n";
        assert_eq!(tag_names(out), vec!["v1.0.0", "v1.2.0", "v2.0.0-RC1"]);
    }

    #[test]
    fn tag_names_ignores_malformed_lines() {
        let out = "no-slashes-here\nabc\trefs/tags/v3.0.0\n";
        assert_eq!(tag_names(out), vec!["v3.0.0"]);
    }

    #[test]
    fn version_sort_orders_naturally() {
        let tags: Vec<String> = ["v1.10.0", "v1.2.0", "v1.9.0"].iter().map(|s| s.to_string()).collect();
        let sorted = version_sort(&tags).unwrap();
        assert_eq!(sorted, vec!["v1.2.0", "v1.9.0", "v1.10.0"]);
    }

    #[test]
    fn grep_e_default_filter_keeps_all() {
        let tags: Vec<String> = ["v1.0.0", "v2.0.0"].iter().map(|s| s.to_string()).collect();
        assert_eq!(grep_e(&tags, ".*").unwrap(), tags);
    }
}
