//! Wrappers around the `gpg` command line tool, mirroring `utility/gpg-utils.sh`
//! and the gt-specific `importRemotesPulledSigningKey` / `validateSigningKeyAndImport`
//! logic from `src/utils.sh`.
//!
//! As with git, we shell out to `gpg` so the trust/verification behaviour matches
//! the original Bash tool exactly.

use std::path::Path;
use std::process::Command;

use crate::args::cyan;
use crate::ask::ask_yes_or_no;
use crate::constants::{AUTO_TRUST_PARAM_PATTERN_LONG, SIGNING_KEY_ASC};
use crate::die;
use crate::error::{Exit, GtResult};
use crate::log::{log_error, log_info, log_success, log_warning};

/// `initialiseGpgDir`: create the gpg homedir and chmod it to 700 (best effort).
pub fn initialise_gpg_dir(gpg_dir: &Path) -> GtResult {
    if std::fs::create_dir_all(gpg_dir).is_err() {
        die!("could not create the gpg directory at {}", gpg_dir.display());
    }
    // it's OK if we cannot set the rights, gpg will warn the user.
    use std::os::unix::fs::PermissionsExt;
    let _ = std::fs::set_permissions(gpg_dir, std::fs::Permissions::from_mode(0o700));
    Ok(())
}

/// `gpg --homedir <gpgDir> --list-sig`. Fatal if it fails (broken setup).
pub fn list_sig(gpg_dir: &Path) -> GtResult {
    let status = Command::new("gpg")
        .arg("--homedir")
        .arg(gpg_dir)
        .arg("--list-sig")
        .status();
    match status {
        Ok(s) if s.success() => Ok(()),
        _ => die!("was not able to list the gpg keys, looks like a broken setup, aborting"),
    }
}

/// `exitBecauseSigningKeyNotImported`: report and exit 1 after cleaning gpgDir.
pub fn exit_because_signing_key_not_imported(
    remote: &str,
    public_keys_dir: &Path,
    gpg_dir: &Path,
    unsecure_param_long: &str,
) -> Exit {
    log_error(&format!(
        "{SIGNING_KEY_ASC} not imported, you won't be able to pull files from the remote {} without using {unsecure_param_long} true\n",
        cyan(remote)
    ));
    eprintln!(
        "Alternatively, you can:\n- place the {SIGNING_KEY_ASC} manually in {} or\n- setup a gpg store yourself at {}",
        public_keys_dir.display(),
        gpg_dir.display()
    );
    let _ = crate::util::delete_dir_chmod_777(gpg_dir);
    Exit(1)
}

/// `importRemotesPulledSigningKey`: validate & import the remote's signing key.
///
/// Returns `Ok(true)` if a key was imported, `Ok(false)` otherwise.
pub fn import_remotes_pulled_signing_key(
    remote: &str,
    repo_working_dir: &Path,
    gpg_dir: &Path,
    public_keys_dir: &Path,
    last_signing_key_check_file: &Path,
    repo_gt_dir: &Path,
) -> Result<bool, Exit> {
    let imported = validate_signing_key_and_import(remote, repo_working_dir, gpg_dir, public_keys_dir, false)?;

    if imported {
        // record date of last signing-key check (YYYY-mm-dd)
        if let Some(date) = today_ymd() {
            let _ = std::fs::write(last_signing_key_check_file, format!("{date}\n"));
        }
    }

    // delete the temporary .gt directory of the repo checkout
    if repo_gt_dir.exists() && crate::util::delete_dir_chmod_777(repo_gt_dir).is_err() {
        log_warning(&format!(
            "was not able to delete {}, please delete it manually",
            repo_gt_dir.display()
        ));
    }

    Ok(imported)
}

