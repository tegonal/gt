//! The `gt pull` command, translated from `src/gt-pull.sh`.

use std::io::Write;
use std::path::{Path, PathBuf};

use crate::args::{Param, cyan, exit_if_not_all_arguments_set, parse_arguments, parse_arguments_lenient};
use crate::ask::ask_yes_or_no;
use crate::constants::*;
use crate::error::{Exit, GtResult};
use crate::log::{log_error, log_info, log_success, log_warning};
use crate::paths::RemotePaths;
use crate::util::{
    RepoCleanup, check_working_dir_exists, current_dir, delete_dir_chmod_777, elapsed_seconds,
    exit_if_path_named_is_outside_of, exit_if_remote_dir_does_not_exist, normalize_path, read_pull_args,
    realpath_relative_to, sha512sum, simple_diff_chars, timestamp_in_ms,
};
use crate::{die, git, gpg, pulled};

/// Entry point: `gt pull <args>`.
pub fn run(args: &[String]) -> GtResult {
    let start_ms = timestamp_in_ms();
    let current = current_dir()?;

    // -------------------------------------------------------------------------
    // Parameter definitions (same order / names as the Bash script)
    // -------------------------------------------------------------------------
    let params = vec![
        Param::new("remote", REMOTE_PARAM_PATTERN, "name of the remote repository"),
        Param::new("tag", TAG_PARAM_PATTERN, "git tag used to pull the file/directory"),
        Param::new(
            "path",
            PATH_PARAM_PATTERN,
            "path in remote repository which shall be pulled (file or directory)",
        ),
        Param::new(
            "pullDir",
            PULL_DIR_PARAM_PATTERN,
            "(optional) directory into which files are pulled",
        ),
        Param::new(
            "chopPath",
            CHOP_PATH_PARAM_PATTERN,
            "(optional) if set to true, then files are put into the pull directory without the path specified",
        ),
        Param::new(
            "targetFileName",
            TARGET_FILE_NAME_PARAM_PATTERN,
            "(optional) if you want to use a different file name then the one specified in the remote",
        ),
        Param::new("tagFilter", TAG_FILTER_PARAM_PATTERN, TAG_FILTER_PARAM_DOCU),
        Param::new(
            "autoTrust",
            &[AUTO_TRUST_PARAM_PATTERN_LONG],
            "(optional) if set to true, then all keys are imported without manual consent",
        ),
        Param::new(
            "unsecure",
            UNSECURE_PARAM_PATTERN,
            "(optional) if set to true, the remote does not need to have GPG key(s) defined",
        ),
        Param::new(
            "forceNoVerification",
            UNSECURE_NO_VERIFICATION_PARAM_PATTERN,
            "(optional) if set to true, implies unsecure true and does not verify even if gpg keys are in store",
        ),
        Param::new("workingDir", WORKING_DIR_PARAM_PATTERN, working_dir_param_docu()),
    ];
    let examples = pull_examples();

    // -------------------------------------------------------------------------
    // First pass (lenient) – only to discover workingDir and remote so we can
    // locate pull.args.
    // -------------------------------------------------------------------------
    let first_pass = parse_arguments_lenient(&params, &examples, GT_VERSION, args);
    let mut first_values = match first_pass {
        Ok(v) => v,
        Err(Exit(99)) => return Ok(()), // --help / --version
        Err(e) => return Err(e),
    };
    let working_dir = first_values
        .remove("workingDir")
        .unwrap_or_else(|| DEFAULT_WORKING_DIR.to_string());

    // -------------------------------------------------------------------------
    // Load pull.args (if remote known) and prepend them to user args.
    // -------------------------------------------------------------------------
    let mut combined: Vec<String> = Vec::new();
    if let Some(remote_name) = first_values.get("remote")
        && !remote_name.is_empty()
    {
        let pull_args_file = Path::new(&working_dir)
            .join("remotes")
            .join(remote_name)
            .join("pull.args");
        let pull_args = read_pull_args(&pull_args_file);
        combined.extend(pull_args);
    }
    combined.extend_from_slice(args);

    // -------------------------------------------------------------------------
    // Second pass (strict) with pull.args + user args.
    // -------------------------------------------------------------------------
    let mut values = parse_arguments(&params, &examples, GT_VERSION, &combined)?;

    // Apply defaults (must match Bash script order)
    let _ = values
        .entry("workingDir".to_string())
        .or_insert_with(|| DEFAULT_WORKING_DIR.to_string());
    let _ = values
        .entry("chopPath".to_string())
        .or_insert_with(|| "false".to_string());
    let _ = values
        .entry("autoTrust".to_string())
        .or_insert_with(|| "false".to_string());
    let _ = values
        .entry("forceNoVerification".to_string())
        .or_insert_with(|| "false".to_string());
    let force_no_verification = values.get("forceNoVerification").map(|s| s == "true").unwrap_or(false);
    if !values.contains_key("unsecure") {
        values.insert("unsecure".to_string(), force_no_verification.to_string());
    }
    let _ = values.entry("tag".to_string()).or_insert_with(|| FAKE_TAG.to_string());
    let _ = values
        .entry("tagFilter".to_string())
        .or_insert_with(|| ".*".to_string());
    let _ = values
        .entry("targetFileName".to_string())
        .or_insert_with(|| "".to_string());

    let working_dir_str = values.get("workingDir").cloned().unwrap();

    // -------------------------------------------------------------------------
    // Validation order (must match Bash to determine which error the user sees first)
    // -------------------------------------------------------------------------
    if !check_working_dir_exists(Path::new(&working_dir_str)) {
        return Err(Exit(9));
    }
    exit_if_path_named_is_outside_of(&working_dir_str, "working directory", &current)?;

    // If remote is set but pullDir is not and remote dir absent, show missing-remote first.
    let remote_str = values.get("remote").cloned().unwrap_or_default();
    let pull_dir_set = values.contains_key("pullDir") && values.get("pullDir").map(|s| !s.is_empty()).unwrap_or(false);
    if !pull_dir_set && !remote_str.is_empty() {
        let wd_abs = normalize_path(Path::new(&working_dir_str)).map_err(|_| {
            log_error(&format!("could not deduce workingDirAbsolute from {working_dir_str}"));
            Exit(1)
        })?;
        let _ = exit_if_remote_dir_does_not_exist(&wd_abs, &remote_str);
    }

    exit_if_not_all_arguments_set(&params, &values, &examples, GT_VERSION)?;
    let remote = values.get("remote").cloned().unwrap();

    let working_dir_absolute = normalize_path(Path::new(&working_dir_str)).map_err(|_| {
        log_error(&format!("could not deduce workingDirAbsolute from {working_dir_str}"));
        Exit(1)
    })?;

    let paths = RemotePaths::new(&working_dir_absolute, &remote);

    if paths.repo.is_file() {
        die!(
            "looks like the remote {} is broken there is a file at the repo's location: {}",
            cyan(&remote),
            paths.repo.display()
        );
    }

    // Re-init repo if .git missing
    if !paths.repo.join(".git").is_dir() {
        log_info(&format!(
            "repo directory (or its .git directory) does not exist for remote {}. Going to re-initialise it based on the stored gitconfig",
            cyan(&remote)
        ));
        git::re_initialise_git_dir(&paths.repo, &paths.gitconfig)?;
    } else if !git::repo_has_remote(&paths.repo, &remote) {
        log_error(&format!(
            "looks like the .git directory of remote {} is broken. There is no remote {} set up in its gitconfig. Following the remotes:",
            cyan(&remote),
            cyan(&remote)
        ));
        let _ = std::process::Command::new("git")
            .arg(format!("--git-dir={}", paths.repo.join(".git").display()))
            .args(["remote"])
            .status();
        if paths.gitconfig.is_file() {
            if ask_yes_or_no(&format!(
                "Shall I delete the repo and re-initialise it based on {}?",
                paths.gitconfig.display()
            )) {
                let _ = delete_dir_chmod_777(&paths.repo);
                git::re_initialise_git_dir(&paths.repo, &paths.gitconfig)?;
            } else {
                return Err(Exit(1));
            }
        } else {
            log_info(&format!(
                "{} does not exist, cannot ask to re-initialise the repo, must abort",
                paths.gitconfig.display()
            ));
            return Err(Exit(1));
        }
    }

    let pull_dir = values.get("pullDir").cloned().unwrap();
    let pull_dir_absolute = normalize_path(Path::new(&pull_dir)).map_err(|_| {
        log_error(&format!("could not deduce pullDirAbsolute from {pull_dir}"));
        Exit(1)
    })?;
    exit_if_path_named_is_outside_of(&pull_dir_absolute.display().to_string(), "pull directory", &current)?;

    let path_str = values.get("path").cloned().unwrap();
    if path_str.starts_with('/') {
        die!("Leading / not allowed for path, given: {}", cyan(&path_str));
    }

    let target_file_name = values.get("targetFileName").cloned().unwrap_or_default();
    if target_file_name.contains('/') {
        die!("/ not allowed in the targetFileName, given {}", target_file_name);
    }

    // -------------------------------------------------------------------------
    // pulled.tsv initialisation / validation
    // -------------------------------------------------------------------------
    if !paths.pulled_tsv.is_file() {
        pulled::initialise_pulled_tsv(&paths.pulled_tsv)?;
    } else {
        pulled::validate_pulled_tsv_header(&paths.pulled_tsv)?;
    }

    // -------------------------------------------------------------------------
    // Determine tag to pull
    // -------------------------------------------------------------------------
    let tag = values.get("tag").cloned().unwrap();
    let tag_filter = values.get("tagFilter").cloned().unwrap_or_else(|| ".*".to_string());
    let tag_to_pull = if tag == FAKE_TAG {
        git::latest_remote_tag(&paths.repo, &remote, &tag_filter)?
    } else {
        tag
    };

    // -------------------------------------------------------------------------
    // Resolve verification policy (doVerification)
    // -------------------------------------------------------------------------
    let auto_trust = values.get("autoTrust").map(|s| s == "true").unwrap_or(false);
    let unsecure = values.get("unsecure").map(|s| s == "true").unwrap_or(false);

    let mut do_verification = !force_no_verification;

    if do_verification {
        if paths.gpg_dir.is_dir() {
            // periodic check (simplified)
            if paths.public_keys_dir.join(SIGNING_KEY_ASC).is_file() && paths.last_signing_key_check_file.is_file() {
                let check_date = std::fs::read_to_string(&paths.last_signing_key_check_file)
                    .unwrap_or_default()
                    .trim()
                    .to_string();
                let days_since_check = if check_date.is_empty() {
                    999
                } else {
                    match check_date_to_days_ago(&check_date) {
                        Ok(d) => d,
                        Err(_) => {
                            die!(
                                "looks like the date {} in {} is not in format YYYY-mm-dd",
                                cyan(&check_date),
                                paths.last_signing_key_check_file.display()
                            );
                        }
                    }
                };
                if days_since_check > 30 {
                    log_warning(&format!(
                        "time to check if the signing key of remote {} is still valid. Last check was on {}. Skipping the reset re-check because the reset command is not yet ported.",
                        cyan(&remote),
                        check_date
                    ));
                }
            }
        } else if paths.gpg_dir.is_file() {
            die!(
                "looks like the remote {} is broken there is a file at the gpg dir's location: {}",
                cyan(&remote),
                paths.gpg_dir.display()
            );
        } else {
            // gpgDir does not exist
            log_info(&format!(
                "gpg directory does not exist at {}\nWe are going to import {SIGNING_KEY_ASC} from {}",
                paths.gpg_dir.display(),
                paths.public_keys_dir.display()
            ));

            if !paths.public_keys_dir.join(SIGNING_KEY_ASC).is_file() {
                if unsecure {
                    log_warning(&format!(
                        "{SIGNING_KEY_ASC} not found, won't be able to verify files (which is OK because '{UNSECURE_PARAM_PATTERN_LONG} true' was specified)"
                    ));
                    do_verification = false;
                    gpg::initialise_gpg_dir(&paths.gpg_dir)?;
                } else {
                    die!("{SIGNING_KEY_ASC} not defined in {}", paths.public_keys_dir.display());
                }
            } else {
                // Import flow
                gpg::initialise_gpg_dir(&paths.gpg_dir)?;
                let imported = gpg::import_remotes_pulled_signing_key(
                    &remote,
                    &paths.public_keys_dir,
                    &paths.gpg_dir,
                    &paths.public_keys_dir,
                    &paths.last_signing_key_check_file,
                    &paths.public_keys_dir,
                )?;
                let number_of_imported_keys: u32 = if imported { 1 } else { 0 };

                if number_of_imported_keys == 0 {
                    if unsecure {
                        log_warning(&format!(
                            "{SIGNING_KEY_ASC} declined, won't be able to verify files (which is OK because '{UNSECURE_PARAM_PATTERN_LONG} true' was specified)"
                        ));
                        do_verification = false;
                    } else {
                        return Err(gpg::exit_because_signing_key_not_imported(
                            &remote,
                            &paths.public_keys_dir,
                            &paths.gpg_dir,
                            UNSECURE_PARAM_PATTERN_LONG,
                        ));
                    }
                }
            }
        }

        if unsecure && do_verification {
            let trust_db = paths.gpg_dir.join("trustdb.gpg");
            if trust_db.is_file() {
                log_info(&format!(
                    "gpg seems to be initialised (found {}), going to perform verification even though '{UNSECURE_PARAM_PATTERN_LONG} true' was specified",
                    trust_db.display()
                ));
            } else {
                do_verification = false;
            }
        }
    }

    // -------------------------------------------------------------------------
    // Call the internal routine (tuple contract preserved)
    // -------------------------------------------------------------------------
    pull_without_arg_checks(
        &current,
        start_ms,
        &working_dir_absolute,
        &remote,
        &tag_to_pull,
        &path_str,
        &pull_dir_absolute,
        values.get("chopPath").map(|s| s == "true").unwrap_or(false),
        &target_file_name,
        &tag_filter,
        auto_trust,
        unsecure,
        force_no_verification,
        do_verification,
    )
}

