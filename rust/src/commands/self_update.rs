//! The `gt self-update` command, translated from `src/gt-self-update.sh`.
//!
//! It updates the local `gt` installation: if installed via git it first checks
//! whether the current branch already matches the latest remote tag (and, unless
//! `--force` is given, skips re-installing in that case); otherwise it asks for
//! confirmation. In all cases that proceed, it copies the installation into a
//! temporary directory and runs `install.sh --directory <installDir>` from there.

use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::atomic::{AtomicU32, Ordering};

use crate::args::{exit_if_not_all_arguments_set, parse_arguments, Param};
use crate::ask::ask_yes_or_no;
use crate::constants::{FORCE_PARAM_PATTERN, FORCE_PARAM_PATTERN_LONG, GT_VERSION};
use crate::error::{Exit, GtResult};
use crate::log::log_info;
use crate::util::{copy_dir_recursive, current_dir, normalize_path};
use crate::{die, git};

/// Entry point: `gt self-update [--force <true/false>]`.
pub fn run(args: &[String]) -> GtResult {
    // currentDir is determined for symmetry with the Bash script (which uses it
    // to cd back); we keep the check so failure to read the cwd fails the same way.
    let _current = current_dir()?;

    let params = vec![Param::new(
        "forceInstall",
        FORCE_PARAM_PATTERN,
        "if set to true, then install.sh will be called even if gt is already on latest tag -- default false",
    )];
    let examples = examples();

    let mut values = parse_arguments(&params, &examples, GT_VERSION, args)?;
    values
        .entry("forceInstall".to_string())
        .or_insert_with(|| "false".to_string());
    exit_if_not_all_arguments_set(&params, &values, &examples, GT_VERSION)?;

    let force_install = values.get("forceInstall").map(|s| s == "true").unwrap_or(false);

    // The Bash script derives installDir from the script's own location
    // (dir_of_gt/..). The Rust binary uses its own executable location instead.
    let exe = std::env::current_exe().map_err(|_| {
        crate::log::log_error("could not determine the location of the gt executable");
        Exit(1)
    })?;
    let exe_dir = exe.parent().ok_or_else(|| {
        crate::log::log_error("could not determine the directory of the gt executable");
        Exit(1)
    })?;

    self_update_with_install_dir(exe_dir, force_install)
}

/// The core of the command, parameterised by the executable's directory so it can
/// be unit-tested with a fake installation. `exe_dir` corresponds to `dir_of_gt`.
pub(crate) fn self_update_with_install_dir(exe_dir: &Path, force_install: bool) -> GtResult {
    let install_dir = normalize_path(&exe_dir.join("..")).map_err(|_| {
        crate::log::log_error(&format!(
            "could not deduce the installation directory from {}",
            exe_dir.display()
        ));
        Exit(1)
    })?;

    let install_sh = install_dir.join("install.sh");
    if !install_sh.is_file() {
        die!(
            "looks like the previous installation is corrupt, there is no install.sh in {}\nPlease re-install gt according to:\nhttps://github.com/tegonal/gt#installation",
            install_dir.display()
        );
    }

    if install_dir.join(".git").is_dir() {
        // looks like it was an installation via git; first check for a new version
        let current_branch = git::current_git_branch(&install_dir)?;
        let latest_tag = git::latest_remote_tag(&install_dir, "origin", ".*")?;
        if current_branch == latest_tag {
            // logInfoWithoutNewline: print without a trailing newline, then append.
            print!("\x1b[0;34mINFO\x1b[0m: latest version of gt ({latest_tag}) is already installed");
            if !force_install {
                println!(
                    ", nothing to do in addition (specify {FORCE_PARAM_PATTERN_LONG} true if you want to re-install)"
                );
                return Ok(());
            } else {
                println!(", but '{FORCE_PARAM_PATTERN_LONG} true' was specified, going to re-install it");
            }
        }
    } else {
        log_info(&format!(
            "looks like you did not install gt via install.sh ({} does not exist)",
            install_dir.join(".git").display()
        ));
        if !ask_yes_or_no(&format!(
            "Do you want to run the following command to replace the current installation with the latest version:\ninstall.sh --directory \"{}\"",
            install_dir.display()
        )) {
            log_info("aborted self update");
            return Err(Exit(1));
        }
    }

    let tmp_dir = make_tmp_dir()?;
    let tmp_gt = tmp_dir.join("gt");
    if copy_dir_recursive(&install_dir, &tmp_gt).is_err() {
        die!(
            "could not copy {} to {}",
            install_dir.display(),
            tmp_gt.display()
        );
    }

    let status = Command::new(tmp_gt.join("install.sh"))
        .arg("--directory")
        .arg(&install_dir)
        .current_dir(&tmp_gt)
        .status();

    match status {
        Ok(s) if s.success() => Ok(()),
        Ok(s) => Err(Exit(s.code().unwrap_or(1))),
        Err(_) => die!("could not run install.sh in {}", tmp_gt.display()),
    }
}

/// Creates a unique temporary directory, mirroring `mktemp -d -t gt-install-XXXXXXXXXX`.
fn make_tmp_dir() -> Result<PathBuf, Exit> {
    static COUNTER: AtomicU32 = AtomicU32::new(0);
    let n = COUNTER.fetch_add(1, Ordering::SeqCst);
    let dir = std::env::temp_dir().join(format!("gt-install-{}-{n}", std::process::id()));
    std::fs::create_dir_all(&dir).map_err(|_| {
        crate::log::log_error(&format!("could not create temporary directory {}", dir.display()));
        Exit(1)
    })?;
    Ok(dir)
}

fn examples() -> String {
    "# updates gt to the latest tag\n\
gt self-update\n\
\n\
# updates gt to the latest tag and downloads the sources even if already on the latest\n\
gt self-update --force"
        .to_string()
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicU32, Ordering as O};

    static COUNTER: AtomicU32 = AtomicU32::new(0);

    fn tmp() -> PathBuf {
        let n = COUNTER.fetch_add(1, O::SeqCst);
        let d = std::env::temp_dir().join(format!("gt-su-ut-{}-{n}", std::process::id()));
        let _ = std::fs::remove_dir_all(&d);
        std::fs::create_dir_all(&d).unwrap();
        d
    }

    #[test]
    fn corrupt_installation_without_install_sh_exits_1() {
        // install_dir = exe_dir/.. ; create an exe_dir whose parent has no install.sh
        let base = tmp();
        let exe_dir = base.join("bin");
        std::fs::create_dir_all(&exe_dir).unwrap();
        let res = self_update_with_install_dir(&exe_dir, false);
        assert_eq!(res, Err(Exit(1)));
    }
}