/// `validateSigningKeyAndImport`: the core trust decision + import flow.
///
/// Returns `Ok(true)` if the key was imported into `gpg_dir`, `Ok(false)` if the
/// user declined / verification could not establish trust.
fn validate_signing_key_and_import(
    remote: &str,
    source_dir: &Path,
    gpg_dir: &Path,
    public_keys_dir: &Path,
    auto_trust: bool,
) -> Result<bool, Exit> {
    let public_key = source_dir.join(SIGNING_KEY_ASC);
    let sig_file = source_dir.join(format!("{SIGNING_KEY_ASC}.sig"));

    log_info(&format!("Verifying if we trust {}\n", public_key.display()));

    // confirm = invert(autoTrust)
    let mut confirm = !auto_trust;
    let mut verified = false;
    let mut import_it = false;

    if !sig_file.is_file() {
        log_warning(&format!(
            "There is no {} next to {}, cannot verify it",
            sig_file.display(),
            public_key.display()
        ));
    } else if gpg_verify(&sig_file, &public_key) {
        verified = true;
        confirm = false;
        println!();

        // signature valid, but the key could be expired or revoked by now
        let key_data = match get_signing_gpg_key_data(&sig_file, None) {
            Some(d) => d,
            None => die!("could not get the key data of {}", sig_file.display()),
        };
        let key_id = extract_field(&key_data, 5);

        if is_key_data_expired(&key_data) {
            import_it = handle_expired_key(&public_key, &key_data, &key_id, auto_trust)?;
        } else if is_key_data_revoked(&key_data) {
            import_it = handle_revoked_key(&sig_file, &key_id)?;
        } else {
            log_info(&format!(
                "trust confirmed for {} -- signature verified",
                public_key.display()
            ));
            import_it = true;
        }
    } else {
        println!();
        log_warning(&format!(
            "gpg verification failed for signing key {} -- if you trust this repo, then import the public key which signed {SIGNING_KEY_ASC} into your personal gpg store",
            cyan(&public_key.display().to_string())
        ));
    }

    if !verified {
        if auto_trust {
            log_info(&format!(
                "since you specified {AUTO_TRUST_PARAM_PATTERN_LONG} true, we trust it nonetheless. This can be a security risk"
            ));
            import_it = true;
        } else {
            log_info(&format!(
                "You can still trust this repository via manual consent.\nIf you do, then the {SIGNING_KEY_ASC} of this remote will be stored in the remote's gpg store (not in your personal store) located at:\n{}",
                gpg_dir.display()
            ));
            if ask_yes_or_no(&format!(
                "Do you want to proceed and take a look at the {SIGNING_KEY_ASC} of remote {remote} to be able to decide if you trust it or not?"
            )) {
                import_it = true;
            } else {
                println!("Decision: do not continue! Skipping this public key accordingly");
            }
        }
    }

    let confirmation_question = if confirm {
        format!(
            "The above key(s) will be used to verify the files you will pull from remote {remote}, do you trust them?"
        )
    } else {
        String::new()
    };

    if import_it {
        println!();
        if import_gpg_key(gpg_dir, &public_key, &confirmation_question)? {
            // move public key + signature into the public keys dir
            move_into(&public_key, public_keys_dir)?;
            move_into(&sig_file, public_keys_dir)?;
            return Ok(true);
        }
    }

    log_info(&format!(
        "deleting gpg key file {} for security reasons",
        public_key.display()
    ));
    if std::fs::remove_file(&public_key).is_err() {
        die!(
            "was not able to delete the gpg key file {}, aborting",
            cyan(&public_key.display().to_string())
        );
    }
    Ok(false)
}

fn move_into(file: &Path, dir: &Path) -> GtResult {
    let Some(name) = file.file_name() else {
        die!(
            "unable to move {} into public keys directory {}",
            file.display(),
            dir.display()
        );
    };
    if std::fs::rename(file, dir.join(name)).is_err() {
        die!(
            "unable to move {} into public keys directory {}",
            cyan(&file.display().to_string()),
            dir.display()
        );
    }
    Ok(())
}

/// `importGpgKey`: optionally ask for confirmation, then import & trust the key.
/// Returns `Ok(true)` if imported.
fn import_gpg_key(gpg_dir: &Path, file: &Path, confirmation_question: &str) -> Result<bool, Exit> {
    let output_key = match gpg_show_only_import(gpg_dir, file) {
        Some(o) => o,
        None => die!(
            "not able to show the theoretical import of {}, aborting",
            file.display()
        ),
    };

    let mut is_trusting = true;
    if !confirmation_question.is_empty() {
        println!("===========================================================================");
        println!("{output_key}");
        is_trusting = ask_yes_or_no(confirmation_question);
        println!();
        println!("Decision: {}", if is_trusting { "y" } else { "n" });
    }

    if !is_trusting {
        return Ok(false);
    }

    println!("importing key {}", file.display());
    let import = Command::new("gpg")
        .arg("--homedir")
        .arg(gpg_dir)
        .args(["--batch", "--no-tty", "--import"])
        .arg(file)
        .status();
    match import {
        Ok(s) if s.success() => {}
        _ => die!("failed to import {}", file.display()),
    }

    for key_id in extract_pub_key_ids(&output_key) {
        println!("establishing trust for key {key_id}");
        trust_gpg_key(gpg_dir, &key_id)?;
    }
    Ok(true)
}

