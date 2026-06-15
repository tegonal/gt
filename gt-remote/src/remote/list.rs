use clap::Parser;
use std::fs;
use std::path::PathBuf;

use crate::config::{DEFAULT_WORKING_DIR, validate_path_inside_current_dir};
use crate::error::Result;

#[derive(Parser, Debug)]
pub struct RemoteListArgs {
    /// Working directory (default: .gt)
    #[arg(short = 'w', long = "working-directory")]
    pub working_directory: Option<String>,
}

impl RemoteListArgs {
    pub fn run(&self) -> Result<()> {
        let working_dir = self
            .working_directory
            .as_deref()
            .unwrap_or(DEFAULT_WORKING_DIR);
        let working_dir_path = PathBuf::from(working_dir);

        validate_path_inside_current_dir(&working_dir_path, "working directory")?;

        let remotes_dir = working_dir_path.join("remotes");

        if !remotes_dir.exists() {
            println!("No remote defined yet.");
            println!();
            println!("To add one, use: gt remote add ...");
            return Ok(());
        }

        let mut remotes: Vec<String> = fs::read_dir(&remotes_dir)?
            .filter_map(|entry| entry.ok())
            .filter(|entry| entry.path().is_dir())
            .filter_map(|entry| {
                entry
                    .file_name()
                    .into_string()
                    .ok()
                    .filter(|name| name != "repo" && name != "public-keys")
            })
            .collect();

        remotes.sort();

        if remotes.is_empty() {
            println!("No remote defined yet.");
            println!();
            println!("To add one, use: gt remote add ...");
        } else {
            for remote in remotes {
                println!("{}", remote);
            }
        }

        Ok(())
    }
}