#[allow(clippy::too_many_arguments)]
fn pull_without_arg_checks(
    current_dir: &Path,
    start_ms: u128,
    working_dir_absolute: &Path,
    remote: &str,
    tag_to_pull: &str,
    path: &str,
    pull_dir_absolute: &Path,
    chop_path: bool,
    target_file_name: &str,
    _tag_filter: &str,
    _auto_trust: bool,
    unsecure: bool,
    _force_no_verification: bool,
    do_verification: bool,
) -> GtResult {
    let paths = RemotePaths::new(working_dir_absolute, remote);

    if !pull_dir_absolute.is_dir() && std::fs::create_dir_all(pull_dir_absolute).is_err() {
        die!("failed to create the pull directory {}", pull_dir_absolute.display());
    }

    let mut guard = RepoCleanup::new(&paths.repo);

    git::fetch_tag_from_remote(&paths.repo, remote, tag_to_pull)?;

    git::checkout_tag_path(&paths.repo, tag_to_pull, path)?;

    // Error if directory pull + targetFileName
    if paths.repo.join(path).is_dir() && !target_file_name.is_empty() {
        die!(
            "you cannot specify --target-file-name when you pull a directory -- what you can do though:\n1. pull the directory\n2. rename the file(s) manually\n3. adjust the entries in pulled.tsv\n\nNext time you gt re-pull or gt update the rename will be taken into account"
        );
    }

    let sig_extension = "sig";

    // Pull signature for single files
    if do_verification && paths.repo.join(path).is_file() {
        let sig_path = format!("{path}.{sig_extension}");
        let checkout = std::process::Command::new("git")
            .arg("-C")
            .arg(&paths.repo)
            .args(["checkout", &format!("tags/{tag_to_pull}"), "--", &sig_path])
            .status();
        if !matches!(checkout, Ok(s) if s.success()) && !unsecure {
            eprintln!(
                "no signature file found for {}, aborting pull from remote {}",
                cyan(path),
                cyan(remote)
            );
            if !unsecure {
                eprintln!(
                    " -- you can disable this check via: {} true\n",
                    UNSECURE_PARAM_PATTERN_LONG
                );
            } else {
                eprintln!(
                    " -- you can disable this check via: {} true\n",
                    UNSECURE_NO_VERIFICATION_PARAM_PATTERN_LONG
                );
            }
            return Err(Exit(1));
        }
    }

    // Pull hooks
    let hook_before = if paths.pull_hook_file.is_file() {
        let hook_name = remote.replace('-', "_");
        Some(format!(
            "source {} && gt_pullHook_{}_before",
            paths.pull_hook_file.display(),
            hook_name
        ))
    } else {
        None
    };
    let hook_after = if paths.pull_hook_file.is_file() {
        let hook_name = remote.replace('-', "_");
        Some(format!(
            "source {} && gt_pullHook_{}_after",
            paths.pull_hook_file.display(),
            hook_name
        ))
    } else {
        None
    };

    let mut number_of_pulled_files = 0u32;

    // Collect files to process
    let repo_path = paths.repo.join(path);
    let files: Vec<PathBuf> = collect_files(&repo_path, sig_extension);

    for absolute_file in files {
        // Defense in depth: re-check target is inside currentDir
        let inside = crate::util::path_is_inside_of(&absolute_file, current_dir).map_err(|_| {
            log_error(&format!(
                "the target path {} is not inside of {}",
                absolute_file.display(),
                current_dir.display()
            ));
            Exit(1)
        })?;
        if !inside {
            die!(
                "the target path {} is not inside of {}",
                absolute_file.display(),
                current_dir.display()
            );
        }

        let repo_file = absolute_file.strip_prefix(&paths.repo).unwrap().to_str().unwrap();
        let sig_file = PathBuf::from(format!("{}.{sig_extension}", absolute_file.display()));

        if do_verification && sig_file.is_file() {
            log_info(&format!("verifying {} from remote {}", cyan(repo_file), cyan(remote)));

            let target_in_pull = pull_dir_absolute.join(repo_file);
            if target_in_pull.is_dir() {
                die!(
                    "there exists a directory with the same name at {}",
                    target_in_pull.display()
                );
            }

            let ok = gpg::verify_file(&paths.gpg_dir, &sig_file, &absolute_file)?;
            if !ok {
                die!(
                    "gpg verification failed for file {} from remote {}",
                    cyan(repo_file),
                    cyan(remote)
                );
            }

            let (_key_id, revoked) = gpg::verify_and_check_revocation(&sig_file, &paths.gpg_dir)?;
            if revoked {
                die!(
                    "the key which signed the file {} from remote {} was revoked",
                    cyan(repo_file),
                    cyan(remote)
                );
            }

            let _ = std::fs::remove_file(&sig_file);

            move_file(
                &mut number_of_pulled_files,
                &paths,
                remote,
                tag_to_pull,
                repo_file,
                &absolute_file,
                pull_dir_absolute,
                chop_path,
                target_file_name,
                working_dir_absolute,
                current_dir,
                &hook_before,
                &hook_after,
                path,
            )?;
        } else if do_verification {
            log_warning(&format!(
                "there was no corresponding *.{sig_extension} file for {} in remote {}, skipping it",
                cyan(repo_file),
                cyan(remote)
            ));
            if !unsecure {
                eprintln!(
                    " -- you can disable this check via: {} true\n",
                    UNSECURE_PARAM_PATTERN_LONG
                );
            } else {
                eprintln!(
                    " -- you can disable this check via: {} true\n",
                    UNSECURE_NO_VERIFICATION_PARAM_PATTERN_LONG
                );
            }
            let _ = std::fs::remove_file(&absolute_file);
        } else {
            move_file(
                &mut number_of_pulled_files,
                &paths,
                remote,
                tag_to_pull,
                repo_file,
                &absolute_file,
                pull_dir_absolute,
                chop_path,
                target_file_name,
                working_dir_absolute,
                current_dir,
                &hook_before,
                &hook_after,
                path,
            )?;
        }
    }

    // Disable cleanup guard on normal exit (keep the repo as-is for next pull)
    guard.disable();

    let elapsed = elapsed_seconds(start_ms);
    if number_of_pulled_files > 1 {
        log_success(&format!(
            "{number_of_pulled_files} files pulled from {remote} {path} in {elapsed} seconds"
        ));
    } else if number_of_pulled_files == 1 {
        log_success(&format!("file {path} pulled from {remote} in {elapsed} seconds"));
    } else {
        die!("0 files could be pulled from {remote}, most likely verification failed, see above.");
    }

    Ok(())
}

