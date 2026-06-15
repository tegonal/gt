use std::path::PathBuf;

use regex::Regex;

use crate::error::{Error, Result};

pub const DEFAULT_WORKING_DIR: &str = ".gt";
pub const DEFAULT_PULL_DIR: &str = "lib";
pub const REMOTE_NAME_REGEX: &str = r"^[a-zA-Z0-9_-]+$";
pub const DEFAULT_TAG_FILTER: &str = ".*";

pub fn validate_remote_name(name: &str) -> Result<()> {
    let re = Regex::new(REMOTE_NAME_REGEX)
        .map_err(|e| Error::Generic(format!("Invalid regex: {}", e)))?;

    if !re.is_match(name) {
        return Err(Error::InvalidRemoteName {
            name: name.to_string(),
            pattern: REMOTE_NAME_REGEX.to_string(),
        });
    }

    Ok(())
}

pub fn validate_path_inside_current_dir(path: &PathBuf, path_type: &str) -> Result<()> {
    let current_dir = std::env::current_dir()
        .map_err(|e| Error::Generic(format!("Could not get current directory: {}", e)))?;

    let full_path = current_dir.join(path);
    let canonical_path = full_path
        .canonicalize()
        .map_err(|e| Error::Generic(format!("Could not canonicalize path: {}", e)))?;

    let canonical_current = current_dir
        .canonicalize()
        .map_err(|e| Error::Generic(format!("Could not canonicalize current dir: {}", e)))?;

    if !canonical_path.starts_with(&canonical_current) {
        return Err(Error::PathOutsideCurrentDir {
            path_type: path_type.to_string(),
            path: path.display().to_string(),
        });
    }

    Ok(())
}