/// `trustGpgKey`: set ultimate ownertrust for `key_id` in `gpg_dir`.
fn trust_gpg_key(gpg_dir: &Path, key_id: &str) -> GtResult {
    let fpr_out = Command::new("gpg")
        .arg("--homedir")
        .arg(gpg_dir)
        .args(["--with-colons", "--fingerprint", key_id])
        .output();
    let fingerprint = match fpr_out {
        Ok(o) if o.status.success() => String::from_utf8_lossy(&o.stdout)
            .lines()
            .find_map(|l| {
                l.strip_prefix("fpr:")
                    .map(|_| l.split(':').nth(9).unwrap_or("").to_string())
            })
            .unwrap_or_default(),
        _ => die!(
            "was not able to determine fingerprint for keyId {key_id} in gpg dir {}",
            gpg_dir.display()
        ),
    };

    use std::io::Write;
    use std::process::Stdio;
    let mut child = match Command::new("gpg")
        .arg("--homedir")
        .arg(gpg_dir)
        .arg("--import-ownertrust")
        .stdin(Stdio::piped())
        .spawn()
    {
        Ok(c) => c,
        Err(_) => die!("was not able to import ownertrust for keyId {key_id}"),
    };
    if let Some(stdin) = child.stdin.as_mut() {
        let _ = writeln!(stdin, "{fingerprint}:5:");
    }
    let _ = child.wait();
    Ok(())
}

// ----- low-level gpg helpers -------------------------------------------------

fn gpg_verify(sig_file: &Path, public_key: &Path) -> bool {
    Command::new("gpg")
        .arg("--verify")
        .arg(sig_file)
        .arg(public_key)
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}

fn gpg_show_only_import(gpg_dir: &Path, file: &Path) -> Option<String> {
    let out = Command::new("gpg")
        .arg("--homedir")
        .arg(gpg_dir)
        .args([
            "--no-tty",
            "--keyid-format",
            "LONG",
            "--list-options",
            "show-sig-expire,show-unusable-subkeys,show-unusable-uids,show-usage,show-user-notations",
            "--import-options",
            "show-only",
            "--import",
        ])
        .arg(file)
        .output()
        .ok()?;
    if out.status.success() {
        Some(String::from_utf8_lossy(&out.stdout).into_owned())
    } else {
        None
    }
}

/// `getSigningGpgKeyData`: the `pub`/`sub` colon-record of the key that signed
/// `sig_file`, searched in `gpg_dir` (or the default store when `None`).
fn get_signing_gpg_key_data(sig_file: &Path, gpg_dir: Option<&Path>) -> Option<String> {
    let packets = Command::new("gpg").arg("--list-packets").arg(sig_file).output().ok()?;
    if !packets.status.success() {
        return None;
    }
    let packets = String::from_utf8_lossy(&packets.stdout);
    // mirrors `grep -oE "keyid .*" | cut -c7-`: the keyid appears mid-line on the
    // `:signature packet:` line, so match it anywhere and take the rest.
    let key_id = packets.lines().find_map(|l| {
        let idx = l.find("keyid ")?;
        Some(l[idx + "keyid ".len()..].trim().to_string())
    })?;

    let mut cmd = Command::new("gpg");
    if let Some(dir) = gpg_dir {
        cmd.arg("--homedir").arg(dir);
    }
    let out = cmd
        .args([
            "--list-keys",
            "--list-options",
            "show-sig-expire,show-unusable-subkeys,show-unusable-uids",
            "--with-colons",
            &key_id,
        ])
        .output()
        .ok()?;
    if !out.status.success() {
        return None;
    }
    let listing = String::from_utf8_lossy(&out.stdout);
    listing
        .lines()
        .find(|l| (l.starts_with("pub") || l.starts_with("sub")) && l.contains(&key_id))
        .map(|l| l.to_string())
}

fn extract_field(colon_record: &str, one_based_index: usize) -> String {
    colon_record
        .split(':')
        .nth(one_based_index - 1)
        .unwrap_or("")
        .to_string()
}

fn is_key_data_expired(key_data: &str) -> bool {
    key_data.starts_with("sub:e:") || key_data.starts_with("pub:e:")
}

fn is_key_data_revoked(key_data: &str) -> bool {
    key_data.starts_with("sub:r:") || key_data.starts_with("pub:r:")
}

