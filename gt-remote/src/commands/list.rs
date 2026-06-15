use crate::config::resolve_working_dir;
use crate::error::Result;
use std::fs;

pub fn execute(working_dir: &str) -> Result<()> {
    let working_dir_absolute = resolve_working_dir(working_dir)?;

    if !working_dir_absolute.exists() {
        println!("No remote defined yet.\n");
        println!("To add one, use: gt remote add ...");
        return Ok(());
    }

    let remotes_dir = working_dir_absolute.join("remotes");

    if !remotes_dir.exists() {
        println!("No remote defined yet.\n");
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
                .filter(|name| name != "pulled.tsv")
        })
        .collect();

    remotes.sort();

    if remotes.is_empty() {
        println!("No remote defined yet.\n");
        println!("To add one, use: gt remote add ...");
    } else {
        for remote in remotes {
            println!("{}", remote);
        }
    }

    Ok(())
}
