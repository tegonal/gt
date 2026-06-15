use crate::error::{GtRemoteError, Result};
use std::path::Path;

pub fn init_git_dir(repo_path: &Path) -> Result<()> {
    if !repo_path.exists() {
        std::fs::create_dir_all(repo_path)?;
    }

    let status = std::process::Command::new("git")
        .arg("--git-dir")
        .arg(repo_path.join(".git"))
        .arg("init")
        .status()
        .map_err(|e| GtRemoteError::Git(format!("Failed to run git init: {}", e)))?;

    if !status.success() {
        return Err(GtRemoteError::Git(
            "Failed to initialize git repository".to_string(),
        ));
    }

    Ok(())
}

pub fn add_remote(repo_path: &Path, remote_name: &str, url: &str) -> Result<()> {
    let status = std::process::Command::new("git")
        .arg("-C")
        .arg(repo_path)
        .arg("remote")
        .arg("add")
        .arg(remote_name)
        .arg(url)
        .status()
        .map_err(|e| GtRemoteError::Git(format!("Failed to add remote: {}", e)))?;

    if !status.success() {
        return Err(GtRemoteError::Git(format!(
            "Failed to add remote '{}' with url '{}'",
            remote_name, url
        )));
    }

    Ok(())
}

pub fn fetch_remote(repo_path: &Path, remote_name: &str, refspec: &str) -> Result<()> {
    let status = std::process::Command::new("git")
        .arg("-C")
        .arg(repo_path)
        .arg("fetch")
        .arg("--depth")
        .arg("1")
        .arg(remote_name)
        .arg(refspec)
        .status()
        .map_err(|e| GtRemoteError::Git(format!("Failed to fetch from remote: {}", e)))?;

    if !status.success() {
        return Err(GtRemoteError::FetchError(format!(
            "Failed to fetch {} from {}",
            refspec, remote_name
        )));
    }

    Ok(())
}

pub fn checkout_branch(repo_path: &Path, branch: &str) -> Result<()> {
    let status = std::process::Command::new("git")
        .arg("-C")
        .arg(repo_path)
        .arg("checkout")
        .arg(branch)
        .status()
        .map_err(|e| GtRemoteError::Git(format!("Failed to checkout branch: {}", e)))?;

    if !status.success() {
        return Err(GtRemoteError::Git(format!(
            "Failed to checkout branch '{}'",
            branch
        )));
    }

    Ok(())
}

pub fn get_remote_default_branch(repo_path: &Path, remote_name: &str) -> Result<String> {
    // First try git remote get-head which directly gets the default branch
    let output = std::process::Command::new("git")
        .arg("-C")
        .arg(repo_path)
        .arg("remote")
        .arg("get-head")
        .arg(remote_name)
        .output()
        .map_err(|e| GtRemoteError::Git(format!("Failed to get HEAD: {}", e)))?;

    if output.status.success() {
        let branch = String::from_utf8_lossy(&output.stdout)
            .trim()
            .strip_prefix(&format!("{}/", remote_name))
            .unwrap_or(String::from_utf8_lossy(&output.stdout).trim())
            .to_string();
        return Ok(branch);
    }

    // Fallback: try to determine from remote branches
    let branches = list_remote_branches(repo_path, remote_name)?;

    // Look for HEAD symbolic ref first
    for branch in &branches {
        if branch.contains("HEAD ->") {
            let parts: Vec<&str> = branch.split(" -> ").collect();
            if parts.len() > 1 {
                return Ok(parts[1].to_string());
            }
        }
    }

    // Look for main, then master as common defaults
    for preferred in &["main", "master"] {
        for branch in &branches {
            if branch.ends_with(&format!("/{preferred}")) || branch == preferred {
                return Ok(preferred.to_string());
            }
        }
    }

    // Fallback to first branch found
    if let Some(first_branch) = branches.first() {
        let branch_name = first_branch
            .strip_prefix(&format!("{}/", remote_name))
            .unwrap_or(first_branch)
            .to_string();
        return Ok(branch_name);
    }

    // Last resort: assume 'main'
    Ok("main".to_string())
}

pub fn list_remote_branches(repo_path: &Path, _remote_name: &str) -> Result<Vec<String>> {
    let output = std::process::Command::new("git")
        .arg("-C")
        .arg(repo_path)
        .arg("branch")
        .arg("-r")
        .output()
        .map_err(|e| GtRemoteError::Git(format!("Failed to list branches: {}", e)))?;

    if !output.status.success() {
        return Err(GtRemoteError::Git(
            "Failed to list remote branches".to_string(),
        ));
    }

    let branches = String::from_utf8_lossy(&output.stdout)
        .lines()
        .map(|l| l.trim().to_string())
        .filter(|l| !l.is_empty())
        .collect();

    Ok(branches)
}

pub fn clone_repo(url: &str, repo_path: &Path) -> Result<()> {
    if repo_path.exists() {
        std::fs::remove_dir_all(repo_path)?;
    }

    let status = std::process::Command::new("git")
        .arg("clone")
        .arg("--depth")
        .arg("1")
        .arg(url)
        .arg(repo_path)
        .status()
        .map_err(|e| GtRemoteError::Git(format!("Failed to clone repository: {}", e)))?;

    if !status.success() {
        return Err(GtRemoteError::Git("Failed to clone repository".to_string()));
    }

    Ok(())
}

pub fn checkout_ref(repo_path: &Path, ref_name: &str) -> Result<()> {
    let status = std::process::Command::new("git")
        .arg("-C")
        .arg(repo_path)
        .arg("checkout")
        .arg(ref_name)
        .status()
        .map_err(|e| GtRemoteError::Git(format!("Failed to checkout ref: {}", e)))?;

    if !status.success() {
        return Err(GtRemoteError::Git(format!(
            "Failed to checkout ref '{}'",
            ref_name
        )));
    }

    Ok(())
}

pub fn has_remote(repo_path: &Path, remote_name: &str) -> bool {
    std::process::Command::new("git")
        .arg("-C")
        .arg(repo_path)
        .arg("remote")
        .arg("get-url")
        .arg(remote_name)
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
}
