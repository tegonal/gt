use crate::error::{GtRemoteError, Result};
use std::path::{Path, PathBuf};

pub struct Paths {
    pub working_dir_absolute: PathBuf,
    pub remotes_dir: PathBuf,
    pub remote_dir: PathBuf,
    pub public_keys_dir: PathBuf,
    pub repo: PathBuf,
    pub gpg_dir: PathBuf,
    pub pulled_tsv: PathBuf,
    pub pull_args_file: PathBuf,
    pub pull_hook_file: PathBuf,
    pub gitconfig: PathBuf,
}

impl Paths {
    pub fn new(working_dir_absolute: PathBuf, remote_name: &str) -> Self {
        let remotes_dir = working_dir_absolute.join("remotes");
        let remote_dir = remotes_dir.join(remote_name);
        let public_keys_dir = remote_dir.join("public-keys");
        let repo = remote_dir.join("repo");
        let gpg_dir = public_keys_dir.join("gpg");
        let pulled_tsv = remote_dir.join("pulled.tsv");
        let pull_args_file = remote_dir.join("pull.args");
        let pull_hook_file = remote_dir.join("pull-hook.sh");
        let gitconfig = remote_dir.join("gitconfig");

        Self {
            working_dir_absolute,
            remotes_dir,
            remote_dir,
            public_keys_dir,
            repo,
            gpg_dir,
            pulled_tsv,
            pull_args_file,
            pull_hook_file,
            gitconfig,
        }
    }

    pub fn default_working_dir() -> PathBuf {
        PathBuf::from(".gt")
    }
}

pub fn resolve_working_dir(input: &str) -> Result<PathBuf> {
    let path = Path::new(input);
    if path.is_absolute() {
        Ok(path.to_path_buf())
    } else {
        std::env::current_dir()
            .map(|d| d.join(path))
            .map_err(GtRemoteError::Io)
    }
}

pub fn exit_if_path_outside_of(current_dir: &Path, path: &Path, path_name: &str) -> Result<()> {
    let resolved = if path.is_absolute() {
        path.to_path_buf()
    } else {
        current_dir.join(path)
    };

    if let Some(canonical) = resolved.canonicalize().ok()
        && !canonical.starts_with(current_dir)
    {
        return Err(GtRemoteError::Config(format!(
            "{} must be inside of current directory",
            path_name
        )));
    }

    Ok(())
}