fn collect_files(repo_path: &Path, sig_extension: &str) -> Vec<PathBuf> {
    let mut files = Vec::new();
    if repo_path.is_file() {
        files.push(repo_path.to_path_buf());
    } else if repo_path.is_dir() {
        for entry in walkdir(repo_path) {
            if let Some(name) = entry.file_name()
                && let Some(s) = name.to_str()
                && s.ends_with(sig_extension)
                && s.rfind('.') == Some(s.len() - sig_extension.len() - 1)
            {
                continue;
            }
            files.push(entry);
        }
    }
    files.sort();
    files
}

fn walkdir(dir: &Path) -> Vec<PathBuf> {
    let mut result = Vec::new();
    if let Ok(entries) = std::fs::read_dir(dir) {
        for entry in entries.flatten() {
            let path = entry.path();
            if path.is_dir() {
                result.extend_from_slice(&walkdir(&path));
            } else if path.is_file() {
                result.push(path);
            }
        }
    }
    result
}

#[allow(clippy::too_many_arguments)]
fn move_file(
    number_of_pulled_files: &mut u32,
    paths: &RemotePaths,
    remote: &str,
    tag_to_pull: &str,
    repo_file: &str,
    absolute_source: &Path,
    pull_dir_absolute: &Path,
    chop_path: bool,
    target_file_name: &str,
    working_dir_absolute: &Path,
    current_dir: &Path,
    hook_before: &Option<String>,
    hook_after: &Option<String>,
    original_path: &str,
) -> GtResult {
    // Target path computation (mirrors gt_pull_moveFile)
    let source_is_dir = paths.repo.join(original_path).is_dir();
    let target_file = compute_target_file(repo_file, chop_path, source_is_dir, original_path, target_file_name);
    let absolute_target = pull_dir_absolute.join(&target_file);
    let parent_dir = absolute_target.parent().unwrap_or(pull_dir_absolute);
    if !parent_dir.is_dir() && std::fs::create_dir_all(parent_dir).is_err() {
        die!(
            "was not able to create the parent dir for {}",
            absolute_target.display()
        );
    }

    // Compute relativeTarget via realpath --relative-to
    let relative_target = normalize_path(absolute_target.as_path()).map_err(|_| {
        log_error(&format!(
            "could not determine relativeTarget for {}",
            absolute_target.display()
        ));
        Exit(1)
    })?;
    let relative_target_str = realpath_relative_to(&relative_target, working_dir_absolute)
        .unwrap_or_else(|_| relative_target.clone())
        .display()
        .to_string();

    // Compute sha512 and hasPlaceholder
    let sha = sha512sum(absolute_source)?;
    let has_placeholder = if pulled::has_gt_placeholder(absolute_source) == "true" {
        "true"
    } else {
        "false"
    };

    let entry = pulled::pulled_tsv_entry(
        tag_to_pull,
        repo_file,
        &relative_target_str,
        ".*",
        has_placeholder,
        &sha,
    );

    let current_entry = pulled::find_entry_by_file(&paths.pulled_tsv, repo_file)?;
    let (entry_tag, _entry_file, entry_relative_target, _entry_tag_filter, entry_has_placeholder, entry_sha) =
        if current_entry.is_empty() {
            (
                String::new(),
                String::new(),
                String::new(),
                String::new(),
                String::new(),
                String::new(),
            )
        } else {
            pulled::parse_entry(&current_entry).unwrap_or_default()
        };

    let proceed_with_move = if current_entry.is_empty() {
        pulled::append_entry(&paths.pulled_tsv, &entry)?;
        true
    } else if entry_tag != tag_to_pull {
        log_info(&format!(
            "the file was pulled before in version {}, going to overwrite with version {} {}",
            cyan(&entry_tag),
            cyan(tag_to_pull),
            cyan(repo_file)
        ));
        pulled::replace_entry_by_file(&paths.pulled_tsv, repo_file, &entry)?;
        true
    } else if !entry_sha.is_empty() && entry_sha != sha {
        log_warning(&format!(
            "looks like the sha512 of {} changed in tag {}",
            cyan(repo_file),
            cyan(tag_to_pull)
        ));
        simple_diff_chars(&entry_sha, &sha);
        eprintln!(
            "Won't pull the file, remove the entry from {} and `gt pull` if you want to pull it nonetheless\n",
            paths.pulled_tsv.display()
        );
        let _ = std::fs::remove_file(absolute_source);
        false
    } else if current_entry != entry {
        let current_location = normalize_path(&working_dir_absolute.join(&entry_relative_target)).ok();
        let new_location = Some(absolute_target.clone());
        match (current_location, new_location) {
            (Some(ref a), Some(ref b)) if a != b => {
                let current_rel = realpath_relative_to(a, current_dir).unwrap_or_else(|_| a.clone());
                let new_rel = realpath_relative_to(b, current_dir).unwrap_or_else(|_| b.clone());
                log_warning("the file was previously pulled to a different location");
                eprintln!("current location: {}", current_rel.display());
                eprintln!("    new location: {}", new_rel.display());
                eprintln!(
                    "Won't pull the file again, you have several alternatives:\n- remove the entry from {} and pull it again\n- move the file manually and adjust the relativeTarget of the entry (and pull again)\n",
                    paths.pulled_tsv.display()
                );
            }
            _ => {
                log_warning(
                    "the file was pulled previously but with a different tag-filter or manual change was carried out (see difference between new and old entry):",
                );
                simple_diff_chars(&current_entry, &entry);
                eprintln!(
                    "Won't pull the file again, remove the entry from {} and `gt pull` if you want to pull it nonetheless\n",
                    paths.pulled_tsv.display()
                );
            }
        }
        let _ = std::fs::remove_file(absolute_source);
        false
    } else if absolute_target.is_file() {
        log_info(&format!(
            "the file was pulled before to the same location, going to overwrite {}",
            cyan(&absolute_target.display().to_string())
        ));
        true
    } else {
        true
    };

    if !proceed_with_move {
        return Ok(());
    }

    // before hook
    if let Some(hook) = hook_before {
        let cmd = format!(
            "{} \"{}\" \"{}\" \"{}\"",
            hook,
            tag_to_pull,
            absolute_source.display(),
            absolute_target.display()
        );
        let status = std::process::Command::new("bash").arg("-c").arg(&cmd).status();
        if !matches!(status, Ok(s) if s.success()) {
            die!(
                "pull hook before failed for {}, will not move the file to its target {}",
                cyan(repo_file),
                absolute_target.display()
            );
        }
    }

    // Placeholder replacement
    if entry_has_placeholder == "true" {
        replace_gt_placeholders(
            remote,
            &paths.repo,
            repo_file,
            &absolute_target,
            absolute_source,
            &entry_tag,
            tag_to_pull,
        )?;
    }

    // Move the file
    if std::fs::rename(absolute_source, &absolute_target).is_err() {
        die!(
            "was not able to move the file {} to {}",
            cyan(&absolute_source.display().to_string()),
            absolute_target.display()
        );
    }

    // after hook
    if let Some(hook) = hook_after {
        let cmd = format!(
            "{} \"{}\" \"{}\" \"{}\"",
            hook,
            tag_to_pull,
            absolute_source.display(),
            absolute_target.display()
        );
        let status = std::process::Command::new("bash").arg("-c").arg(&cmd).status();
        if !matches!(status, Ok(s) if s.success()) {
            die!(
                "pull hook after failed for {} but the file was already moved, please do a manual cleanup",
                cyan(repo_file)
            );
        }
    }

    *number_of_pulled_files += 1;
    Ok(())
}

