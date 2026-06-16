//! The `gt remote` command (`add` / `list` / `remove`), translated from
//! `src/gt-remote.sh`.

use std::path::Path;

use crate::args::{
    Command, CommandSelection, Param, cyan, exit_if_not_all_arguments_set, parse_arguments, parse_command,
};
use crate::ask::ask_yes_or_no;
use crate::constants::*;
use crate::error::{Exit, GtResult};
use crate::log::{log_error, log_info, log_success, log_warning};
use crate::paths::{RemotePaths, remotes_dir};
use crate::util::{
    check_working_dir_exists, current_dir, delete_dir_chmod_777, exit_if_path_named_is_outside_of,
    exit_if_working_dir_does_not_exist, normalize_path,
};
use crate::{die, exit_with, git, gpg, pulled};

/// Entry point: `gt remote <command> ...`.
pub fn run(args: &[String]) -> GtResult {
    let commands = [
        Command {
            name: "add",
            help: "add a remote",
        },
        Command {
            name: "remove",
            help: "remove a remote",
        },
        Command {
            name: "list",
            help: "list all remotes",
        },
    ];
    match parse_command(&commands, GT_VERSION, "gt-remote.sh", args)? {
        CommandSelection::Selected { name, rest } => match name {
            "add" => add(rest),
            "remove" => remove(rest),
            "list" => list(rest),
            _ => unreachable!("parse_command only returns known commands"),
        },
        CommandSelection::Handled => Ok(()),
    }
}

// ---------------------------------------------------------------------------
// add
// ---------------------------------------------------------------------------

fn add(args: &[String]) -> GtResult {
    let current = current_dir()?;

    let params = vec![
        Param::new("remote", REMOTE_PARAM_PATTERN, "name identifying this remote"),
        Param::new("url", URL_PARAM_PATTERN, "url of the remote repository"),
        Param::new(
            "pullDir",
            PULL_DIR_PARAM_PATTERN,
            "(optional) directory into which files are pulled -- default: lib/<remote>",
        ),
        Param::new("tagFilter", TAG_FILTER_PARAM_PATTERN, TAG_FILTER_PARAM_DOCU),
        Param::new(
            "unsecure",
            UNSECURE_PARAM_PATTERN,
            format!(
                "(optional) if set to true, the remote does not need to have GPG key(s) defined at {DEFAULT_WORKING_DIR}/*.asc -- default: false"
            ),
        ),
        Param::new("workingDir", WORKING_DIR_PARAM_PATTERN, working_dir_param_docu()),
    ];
    let examples = add_examples();

    let mut values = parse_arguments(&params, &examples, GT_VERSION, args)?;

    // apply defaults
    let remote_for_default = values
        .get("remote")
        .cloned()
        .unwrap_or_else(|| "remote-not-defined".to_string());
    values
        .entry("pullDir".to_string())
        .or_insert_with(|| format!("lib/{remote_for_default}"));
    values
        .entry("unsecure".to_string())
        .or_insert_with(|| "false".to_string());
    values
        .entry("workingDir".to_string())
        .or_insert_with(|| DEFAULT_WORKING_DIR.to_string());
    values
        .entry("tagFilter".to_string())
        .or_insert_with(|| ".*".to_string());

    let working_dir = values.get("workingDir").cloned().unwrap();

    // before we report about missing arguments we check that the working dir is inside the call location
    exit_if_path_named_is_outside_of(&working_dir, "working directory", &current)?;
    exit_if_not_all_arguments_set(&params, &values, &examples, GT_VERSION)?;

    let remote = values.get("remote").cloned().unwrap();
    let url = values.get("url").cloned().unwrap();
    let pull_dir = values.get("pullDir").cloned().unwrap();
    let tag_filter = values.get("tagFilter").cloned().unwrap();
    let unsecure = values.get("unsecure").map(|s| s == "true").unwrap_or(false);

    if !is_valid_remote_name(&remote) {
        die!(
            "remote names need to match the regex {} given {remote}",
            cyan("^[a-zA-Z0-9_-]+$")
        );
    }

    let working_dir_absolute = normalize_path(Path::new(&working_dir)).map_err(|_| {
        log_error(&format!("could not deduce workingDirAbsolute from {working_dir}"));
        Exit(1)
    })?;

    if !check_working_dir_exists(&working_dir_absolute) {
        if ask_yes_or_no("Shall I create the work directory for you and continue?") {
            if std::fs::create_dir_all(&working_dir_absolute).is_err() {
                die!(
                    "was not able to create the workingDir {}",
                    working_dir_absolute.display()
                );
            }
            maybe_add_gitignore(&current, &working_dir);
        } else {
            return Err(Exit(9));
        }
    }

    if std::fs::create_dir_all(remotes_dir(&working_dir_absolute)).is_err() {
        die!(
            "was not able to create directory {}",
            remotes_dir(&working_dir_absolute).display()
        );
    }

    let paths = RemotePaths::new(&working_dir_absolute, &remote);

    if paths.remote_dir.is_file() {
        die!(
            "cannot create remote directory, there is a file at this location: {}",
            paths.remote_dir.display()
        );
    } else if paths.remote_dir.is_dir() {
        if paths.pulled_tsv.is_file() {
            return Err({
                log_error(&format!("remote {} already exists with pulled files", cyan(&remote)));
                Exit(1)
            });
        }
        log_error(&format!(
            "remote {} already exists but without pulled files",
            cyan(&remote)
        ));
        if ask_yes_or_no("Shall I remove the remote for you and continue?") {
            remove(&[
                WORKING_DIR_PARAM_PATTERN_LONG.to_string(),
                working_dir_absolute.display().to_string(),
                REMOTE_PARAM_PATTERN_LONG.to_string(),
                remote.clone(),
            ])?;
        } else {
            return Err(Exit(1));
        }
    }

    if std::fs::create_dir(&paths.remote_dir).is_err() {
        die!("failed to create remote directory {}", paths.remote_dir.display());
    }

    // From here on, clean up the remote dir on any unexpected failure (mirrors the
    // Bash EXIT trap: delete the dir and re-create it empty so that one can still
    // establish trust manually).
    let result = add_after_remote_dir_created(&paths, &remote, &url, &pull_dir, &tag_filter, unsecure, &working_dir);
    if result.is_err() && paths.remote_dir.is_dir() {
        let _ = delete_dir_chmod_777(&paths.remote_dir);
        let _ = std::fs::create_dir(&paths.remote_dir);
    }
    result
}

