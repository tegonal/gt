use crate::error::{GtRemoteError, Result};
use std::path::Path;

pub fn init_gpg_dir(gpg_dir: &Path) -> Result<()> {
    if !gpg_dir.exists() {
        std::fs::create_dir_all(gpg_dir)?;
    }

    // Set permissions to 700 (gpg requires this)
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let perms = std::fs::Permissions::from_mode(0o700);
        std::fs::set_permissions(gpg_dir, perms).ok();
    }

    Ok(())
}

pub fn import_key(gpg_dir: &Path, key_file: &Path) -> Result<()> {
    let output = std::process::Command::new("gpg")
        .arg("--homedir")
        .arg(gpg_dir)
        .arg("--import")
        .arg(key_file)
        .output()
        .map_err(|e| GtRemoteError::Gpg(format!("Failed to run gpg: {}", e)))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(GtRemoteError::Gpg(format!(
            "Failed to import GPG key: {}",
            stderr
        )));
    }

    Ok(())
}

pub fn list_keys(gpg_dir: &Path) -> Result<Vec<String>> {
    let output = std::process::Command::new("gpg")
        .arg("--homedir")
        .arg(gpg_dir)
        .arg("--list-keys")
        .arg("--with-colons")
        .output()
        .map_err(|e| GtRemoteError::Gpg(format!("Failed to list GPG keys: {}", e)))?;

    if !output.status.success() {
        return Err(GtRemoteError::Gpg("Failed to list GPG keys".to_string()));
    }

    let keys = String::from_utf8_lossy(&output.stdout)
        .lines()
        .filter(|l| l.starts_with("pub:"))
        .map(|l| l.split(':').nth(4).unwrap_or("").to_string())
        .filter(|k| !k.is_empty())
        .collect();

    Ok(keys)
}

pub fn list_sigs(gpg_dir: &Path) -> Result<()> {
    let status = std::process::Command::new("gpg")
        .arg("--homedir")
        .arg(gpg_dir)
        .arg("--list-sigs")
        .status()
        .map_err(|e| GtRemoteError::Gpg(format!("Failed to list GPG signatures: {}", e)))?;

    if !status.success() {
        return Err(GtRemoteError::Gpg(
            "Failed to list GPG signatures".to_string(),
        ));
    }

    Ok(())
}

pub fn import_signing_key_from_remote(
    repo_path: &Path,
    working_dir_name: &str,
    public_keys_dir: &Path,
    gpg_dir: &Path,
) -> Result<usize> {
    let default_working_dir = working_dir_name;
    let signing_key_path = repo_path
        .join(default_working_dir)
        .join("signing-key.public.asc");

    if !signing_key_path.exists() {
        return Err(GtRemoteError::NoGpgKeys);
    }

    let key_name = signing_key_path
        .file_name()
        .unwrap_or_default()
        .to_string_lossy()
        .to_string();

    let dest_key_path = public_keys_dir.join(&key_name);
    std::fs::copy(&signing_key_path, &dest_key_path)?;

    import_key(gpg_dir, &dest_key_path)?;

    let keys = list_keys(gpg_dir)?;
    Ok(keys.len())
}

pub fn check_signing_key_exists(repo_path: &Path, working_dir_name: &str) -> bool {
    let signing_key_path = repo_path
        .join(working_dir_name)
        .join("signing-key.public.asc");
    signing_key_path.exists()
}

pub fn gt_dir_exists(repo_path: &Path, working_dir_name: &str) -> bool {
    let gt_dir = repo_path.join(working_dir_name);
    gt_dir.exists()
}