fn compute_target_file(
    repo_file: &str,
    chop_path: bool,
    source_is_dir: bool,
    original_path: &str,
    target_file_name: &str,
) -> String {
    let mut target = if chop_path {
        if source_is_dir {
            // Remove the leading source-path component(s)
            let offset = if original_path.ends_with('/') {
                // offset 1: skip the trailing slash
                original_path.len() + 1
            } else {
                // offset 2: skip the last directory name + slash
                original_path.len() + 2
            };
            if offset <= repo_file.len() {
                repo_file[offset - 1..].to_string()
            } else {
                repo_file.to_string()
            }
        } else {
            // File source: reduce to basename
            Path::new(repo_file)
                .file_name()
                .and_then(|n| n.to_str())
                .unwrap_or(repo_file)
                .to_string()
        }
    } else {
        repo_file.to_string()
    };

    if !target_file_name.is_empty() {
        let dir = Path::new(&target).parent().unwrap_or(Path::new("."));
        let dir_str = dir.to_str().unwrap_or(".");
        if dir_str == "." || dir_str.is_empty() {
            target = target_file_name.to_string();
        } else {
            target = format!("{dir_str}/{target_file_name}");
        }
    }
    target
}

fn replace_gt_placeholders(
    _remote: &str,
    repo: &Path,
    repo_path: &str,
    _current_file: &Path,
    updated_file: &Path,
    entry_tag: &str,
    tag_to_pull: &str,
) -> GtResult {
    if !repo.join(repo_path).is_file() {
        die!("the given repo path {} does not exist", repo.join(repo_path).display());
    }
    if !updated_file.is_file() {
        die!("the given updated file {} does not exist", updated_file.display());
    }

    // Fetch old version if tag changed
    let original_content = if entry_tag != tag_to_pull {
        git::show_tag_file(repo, entry_tag, repo_path)?
    } else {
        String::new()
    };

    let current_content = match std::fs::read_to_string(updated_file) {
        Ok(c) => c,
        Err(e) => die!("could not read current file {}: {e}", updated_file.display()),
    };

    let old_placeholders = extract_placeholders(&original_content);
    let current_placeholders = extract_placeholders(&current_content);

    let updated = match std::fs::read_to_string(updated_file) {
        Ok(c) => c,
        Err(e) => die!("could not read updated file {}: {e}", updated_file.display()),
    };

    let tmp_path = updated_file.with_extension("gt_tmp_file");
    let mut tmp = std::fs::OpenOptions::new()
        .create(true)
        .write(true)
        .truncate(true)
        .open(&tmp_path)
        .map_err(|e| {
            log_error(&format!("could not create temp file {}: {e}", tmp_path.display()));
            Exit(1)
        })?;

    let mut current_remaining: std::collections::HashMap<String, String> = current_placeholders.clone();

    let updated_lines: Vec<&str> = updated.lines().collect();
    let mut idx = 0;
    while idx < updated_lines.len() {
        let line = updated_lines[idx];
        if let Some(key) = placeholder_key(line)
            && current_placeholders.contains_key(&key)
        {
            let current_block = &current_placeholders[&key];
            let original_block = old_placeholders.get(&key);
            let preserve = original_block.map(|o| current_block != o).unwrap_or(true);
            if preserve {
                // Write the CURRENT (consumer-edited) block and skip the incoming region
                let trimmed = current_block.trim_end();
                for bline in trimmed.lines() {
                    writeln!(tmp, "{bline}").map_err(|_| Exit(1))?;
                }
                idx += 1;
                // Skip incoming region until we find the matching end marker
                while idx < updated_lines.len() {
                    if updated_lines[idx].contains(&format!("gt-placeholder-{key}-end")) {
                        break;
                    }
                    idx += 1;
                }
                current_remaining.remove(&key);
                idx += 1;
                continue;
            }
        }
        writeln!(tmp, "{line}").map_err(|_| Exit(1))?;
        idx += 1;
    }

    drop(tmp);
    if std::fs::rename(&tmp_path, updated_file).is_err() {
        die!("could not move merged temp file over {}", updated_file.display());
    }

    if !current_remaining.is_empty() {
        log_warning(&format!(
            "looks like the following placeholders no longer exists in the file {}",
            updated_file.display()
        ));
        for key in current_remaining.keys() {
            eprintln!("gt-placeholder-{key}");
        }
    }

    Ok(())
}