#[allow(clippy::too_many_arguments)]
fn add_after_remote_dir_created(
    paths: &RemotePaths,
    remote: &str,
    url: &str,
    pull_dir: &str,
    tag_filter: &str,
    unsecure: bool,
    _working_dir: &str,
) -> GtResult {
    // write pull.args (best effort; warn on failure)
    let pull_args = format!("{PULL_DIR_PARAM_PATTERN_LONG} \"{pull_dir}\"\n");
    if std::fs::write(&paths.pull_args_file, pull_args).is_err() {
        log_warning_could_not_write_pull_args(
            "the pull directory",
            pull_dir,
            &paths.pull_args_file,
            PULL_DIR_PARAM_PATTERN_LONG,
            remote,
        );
    }
    if tag_filter != ".*" {
        let line = format!("{} \"{tag_filter}\"\n", TAG_FILTER_PARAM_PATTERN.join("|"));
        if append_to_file(&paths.pull_args_file, &line).is_err() {
            log_warning_could_not_write_pull_args(
                "the tag filter",
                tag_filter,
                &paths.pull_args_file,
                TAG_FILTER_PARAM_PATTERN_LONG,
                remote,
            );
        }
    }

    if std::fs::create_dir(&paths.public_keys_dir).is_err() {
        die!(
            "was not able to create the public keys dir at {}",
            paths.public_keys_dir.display()
        );
    }
    gpg::initialise_gpg_dir(&paths.gpg_dir)?;
    git::initialise_git_dir(&paths.repo)?;

    git::remote_add(&paths.repo, remote, url)?;

    // copy the git config away so one can commit it (used to restore the config
    // for those who have not set up the remote on their machine)
    let git_config = paths.repo.join(".git").join("config");
    if std::fs::copy(&git_config, &paths.gitconfig).is_err() {
        die!(
            "could not copy {} to {}",
            git_config.display(),
            paths.gitconfig.display()
        );
    }

    let default_branch = git::determine_default_branch(&paths.repo, remote);

    if !git::checkout_gt_dir(&paths.repo, remote, &default_branch, DEFAULT_WORKING_DIR)? {
        if unsecure {
            log_warning(&format!(
                "no {DEFAULT_WORKING_DIR} directory defined in remote {} which means no GPG key available, ignoring it because {UNSECURE_PARAM_PATTERN_LONG} true was specified",
                cyan(remote)
            ));
            let _ = append_to_file(&paths.pull_args_file, &format!("{UNSECURE_PARAM_PATTERN_LONG} true\n"));
            return Ok(());
        }
        exit_with!(
            1,
            "remote {} has no directory {} defined in branch {}, unable to fetch the GPG key(s) -- you can disable this check via {UNSECURE_PARAM_PATTERN_LONG} true",
            cyan(remote),
            cyan(".gt"),
            cyan(&default_branch)
        );
    }

    let signing_key = paths.repo.join(DEFAULT_WORKING_DIR).join(SIGNING_KEY_ASC);
    if !signing_key.is_file() {
        if unsecure {
            log_warning(&format!(
                "remote {} has a directory {} but no {SIGNING_KEY_ASC} in it. Ignoring it because {UNSECURE_PARAM_PATTERN_LONG} true was specified",
                cyan(remote),
                cyan(DEFAULT_WORKING_DIR)
            ));
            let _ = append_to_file(&paths.pull_args_file, &format!("{UNSECURE_PARAM_PATTERN_LONG} true\n"));
            return Ok(());
        }
        exit_with!(
            1,
            "remote {} has a directory {} but no {SIGNING_KEY_ASC} in it -- you can disable this check via {UNSECURE_PARAM_PATTERN_LONG} true",
            cyan(remote),
            cyan(DEFAULT_WORKING_DIR)
        );
    }

    // end of checks, can start importing keys
    let repo_gt_dir = paths.repo.join(DEFAULT_WORKING_DIR);
    let imported = gpg::import_remotes_pulled_signing_key(
        remote,
        &repo_gt_dir,
        &paths.gpg_dir,
        &paths.public_keys_dir,
        &paths.last_signing_key_check_file,
        &repo_gt_dir,
    )?;
    let number_of_imported_keys: u32 = if imported { 1 } else { 0 };

    if number_of_imported_keys == 0 {
        if unsecure {
            log_warning(&format!(
                "no GPG keys imported, ignoring it because {UNSECURE_PARAM_PATTERN_LONG} true was specified"
            ));
            return Ok(());
        }
        return Err(gpg::exit_because_signing_key_not_imported(
            remote,
            &paths.public_keys_dir,
            &paths.gpg_dir,
            UNSECURE_PARAM_PATTERN_LONG,
        ));
    }

    gpg::list_sig(&paths.gpg_dir)?;
    gpg::log_setup_success(remote, number_of_imported_keys);
    Ok(())
}

