use crate::config::{Paths, exit_if_path_outside_of, resolve_working_dir};
use crate::error::{GtRemoteError, Result};
use crate::git::{add_remote, checkout_ref, fetch_remote, get_remote_default_branch, init_git_dir};
use crate::gpg::{
    check_signing_key_exists, gt_dir_exists, import_signing_key_from_remote, init_gpg_dir,
    list_sigs,
};
use std::fs;
use std::io::Write;

pub fn execute(
    working_dir: &str,
    remote_name: &str,
    url: &str,
    pull_dir: &str,
    tag_filter: &str,
    unsecure: bool,
) -> Result<()> {
    let current_dir = std::env::current_dir()?;

    let working_dir_absolute = resolve_working_dir(working_dir)?;
    exit_if_path_outside_of(&current_dir, &working_dir_absolute, "working directory")?;

    if !working_dir_absolute.exists() {
        println!(
            "Working directory '{}' does not exist. Creating it...",
            working_dir_absolute.display()
        );
        fs::create_dir_all(&working_dir_absolute)?;
    }

    if !remote_name
        .chars()
        .all(|c| c.is_alphanumeric() || c == '-' || c == '_')
    {
        return Err(GtRemoteError::InvalidRemoteName(remote_name.to_string()));
    }

    let paths = Paths::new(working_dir_absolute.clone(), remote_name);

    if paths.remote_dir.exists() {
        if paths.pulled_tsv.exists() {
            return Err(GtRemoteError::RemoteExists(remote_name.to_string()));
        } else {
            println!(
                "Remote '{}' exists but without pulled files. Removing it first...",
                remote_name
            );
            fs::remove_dir_all(&paths.remote_dir)?;
        }
    }

    fs::create_dir_all(&paths.remote_dir)?;

    let temp_repo = paths.repo.join("temp_clone");
    if temp_repo.exists() {
        fs::remove_dir_all(&temp_repo)?;
    }

    init_git_dir(&paths.repo)?;
    add_remote(&paths.repo, remote_name, url)?;

    // Copy git config for later restoration
    if let Ok(config_content) = fs::read_to_string(paths.repo.join(".git").join("config")) {
        let mut gitconfig_file = fs::File::create(&paths.gitconfig)?;
        gitconfig_file.write_all(config_content.as_bytes())?;
    }

    let default_branch = get_remote_default_branch(&paths.repo, remote_name)?;

    // Fetch the default branch to get access to the remote's files
    fetch_remote(
        &paths.repo,
        remote_name,
        &format!(
            "refs/heads/{}:refs/remotes/{}",
            default_branch, default_branch
        ),
    )?;

    // Checkout the default branch to populate the working directory
    checkout_ref(
        &paths.repo,
        &format!("refs/remotes/{}/{}", remote_name, default_branch),
    )?;

    // Try to checkout the .gt directory from the remote
    let gt_dir_in_repo = paths.repo.join(".gt");
    if !gt_dir_in_repo.exists() {
        if unsecure {
            println!(
                "Warning: No .gt directory found in remote '{}' branch '{}', ignoring because --unsecure was specified",
                remote_name, default_branch
            );
            write_pull_args(&paths, pull_dir, tag_filter, unsecure)?;
            fs::remove_dir_all(&paths.repo)?;
            return Ok(());
        } else {
            return Err(GtRemoteError::Config(format!(
                "Remote '{}' has no .gt directory defined in branch '{}', unable to fetch GPG key(s). Use --unsecure true to disable this check.",
                remote_name, default_branch
            )));
        }
    }

    if !check_signing_key_exists(&paths.repo, ".gt") {
        if unsecure {
            println!(
                "Warning: Remote '{}' has .gt directory but no signing-key.public.asc. Ignoring because --unsecure was specified",
                remote_name
            );
            write_pull_args(&paths, pull_dir, tag_filter, unsecure)?;
            fs::remove_dir_all(&paths.repo)?;
            return Ok(());
        } else {
            return Err(GtRemoteError::Config(format!(
                "Remote '{}' has .gt directory but no signing-key.public.asc. Use --unsecure true to disable this check.",
                remote_name
            )));
        }
    }

    init_gpg_dir(&paths.gpg_dir)?;

    let num_keys =
        import_signing_key_from_remote(&paths.repo, ".gt", &paths.public_keys_dir, &paths.gpg_dir)?;

    if num_keys == 0 {
        if unsecure {
            println!("Warning: No GPG keys imported, ignoring because --unsecure was specified");
            write_pull_args(&paths, pull_dir, tag_filter, unsecure)?;
            fs::remove_dir_all(&paths.repo)?;
            return Ok(());
        } else {
            fs::remove_dir_all(&paths.gpg_dir)?;
            return Err(GtRemoteError::NoGpgKeys);
        }
    }

    list_sigs(&paths.gpg_dir)?;

    write_pull_args(&paths, pull_dir, tag_filter, unsecure)?;

    fs::remove_dir_all(&paths.repo)?;

    println!(
        "Remote '{}' was set up successfully; imported {} GPG key(s) for verification.",
        remote_name, num_keys
    );
    println!("\nYou are ready to pull files via:");
    println!("gt pull -r {} -p <PATH>", remote_name);

    Ok(())
}

fn write_pull_args(paths: &Paths, pull_dir: &str, tag_filter: &str, unsecure: bool) -> Result<()> {
    let mut file = fs::File::create(&paths.pull_args_file)?;
    writeln!(file, "--directory \"{}\"", pull_dir)?;
    if tag_filter != ".*" {
        writeln!(file, "--tag-filter \"{}\"", tag_filter)?;
    }
    if unsecure {
        writeln!(file, "--unsecure true")?;
    }
    Ok(())
}