fn placeholder_key(line: &str) -> Option<String> {
    let prefix = "gt-placeholder-";
    let suffix = "-start";
    if line.contains(prefix) && line.contains(suffix) {
        // Extract the key between prefix and suffix
        if let Some(start) = line.find(prefix) {
            let after = &line[start + prefix.len()..];
            if let Some(end) = after.find(suffix) {
                return Some(after[..end].to_string());
            }
        }
    }
    None
}

fn extract_placeholders(content: &str) -> std::collections::HashMap<String, String> {
    let mut result = std::collections::HashMap::new();
    let lines: Vec<&str> = content.lines().collect();
    let mut i = 0;
    while i < lines.len() {
        if let Some(key) = placeholder_key(lines[i]) {
            let mut block = String::new();
            block.push_str(lines[i]);
            block.push('\n');
            i += 1;
            while i < lines.len() {
                block.push_str(lines[i]);
                block.push('\n');
                if lines[i].contains(&format!("gt-placeholder-{key}-end")) {
                    break;
                }
                i += 1;
            }
            result.insert(key, block);
        }
        i += 1;
    }
    result
}

fn check_date_to_days_ago(date_str: &str) -> Result<i64, ()> {
    let output = std::process::Command::new("date")
        .args(["-d", date_str, "+%s"])
        .output();
    let date_ts = match output {
        Ok(o) if o.status.success() => {
            let s = String::from_utf8_lossy(&o.stdout);
            s.trim().parse::<i64>().map_err(|_| ())?
        }
        _ => return Err(()),
    };

    let now_out = std::process::Command::new("date").args(["+%s"]).output();
    let now_ts = match now_out {
        Ok(o) if o.status.success() => {
            let s = String::from_utf8_lossy(&o.stdout);
            s.trim().parse::<i64>().map_err(|_| ())?
        }
        _ => return Err(()),
    };

    Ok((now_ts - date_ts) / 86400)
}