fn maybe_add_gitignore(current: &Path, working_dir: &str) {
    let git_ignore = current.join(".gitignore");
    if !git_ignore.is_file() {
        return;
    }
    let content = std::fs::read_to_string(&git_ignore).unwrap_or_default();
    if content.contains(&format!("{working_dir}/")) {
        return;
    }
    if ask_yes_or_no(&format!(
        "Shall I add gt specific ignore patterns to {}",
        git_ignore.display()
    )) {
        let patterns = format!("\n# gt (https://github.com/tegonal/gt)\n{working_dir}/**/repo\n{working_dir}/**/gpg\n");
        if append_to_file(&git_ignore, &patterns).is_err() {
            log_warning(&format!(
                "was not able to write gpg ignore patterns to {}, please add them manually",
                git_ignore.display()
            ));
        }
    }
}

// ---------------------------------------------------------------------------
// list
// ---------------------------------------------------------------------------

fn list(args: &[String]) -> GtResult {
    match list_raw(args) {
        Ok(output) => {
            if output.is_empty() {
                log_info("No remote defined yet.");
                println!();
                println!("To add one, use: {COLOR_MAGENTA}gt remote add ...{COLOR_RESET}");
                println!("Following the output of calling `gt remote add --help`:");
                println!();
                // print add --help (parse_arguments prints help and returns Exit(99))
                let _ = add(&["--help".to_string()]);
            } else {
                println!("{output}");
            }
            Ok(())
        }
        // exit 99 means --help/--version was handled (and already printed)
        Err(Exit(99)) => Ok(()),
        Err(e) => Err(e),
    }
}

