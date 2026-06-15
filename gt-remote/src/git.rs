use std::path::Path;
use std::process::Command;

use crate::error::{Error, Result};

pub fn run_git<C, P>(current_dir: C, args: &[P]) -> Result<String>
where
    C: AsRef<Path>,
    P: AsRef<std::ffi::OsStr>,
{
    let output = Command::new("git")
        .current_dir(current_dir)
        .args(args)
        .output()
        .map_err(|e| Error::Git(format!("Failed to run git: {}", e)))?;

    if output.status.success() {
        Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
    } else {
        let stderr = String::from_utf8_lossy(&output.stderr);
        Err(Error::Git(stderr.to_string()))
    }
}

pub fn clone_repository(url: &str, target_dir: &Path) -> Result<()> {
    let output = Command::new("git")
        .arg("clone")
        .arg(url)
        .arg(target_dir)
        .output()
        .map_err(|e| Error::Git(format!("Failed to clone repository: {}", e)))?;

    if output.status.success() {
        Ok(())
    } else {
        let stderr = String::from_utf8_lossy(&output.stderr);
        Err(Error::Git(stderr.to_string()))
    }
}

pub fn get_default_branch(repo_dir: &Path) -> Result<String> {
    let output = Command::new("git")
        .current_dir(repo_dir)
        .args(["remote", "show", "origin"])
        .output()
        .map_err(|e| Error::Git(format!("Failed to get remote info: {}", e)))?;

    if output.status.success() {
        let stdout = String::from_utf8_lossy(&output.stdout);
        for line in stdout.lines() {
            if line.contains("HEAD branch:") {
                let parts: Vec<&str> = line.split(':').collect();
                if parts.len() > 1 {
                    return Ok(parts[1].trim().to_string());
                }
            }
        }
    }

    let branches = run_git(repo_dir, &["branch", "-r"])?;
    if branches.contains("origin/main") {
        Ok("main".to_string())
    } else if branches.contains("origin/master") {
        Ok("master".to_string())
    } else {
        Err(Error::Git("Could not determine default branch".to_string()))
    }
}

pub fn checkout_directory(repo_dir: &Path, branch: &str, directory: &str) -> Result<bool> {
    let output = Command::new("git")
        .current_dir(repo_dir)
        .args(["checkout", branch, "--", directory])
        .output()
        .map_err(|e| Error::Git(format!("Failed to checkout directory: {}", e)))?;

    Ok(output.status.success())
}