fn pull_examples() -> String {
    "# pull the file src/utility/update-bash-docu.sh from remote tegonal-scripts\n\
     # in version v0.1.0 (i.e. tag v0.1.0 is used)\n\
     # into the default directory of this remote\n\
     gt pull -r tegonal-scripts -t v0.1.0 -p src/utility/update-bash-docu.sh\n\
     \n\
     # pull the directory src/utility/ from remote tegonal-scripts\n\
     # in version v0.1.0 (i.e. tag v0.1.0 is used)\n\
     gt pull -r tegonal-scripts -t v0.1.0 -p src/utility/"
        .to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn placeholder_detection() {
        assert_eq!(placeholder_key("// gt-placeholder-foo-start"), Some("foo".to_string()));
        assert_eq!(placeholder_key("normal line"), None);
        assert_eq!(
            placeholder_key("gt-placeholder-bar-start more"),
            Some("bar".to_string())
        );
    }

    #[test]
    fn extract_placeholders_basic() {
        let text = "before\ngt-placeholder-xyz-start\ncontent\ngt-placeholder-xyz-end\nafter";
        let map = extract_placeholders(text);
        assert_eq!(map.len(), 1);
        assert!(map.contains_key("xyz"));
    }

    #[test]
    fn compute_target_no_chop() {
        assert_eq!(
            compute_target_file("src/a.sh", false, false, "src/a.sh", ""),
            "src/a.sh"
        );
    }

    #[test]
    fn compute_target_chop_file() {
        assert_eq!(compute_target_file("src/a.sh", true, false, "src/a.sh", ""), "a.sh");
    }

    #[test]
    fn compute_target_rename() {
        assert_eq!(
            compute_target_file("src/a.sh", false, false, "src/a.sh", "b.sh"),
            "src/b.sh"
        );
    }
}