/// Returns the sorted, newline-joined remote names (empty string if none).
fn list_raw(args: &[String]) -> Result<String, Exit> {
    let current = current_dir()?;

    let params = vec![Param::new(
        "workingDir",
        WORKING_DIR_PARAM_PATTERN,
        working_dir_param_docu(),
    )];
    let examples = "# lists all defined remotes in .gt\ngt remote list\n\n# uses a custom working directory\ngt remote list -w .github/.gt";

    let mut values = parse_arguments(&params, examples, GT_VERSION, args)?;
    values
        .entry("workingDir".to_string())
        .or_insert_with(|| DEFAULT_WORKING_DIR.to_string());
    let working_dir = values.get("workingDir").cloned().unwrap();

    exit_if_working_dir_does_not_exist(Path::new(&working_dir))?;
    exit_if_path_named_is_outside_of(&working_dir, "working directory", &current)?;
    exit_if_not_all_arguments_set(&params, &values, examples, GT_VERSION)?;

    let working_dir_absolute = normalize_path(Path::new(&working_dir)).map_err(|_| {
        log_error(&format!("could not deduce workingDirAbsolute from {working_dir}"));
        Exit(1)
    })?;

    let remotes = remotes_dir(&working_dir_absolute);
    if !remotes.is_dir() {
        return Ok(String::new());
    }
    let mut names: Vec<String> = std::fs::read_dir(&remotes)
        .map_err(|_| Exit(1))?
        .flatten()
        .filter(|e| e.path().is_dir())
        .filter_map(|e| e.file_name().into_string().ok())
        .collect();
    names.sort();
    Ok(names.join("\n"))
}

// ---------------------------------------------------------------------------
// remove
// ---------------------------------------------------------------------------

fn remove(args: &[String]) -> GtResult {
    let current = current_dir()?;

    let params = vec![
        Param::new(
            "remote",
            REMOTE_PARAM_PATTERN,
            "define the name of the remote which shall be removed",
        ),
        Param::new(
            "deletePulledFiles",
            DELETE_PULLED_FILES_PARAM_PATTERN,
            "(optional) if set to true, then all files defined in the remote's pulled.tsv are deleted as well -- default: false",
        ),
        Param::new("workingDir", WORKING_DIR_PARAM_PATTERN, working_dir_param_docu()),
    ];
    let examples = remove_examples();

    let mut values = parse_arguments(&params, &examples, GT_VERSION, args)?;
    values
        .entry("workingDir".to_string())
        .or_insert_with(|| DEFAULT_WORKING_DIR.to_string());
    values
        .entry("deletePulledFiles".to_string())
        .or_insert_with(|| "false".to_string());

    let working_dir = values.get("workingDir").cloned().unwrap();

    exit_if_working_dir_does_not_exist(Path::new(&working_dir))?;
    exit_if_path_named_is_outside_of(&working_dir, "working directory", &current)?;
    exit_if_not_all_arguments_set(&params, &values, &examples, GT_VERSION)?;

    let remote = values.get("remote").cloned().unwrap();
    let delete_pulled_files = values.get("deletePulledFiles").map(|s| s == "true").unwrap_or(false);

    let working_dir_absolute = normalize_path(Path::new(&working_dir)).map_err(|_| {
        log_error(&format!("could not deduce workingDirAbsolute from {working_dir}"));
        Exit(1)
    })?;

    let paths = RemotePaths::new(&working_dir_absolute, &remote);

    if paths.remote_dir.is_file() {
        exit_with!(
            1,
            "cannot delete remote {}, looks like it is broken there is a file at this location: {}",
            cyan(&remote),
            paths.remote_dir.display()
        );
    }
    if !paths.remote_dir.is_dir() {
        log_error(&format!(
            "remote {} does not exist, check for typos.\nFollowing the remotes which exist:",
            cyan(&remote)
        ));
        let _ = list(&[
            WORKING_DIR_PARAM_PATTERN_LONG.to_string(),
            working_dir_absolute.display().to_string(),
        ]);
        return Err(Exit(9));
    }

    if paths.pull_hook_file.is_file() {
        log_warning(&format!(
            "detected a pull-hook.sh in the remote {remote}, you might want to move it away first."
        ));
        if !ask_yes_or_no("shall I continue and delete it as well?") {
            log_info(&format!("removing remote {} aborted", cyan(&remote)));
            return Err(Exit(10));
        }
    }

    if paths.pulled_tsv.is_file() {
        if !delete_pulled_files {
            log_info(&format!(
                "detected a pulled.tsv in the remote {remote}. You might want to pass '--delete-pulled-files true' in case you want to delete all files"
            ));
            if ask_yes_or_no(
                "Shall I abort? If you don't choose y, then I will go on and delete the remote without deleting the pulled files as defined in pulled.tsv",
            ) {
                log_info(&format!("removing remote {} aborted", cyan(&remote)));
                return Err(Exit(10));
            }
        } else {
            let entries = pulled::read_pulled_tsv(&working_dir_absolute, &remote, &paths.pulled_tsv)?;
            let mut number_of_deleted_files = 0u32;
            if let Some(entries) = entries {
                for entry in entries {
                    if std::fs::remove_file(&entry.absolute_path).is_ok() {
                        number_of_deleted_files += 1;
                    }
                }
            }
            log_info(&format!("deleted {number_of_deleted_files} pulled files"));
        }
    }

    if delete_dir_chmod_777(&paths.remote_dir).is_err() {
        die!("was not able to delete remoteDir {}", paths.remote_dir.display());
    }
    log_success(&format!("removed remote {}", cyan(&remote)));
    Ok(())
}

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------

