use clap::Parser;
use std::fs;
use std::path::PathBuf;

use crate::config::{
    DEFAULT_PULL_DIR, DEFAULT_TAG_FILTER, DEFAULT_WORKING_DIR, validate_path_inside_current_dir,
    validate_remote_name,
};
use crate::error::{Error, Result};
use crate::git::{checkout_directory, clone_repository, get_default_branch};
use crate::gpg::{import_public_key, initialize_gpg_dir, list_gpg_keys};
use crate::paths::RemotePaths;

const SIGNING_KEY_FILE: &str = "signing-key.public.asc";

#[derive(Parser, Debug)]
pub struct RemoteAddArgs {
    /// Name identifying this remote (alphanumeric, -, _)
    #[arg(short = 'r', long = "remote")]
    pub remote: String,

    /// URL of the remote repository
    #[arg(short = 'u', long = "url")]
    pub url: String,

    /// Directory for pulled files (default: lib/<remote>)
    #[arg(short = 'd', long = "directory")]
    pub directory: Option<String>,

    /// Regex to filter tags (default: .*)
    #[arg(long = "tag-filter")]
    pub tag_filter: Option<String>,

    /// Skip GPG key requirement (default: false)
    #[arg(long = "unsecure")]
    pub unsecure: Option<bool>,

    /// Working directory (default: .gt)
    #[arg(short = 'w', long = "working-directory")]
    pub working_directory: Option<String>,
}

impl RemoteAddArgs {
    pub fn run(&self) -> Result<()> {
        let remote_name = &self.remote;
        validate_remote_name(remote_name)?;

        let working_dir = self
            .working_directory
            .as_deref()
            .unwrap_or(DEFAULT_WORKING_DIR);
        let working_dir_path = PathBuf::from(working_dir);

        validate_path_inside_current_dir(&working_dir_path, "working directory")?;

        let pull_dir = self
            .directory
            .clone()
            .unwrap_or_else(|| format!("{}/{}", DEFAULT_PULL_DIR, remote_name));

        let tag_filter = self
            .tag_filter
            .clone()
            .unwrap_or_else(|| DEFAULT_TAG_FILTER.to_string());
        let unsecure = self.unsecure.unwrap_or(false);

        let paths = RemotePaths::new(&working_dir_path, remote_name);

        if paths.remote_dir.exists() {
            if paths.pulled_tsv.exists() {
                return Err(Error::RemoteExists {
                    remote: remote_name.clone(),
                });
            } else {
                return Err(Error::RemoteExistsEmpty {
                    remote: remote_name.clone(),
                });
            }
        }

        fs::create_dir_all(&paths.remotes_dir)?;
        fs::create_dir_all(&paths.remote_dir)?;

        fs::write(&paths.pull_args, format!("-d {}\n", pull_dir))?;

        if tag_filter != DEFAULT_TAG_FILTER {
            fs::write(&paths.pull_args, format!("--tag-filter {}\n", tag_filter))?;
        }

        fs::create_dir_all(&paths.public_keys_dir)?;
        initialize_gpg_dir(&paths.gpg_dir)?;

        clone_repository(&self.url, &paths.repo_dir)?;

        fs::copy(paths.repo_dir.join(".git").join("config"), &paths.gitconfig)?;

        let default_branch = get_default_branch(&paths.repo_dir)?;

        if !checkout_directory(&paths.repo_dir, &default_branch, ".gt")? {
            if unsecure {
                eprintln!(
                    "Warning: no .gt directory defined in remote '{}' which means no GPG key available, ignoring it because --unsecure true was specified",
                    remote_name
                );
                return Ok(());
            } else {
                return Err(Error::NoGtDirectory {
                    branch: default_branch,
                });
            }
        }

        let signing_key_path = paths.repo_dir.join(".gt").join(SIGNING_KEY_FILE);
        if !signing_key_path.exists() {
            if unsecure {
                eprintln!(
                    "Warning: remote '{}' has a directory .gt but no {} in it. Ignoring it because --unsecure true was specified",
                    remote_name, SIGNING_KEY_FILE
                );
                return Ok(());
            } else {
                return Err(Error::NoSigningKey);
            }
        }

        fs::copy(
            &signing_key_path,
            paths.public_keys_dir.join(SIGNING_KEY_FILE),
        )?;

        let num_keys = import_public_key(&paths.gpg_dir, &signing_key_path)?;

        if num_keys == 0 {
            if unsecure {
                eprintln!(
                    "Warning: no GPG keys imported, ignoring it because --unsecure true was specified"
                );
                return Ok(());
            } else {
                return Err(Error::NoGpgKeysImported {
                    remote: remote_name.clone(),
                });
            }
        }

        let _ = list_gpg_keys(&paths.gpg_dir);

        println!(
            "Remote '{}' was set up successfully; imported {} GPG key(s) for verification.",
            remote_name, num_keys
        );
        println!(
            "You are ready to pull files via:\ngt pull -r {} -p <PATH>",
            remote_name
        );

        Ok(())
    }
}