/// Extract pub key ids from the `--import show-only` output (mirrors the
/// `grep pub | perl ...` pipeline: takes the id after `<algo>/`).
fn extract_pub_key_ids(output_key: &str) -> Vec<String> {
    output_key
        .lines()
        .filter(|l| l.trim_start().starts_with("pub"))
        .filter_map(|l| {
            // e.g. "pub   rsa4096/0B66B0D6 ..." -> take "0B66B0D6"
            let after_slash = l.split('/').nth(1)?;
            let id: String = after_slash.chars().take_while(|c| c.is_ascii_alphanumeric()).collect();
            if id.is_empty() {
                None
            } else {
                Some(id)
            }
        })
        .collect()
}

fn handle_expired_key(public_key: &Path, key_data: &str, key_id: &str, auto_trust: bool) -> Result<bool, Exit> {
    let expiration_timestamp = extract_field(key_data, 7);
    let expiration_date = timestamp_to_date_time(&expiration_timestamp).unwrap_or_else(|| expiration_timestamp.clone());

    if auto_trust {
        log_info(&format!(
            "The key {key_id} used to sign {} expired at {expiration_date}, ignoring it since you specified {AUTO_TRUST_PARAM_PATTERN_LONG} true",
            public_key.display()
        ));
        return Ok(true);
    }

    log_info(&format!(
        "The key {key_id} used to sign {} expired at {expiration_date}",
        public_key.display()
    ));
    let import_it = if ask_yes_or_no(&format!(
        "The signature as such is OK and thus we assume you still trust it. Or would you like to take a closer look at the key {key_id}?"
    )) {
        list_signatures_and_highlight_key(key_id, None);
        ask_yes_or_no(&format!(
            "Do you want to trust {SIGNING_KEY_ASC} seeing now more details of the key {key_id} which signed it"
        ))
    } else {
        true
    };
    if import_it {
        log_info(&format!(
            "trust confirmed for {} -- signature verified (see further above) via expired key {key_id}",
            public_key.display()
        ));
    }
    Ok(import_it)
}

fn handle_revoked_key(sig_file: &Path, key_id: &str) -> Result<bool, Exit> {
    let sig_creation_date = match get_sig_creation_date(sig_file) {
        Some(d) => d,
        None => die!(
            "could not get the creation date of the signature {}",
            sig_file.display()
        ),
    };
    let sig_creation_ts = match date_to_timestamp(&sig_creation_date) {
        Some(t) => t,
        None => die!("was not able to convert the signature creation date {sig_creation_date} to a timestamp"),
    };

    let rev_data = match get_revocation_data(key_id, None) {
        Some(d) => d,
        None => die!("could not get the revocation data for key {key_id}"),
    };
    let rev_created_ts_str = extract_field(&rev_data, 6);
    let rev_created_ts = match rev_created_ts_str.parse::<i64>() {
        Ok(t) => t,
        Err(_) => die!(
            "was not able to extract the revocation creation timestamp from the revocation information:\n{rev_data}"
        ),
    };
    let rev_create = timestamp_to_date_time(&rev_created_ts_str).unwrap_or_else(|| rev_created_ts_str.clone());

    if sig_creation_ts < rev_created_ts {
        log_warning(&format!(
            "The key {key_id} used to sign the signing-key was revoked at {rev_create}.\nHowever, the signature was created before at {sig_creation_date}. You should take a closer look at the key and the reason why it was revoked to decide if you trust the signature."
        ));
        println!("Press enter to see the signatures of {key_id}\n");
        list_signatures_and_highlight_key(key_id, None);
        let import_it = ask_yes_or_no(&format!(
            "Do you want to trust the {SIGNING_KEY_ASC} although the key {key_id} signing it was revoked?"
        ));
        if import_it {
            log_info(&format!(
                "trust confirmed for the signing-key -- signature verified (see further above) via revoked key {key_id}"
            ));
        }
        Ok(import_it)
    } else {
        log_error(&format!(
            "The key {key_id} used to sign the {SIGNING_KEY_ASC} was revoked at {rev_create} and but the signature was created afterwards at {sig_creation_date} -- i.e. we cannot trust it"
        ));
        Ok(false)
    }
}

fn get_sig_creation_date(sig_file: &Path) -> Option<String> {
    let packets = Command::new("gpg").arg("--list-packets").arg(sig_file).output().ok()?;
    if !packets.status.success() {
        return None;
    }
    let packets = String::from_utf8_lossy(&packets.stdout);
    // grep -oE "sig created [0-9-]+" | cut -c13-
    packets.lines().find_map(|l| {
        let idx = l.find("sig created ")?;
        let rest = &l[idx + "sig created ".len()..];
        let date: String = rest.chars().take_while(|c| c.is_ascii_digit() || *c == '-').collect();
        if date.is_empty() {
            None
        } else {
            Some(date)
        }
    })
}

