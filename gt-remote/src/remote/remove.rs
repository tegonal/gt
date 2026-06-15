use clap::Parser;
use std::fs;
use std::io::{BufRead, BufReader};
use std::path::PathBuf;

use crate::config::{DEFAULT_WORKING_DIR, validate_path_inside_current_dir};
use crate::error::{Error, Result};
use crate::paths::RemotePaths;

#[derive(Parser, Debug)]
pub struct RemoteRemoveArgs {
    /// Name of the remote to remove
    #[arg(short = 'r', long = "remote")]
    pub remote: String,

    /// Delete pulled files (default: false)
    #[arg(long = "delete-pulled-files")]
    pub delete_pulled_files: Option<bool>,

    /// Working directory (default: .gt)
    #[arg(short = 'w', long = "working-directory")]
    pub working_directory: Option<String>,
}

impl RemoteRemoveArgs {
    pub fn run(&self) -> Result<()> {
        let remote_name = &self.remote;
        let working_dir = self
            .working_directory
            .as_deref()
            .unwrap_or(DEFAULT_WORKING_DIR);
        let working_dir_path = PathBuf::from(working_dir);

        validate_path_inside_current_dir(&working_dir_path, "working directory")?;

        let delete_pulled_files = self.delete_pulled_files.unwrap_or(false);

        let paths = RemotePaths::new(&working_dir_path, remote_name);

        if paths.remote_dir.is_file() {
            return Err(Error::Generic(format!(
                "cannot delete remote '{}', looks like it is broken there is a file at this location: {}",
                remote_name,
                paths.remote_dir.display()
            )));
        }

        if !paths.remote_dir.exists() {
            return Err(Error::RemoteNotFound {
                remote: remote_name.clone(),
            });
        }

        let pull_hook = paths.pull_hook.clone();
        if pull_hook.exists() {
            eprintln!(
                "Warning: detected a pull-hook.sh in the remote {}, you might want to move it away first.",
                remote_name
            );
            eprintln!("Shall I continue and delete it as well? (y/N)");
            let mut input = String::new();
            std::io::stdin().read_line(&mut input)?;
            if !input.trim().eq_ignore_ascii_case("y") {
                eprintln!("Removing remote '{}' aborted", remote_name);
                return Err(Error::Cancelled);
            }
        }

        if delete_pulled_files && paths.pulled_tsv.exists() {
            let file = fs::File::open(&paths.pulled_tsv)?;
            let reader = BufReader::new(file);
            let mut deleted_count = 0;

            for (index, line) in reader.lines().enumerate() {
                if index < 2 {
                    continue;
                }

                let line = line?;
                let parts: Vec<&str> = line.split('\t').collect();
                if parts.len() >= 3 {
                    let relative_path = parts[2];
                    let file_path = working_dir_path.join(remote_name).join(relative_path);
                    if file_path.exists() {
                        fs::remove_file(&file_path)?;
                        deleted_count += 1;
                    }
                }
            }

            println!("Deleted {} pulled files", deleted_count);
        } else if paths.pulled_tsv.exists() {
            println!(
                "Detected a pulled.tsv in the remote {}. You might want to pass '--delete-pulled-files true' in case you want to delete all files",
                remote_name
            );
            eprintln!(
                "Shall I abort? If you don't choose y, then I will go on and delete the remote without deleting the pulled files as defined in pulled.tsv (y/N)"
            );
            let mut input = String::new();
            std::io::stdin().read_line(&mut input)?;
            if input.trim().eq_ignore_ascii_case("y") {
                eprintln!("Removing remote '{}' aborted", remote_name);
                return Err(Error::Cancelled);
            }
        }

        fs::remove_dir_all(&paths.remote_dir)?;

        println!("Removed remote '{}'", remote_name);

        Ok(())
    }
}
