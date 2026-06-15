use std::path::{Path, PathBuf};

pub struct RemotePaths {
    pub remotes_dir: PathBuf,
    pub remote_dir: PathBuf,
    pub repo_dir: PathBuf,
    pub public_keys_dir: PathBuf,
    pub gpg_dir: PathBuf,
    pub pulled_tsv: PathBuf,
    pub pull_args: PathBuf,
    pub pull_hook: PathBuf,
    pub gitconfig: PathBuf,
}

impl RemotePaths {
    pub fn new(working_dir: &Path, remote_name: &str) -> Self {
        let working_dir_absolute = working_dir
            .canonicalize()
            .unwrap_or_else(|_| working_dir.to_path_buf());

        let remotes_dir = working_dir_absolute.join("remotes");
        let remote_dir = remotes_dir.join(remote_name);
        let repo_dir = remote_dir.join("repo");
        let public_keys_dir = remote_dir.join("public-keys");
        let gpg_dir = public_keys_dir.join("gpg");
        let pulled_tsv = remote_dir.join("pulled.tsv");
        let pull_args = remote_dir.join("pull.args");
        let pull_hook = remote_dir.join("pull-hook.sh");
        let gitconfig = remote_dir.join("gitconfig");

        Self {
            remotes_dir,
            remote_dir,
            repo_dir,
            public_keys_dir,
            gpg_dir,
            pulled_tsv,
            pull_args,
            pull_hook,
            gitconfig,
        }
    }
}