fn get_revocation_data(key_id: &str, gpg_dir: Option<&Path>) -> Option<String> {
    let mut cmd = Command::new("gpg");
    if let Some(dir) = gpg_dir {
        cmd.arg("--homedir").arg(dir);
    }
    let out = cmd
        .args([
            "--list-sigs",
            "--list-options",
            "show-sig-expire,show-unusable-subkeys,show-unusable-uids",
            "--with-colons",
            key_id,
        ])
        .output()
        .ok()?;
    if !out.status.success() {
        return None;
    }
    let sigs = String::from_utf8_lossy(&out.stdout);
    // find the first `rev:` colon-record following a revoked pub/sub for this key
    let mut seen_revoked_key = false;
    for line in sigs.lines() {
        if (line.starts_with("pub:r:") || line.starts_with("sub:r:")) && line.contains(key_id) {
            seen_revoked_key = true;
        }
        if seen_revoked_key && line.starts_with("rev:") {
            return Some(line.to_string());
        }
    }
    None
}

fn list_signatures_and_highlight_key(key_id: &str, gpg_dir: Option<&Path>) {
    let mut cmd = Command::new("gpg");
    if let Some(dir) = gpg_dir {
        cmd.arg("--homedir").arg(dir);
    }
    let out = cmd
        .args([
            "--list-sigs",
            "--keyid-format",
            "LONG",
            "--list-options",
            "show-sig-expire,show-unusable-subkeys,show-unusable-uids,show-usage,show-user-notations",
            key_id,
        ])
        .output();
    if let Ok(out) = out {
        if out.status.success() {
            let listing = String::from_utf8_lossy(&out.stdout);
            let highlighted = listing.replace(key_id, &format!("\x1b[0;31m{key_id}\x1b[0m"));
            print!("{highlighted}");
        }
    }
}

// ----- date helpers (delegate to the `date` CLI, matching date-utils.sh) -----

fn today_ymd() -> Option<String> {
    let out = Command::new("date").args(["+%Y-%m-%d"]).output().ok()?;
    if out.status.success() {
        Some(String::from_utf8_lossy(&out.stdout).trim().to_string())
    } else {
        None
    }
}

fn timestamp_to_date_time(timestamp: &str) -> Option<String> {
    let out = Command::new("date")
        .args([&format!("-d@{timestamp}"), "+%Y-%m-%dT%H:%M:%S"])
        .output()
        .ok()?;
    if out.status.success() {
        Some(String::from_utf8_lossy(&out.stdout).trim().to_string())
    } else {
        None
    }
}

fn date_to_timestamp(date: &str) -> Option<i64> {
    let out = Command::new("date").args([&format!("-d{date}"), "+%s"]).output().ok()?;
    if out.status.success() {
        String::from_utf8_lossy(&out.stdout).trim().parse().ok()
    } else {
        None
    }
}

/// Mirrors `logSuccess` for the successful remote setup message (re-exported so
/// the command module can call it without importing `log` separately).
pub fn log_setup_success(remote: &str, number_of_imported_keys: u32) {
    log_success(&format!(
        "remote {} was set up successfully; imported {number_of_imported_keys} GPG key(s) for verification.\nYou are ready to pull files via:\ngt pull -r {remote} -p <PATH>",
        cyan(remote)
    ));
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn extract_field_is_one_based() {
        let record = "pub:e:4096:1:ABC123:1600000000:1700000000:::::";
        assert_eq!(extract_field(record, 1), "pub");
        assert_eq!(extract_field(record, 5), "ABC123");
        assert_eq!(extract_field(record, 7), "1700000000");
        assert_eq!(extract_field(record, 99), "");
    }

    #[test]
    fn detects_expired_and_revoked_records() {
        assert!(is_key_data_expired("pub:e:4096:1:ABC:::"));
        assert!(is_key_data_expired("sub:e:4096:1:ABC:::"));
        assert!(!is_key_data_expired("pub:-:4096:1:ABC:::"));

        assert!(is_key_data_revoked("pub:r:4096:1:ABC:::"));
        assert!(is_key_data_revoked("sub:r:4096:1:ABC:::"));
        assert!(!is_key_data_revoked("pub:-:4096:1:ABC:::"));
    }

    #[test]
    fn extracts_pub_key_ids_from_show_only_output() {
        let output = "\
pub   rsa4096/0B66B0D6 2017-05-04 [SC]
      Key fingerprint = ...
uid   Tegonal <info@tegonal.com>
sub   rsa4096/DEADBEEF 2017-05-04 [E]";
        assert_eq!(extract_pub_key_ids(output), vec!["0B66B0D6".to_string()]);
    }
}
