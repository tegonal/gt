use crate::config::{Paths, resolve_working_dir};
use crate::error::{GtRemoteError, Result};
use std::fs;

pub fn execute(working_dir: &str, remote_name: &str, delete_pulled_files: bool) -> Result<()> {
    let working_dir_absolute = resolve_working_dir(working_dir)?;
    let paths = Paths::new(working_dir_absolute.clone(), remote_name);

    if !paths.remote_dir.exists() {
        return Err(GtRemoteError::RemoteNotFound(remote_name.to_string()));
    }

    if paths.pull_hook_file.exists() {
        println!(
            "Warning: detected a pull-hook.sh in the remote '{}', you might want to move it away first.",
            remote_name
        );
    }

    if paths.pulled_tsv.exists() && !delete_pulled_files {
        println!(
            "Detected a pulled.tsv in the remote '{}'. You might want to pass '--delete-pulled-files true' in case you want to delete all files",
            remote_name
        );
    } else if paths.pulled_tsv.exists() && delete_pulled_files {
        let content = fs::read_to_string(&paths.pulled_tsv)?;
        let mut deleted_count = 0;

        for line in content.lines() {
            if line.starts_with('#') || line.trim().is_empty() {
                continue;
            }

            let fields: Vec<&str> = line.split('\t').collect();
            if fields.len() >= 3 {
                let relative_path = fields[2];
                let target_dir = working_dir_absolute.join("lib").join(remote_name);
                let file_path = target_dir.join(relative_path);

                if file_path.exists() {
                    if let Err(e) = fs::remove_file(&file_path) {
                        println!(
                            "Warning: could not delete file '{}': {}",
                            file_path.display(),
                            e
                        );
                    } else {
                        deleted_count += 1;
                    }
                }
            }
        }

        println!("Deleted {} pulled files", deleted_count);
    }

    fs::remove_dir_all(&paths.remote_dir)?;

    println!("Removed remote '{}'", remote_name);

    Ok(())
}