fn is_valid_remote_name(remote: &str) -> bool {
    !remote.is_empty()
        && remote
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || c == '_' || c == '-')
}

fn append_to_file(path: &Path, content: &str) -> std::io::Result<()> {
    use std::io::Write;
    let mut file = std::fs::OpenOptions::new().create(true).append(true).open(path)?;
    file.write_all(content.as_bytes())
}

fn log_warning_could_not_write_pull_args(what: &str, value: &str, file: &Path, param_long: &str, remote: &str) {
    log_warning(&format!(
        "was not able to write {what} {value} into {}\nPlease do it manually or use {param_long} when using 'gt pull' with the remote {remote}",
        file.display()
    ));
}

fn add_examples() -> String {
    format!(
        "# adds the remote tegonal-scripts with url https://github.com/tegonal/scripts\n\
# uses the default location lib/tegonal-scripts for the files which will be pulled from this remote\n\
gt remote add -r tegonal-scripts -u https://github.com/tegonal/scripts\n\
\n\
# uses a custom pull directory, files of the remote tegonal-scripts will now\n\
# be placed into scripts/lib/tegonal-scripts instead of default location lib/tegonal-scripts\n\
gt remote add -r tegonal-scripts -u https://github.com/tegonal/scripts -d scripts/lib/tegonal-scripts\n\
\n\
# defines a tag-filter which is used when determining the latest version (in `gt pull` and in `gt update`)\n\
gt remote add -r tegonal-scripts --tag-filter \"^v[0-9]+\\.[0-9]+\\.[0-9]+$\"\n\
\n\
# Does not complain if the remote does not provide a GPG key for verification (but still tries to fetch one)\n\
gt remote add -r tegonal-scripts -u https://github.com/tegonal/scripts --unsecure true\n\
\n\
# uses a custom working directory\n\
gt remote add -r tegonal-scripts -u https://github.com/tegonal/scripts -w .github/{DEFAULT_WORKING_DIR}"
    )
}

fn remove_examples() -> String {
    format!(
        "# removes the remote tegonal-scripts (but keeps already pulled files)\n\
gt remote remove -r tegonal-scripts\n\
\n\
# removes the remote tegonal-scripts and all pulled files\n\
gt remote remove -r tegonal-scripts --delete-pulled-files true\n\
\n\
# uses a custom working directory\n\
gt remote remove -r tegonal-scripts -w .github/{DEFAULT_WORKING_DIR}"
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn valid_remote_names() {
        assert!(is_valid_remote_name("tegonal-scripts"));
        assert!(is_valid_remote_name("abc_123"));
        assert!(is_valid_remote_name("ABC"));
    }

    #[test]
    fn invalid_remote_names() {
        assert!(!is_valid_remote_name(""));
        assert!(!is_valid_remote_name("bad name"));
        assert!(!is_valid_remote_name("with/slash"));
        assert!(!is_valid_remote_name("dot.dot"));
    }
}
