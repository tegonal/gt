use std::path::Path;
use std::process::Command;

use crate::error::{Error, Result};

pub fn initialize_gpg_dir(gpg_dir: &Path) -> Result<()> {
    std::fs::create_dir_all(gpg_dir)
        .map_err(|e| Error::Gpg(format!("Failed to create GPG directory: {}", e)))?;

    let output = Command::new("gpg")
        .args(["--homedir", gpg_dir.to_str().unwrap_or("")])
        .arg("--list-keys")
        .output()
        .map_err(|e| Error::Gpg(format!("Failed to initialize GPG: {}", e)))?;

    if output.status.success() {
        Ok(())
    } else {
        Err(Error::Gpg("Failed to initialize GPG directory".to_string()))
    }
}

pub fn import_public_key(gpg_dir: &Path, key_file: &Path) -> Result<usize> {
    let output = Command::new("gpg")
        .args(["--homedir", gpg_dir.to_str().unwrap_or("")])
        .arg("--import")
        .arg(key_file)
        .output()
        .map_err(|e| Error::Gpg(format!("Failed to import key: {}", e)))?;

    if output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        let mut count = 0;

        for line in stderr.lines() {
            if line.contains("imported")
                && let Some(pos) = line.find("imported")
            {
                let before = &line[..pos];
                if let Some(pos) = before.rfind(' ')
                    && let Ok(num) = before[pos + 1..].trim().parse::<usize>()
                {
                    count = num;
                }
            }
        }

        Ok(count)
    } else {
        let stderr = String::from_utf8_lossy(&output.stderr);
        Err(Error::Gpg(stderr.to_string()))
    }
}

pub fn list_gpg_keys(gpg_dir: &Path) -> Result<String> {
    let output = Command::new("gpg")
        .args(["--homedir", gpg_dir.to_str().unwrap_or("")])
        .arg("--list-sigs")
        .output()
        .map_err(|e| Error::Gpg(format!("Failed to list GPG keys: {}", e)))?;

    if output.status.success() {
        Ok(String::from_utf8_lossy(&output.stdout).to_string())
    } else {
        let stderr = String::from_utf8_lossy(&output.stderr);
        Err(Error::Gpg(stderr.to_string()))
    }
}
