//! Path layout of a gt working directory, mirroring `src/paths.source.sh`.
//!
//! Given an absolute working directory and a remote name, this computes all the
//! derived paths (remote dir, repo, gpg dir, pulled.tsv, ...).

use std::path::{Path, PathBuf};

/// All paths derived from a working directory and a particular remote.
#[derive(Debug, Clone)]
pub struct RemotePaths {
    pub remotes_dir: PathBuf,
    pub remote_dir: PathBuf,
    pub public_keys_dir: PathBuf,
    pub repo: PathBuf,
    pub gpg_dir: PathBuf,
    pub pulled_tsv: PathBuf,
    /// note: keep in sync with gt-pull.sh => pullArgsFile
    pub pull_args_file: PathBuf,
    pub pull_hook_file: PathBuf,
    pub gitconfig: PathBuf,
    pub last_signing_key_check_file: PathBuf,
}

impl RemotePaths {
    /// Computes all remote-related paths for `remote` inside `working_dir_absolute`.
    pub fn new(working_dir_absolute: &Path, remote: &str) -> Self {
        let remotes_dir = working_dir_absolute.join("remotes");
        let remote_dir = remotes_dir.join(remote);
        let public_keys_dir = remote_dir.join("public-keys");
        let repo = remote_dir.join("repo");
        let gpg_dir = public_keys_dir.join("gpg");
        let pulled_tsv = remote_dir.join("pulled.tsv");
        let pull_args_file = remote_dir.join("pull.args");
        let pull_hook_file = remote_dir.join("pull-hook.sh");
        let gitconfig = remote_dir.join("gitconfig");
        let last_signing_key_check_file = gpg_dir.join("signing-key.last-check.txt");

        RemotePaths {
            remotes_dir,
            remote_dir,
            public_keys_dir,
            repo,
            gpg_dir,
            pulled_tsv,
            pull_args_file,
            pull_hook_file,
            gitconfig,
            last_signing_key_check_file,
        }
    }
}

/// Only the `remotes` dir is needed (e.g. for `remote list`); `remote` is irrelevant.
pub fn remotes_dir(working_dir_absolute: &Path) -> PathBuf {
    working_dir_absolute.join("remotes")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn computes_expected_layout() {
        let wd = Path::new("/project/.gt");
        let p = RemotePaths::new(wd, "tegonal-scripts");
        assert_eq!(p.remotes_dir, PathBuf::from("/project/.gt/remotes"));
        assert_eq!(p.remote_dir, PathBuf::from("/project/.gt/remotes/tegonal-scripts"));
        assert_eq!(
            p.public_keys_dir,
            PathBuf::from("/project/.gt/remotes/tegonal-scripts/public-keys")
        );
        assert_eq!(p.repo, PathBuf::from("/project/.gt/remotes/tegonal-scripts/repo"));
        assert_eq!(
            p.gpg_dir,
            PathBuf::from("/project/.gt/remotes/tegonal-scripts/public-keys/gpg")
        );
        assert_eq!(
            p.pulled_tsv,
            PathBuf::from("/project/.gt/remotes/tegonal-scripts/pulled.tsv")
        );
        assert_eq!(
            p.pull_args_file,
            PathBuf::from("/project/.gt/remotes/tegonal-scripts/pull.args")
        );
        assert_eq!(
            p.pull_hook_file,
            PathBuf::from("/project/.gt/remotes/tegonal-scripts/pull-hook.sh")
        );
        assert_eq!(
            p.gitconfig,
            PathBuf::from("/project/.gt/remotes/tegonal-scripts/gitconfig")
        );
        assert_eq!(
            p.last_signing_key_check_file,
            PathBuf::from("/project/.gt/remotes/tegonal-scripts/public-keys/gpg/signing-key.last-check.txt")
        );
        assert_eq!(remotes_dir(wd), PathBuf::from("/project/.gt/remotes"));
    }
}
