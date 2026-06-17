//! The `gt self-update` command, translated from `src/gt-self-update.sh`.
//!
//! It updates the local `gt` installation: if installed via git it first checks
//! whether the current branch already matches the latest remote tag (and, unless
//! `--force` is given, skips re-installing in that case); otherwise it asks for
//! confirmation. In all cases that proceed, it copies the installation into a
//! temporary directory and runs `install.sh --directory <installDir>` from there.

use std::path::{Path, PathBuf};
use std::process::{Command, ExitStatus};
use std::sync::atomic::{AtomicU32, Ordering};

use crate::args::{exit_if_not_all_arguments_set, parse_arguments, Param};
use crate::constants::{FORCE_PARAM_PATTERN, FORCE_PARAM_PATTERN_LONG, GT_VERSION};
use crate::error::{Exit, GtResult};
use crate::log::log_info;
use crate::util::{copy_dir_recursive, current_dir, normalize_path};
use crate::{die, git};

/// Trait abstracting the environment interactions required by self-update.
///
/// Allows unit tests to mock git state, user prompts and file-system / process
/// operations without touching the real system.
pub(crate) trait SelfUpdateEnv {
    fn current_git_branch(&mut self, repo: &Path) -> Result<String, Exit>;
    fn latest_remote_tag(&mut self, repo: &Path, remote: &str, filter: &str) -> Result<String, Exit>;
    fn ask_yes_or_no(&mut self, question: &str) -> bool;
    fn make_tmp_dir(&mut self) -> Result<PathBuf, Exit>;
    fn copy_dir_recursive(&mut self, src: &Path, dst: &Path) -> std::io::Result<()>;
    fn run_install_sh(
        &mut self,
        install_sh: &Path,
        install_dir: &Path,
        cwd: &Path,
    ) -> std::io::Result<ExitStatus>;
}

struct RealSelfUpdateEnv;
impl SelfUpdateEnv for RealSelfUpdateEnv {
    fn current_git_branch(&mut self, repo: &Path) -> Result<String, Exit> {
        git::current_git_branch(repo)
    }

    fn latest_remote_tag(&mut self, repo: &Path, remote: &str, filter: &str) -> Result<String, Exit> {
        git::latest_remote_tag(repo, remote, filter)
    }

    fn ask_yes_or_no(&mut self, question: &str) -> bool {
        crate::ask::ask_yes_or_no(question)
    }

    fn make_tmp_dir(&mut self) -> Result<PathBuf, Exit> {
        make_tmp_dir_real()
    }

    fn copy_dir_recursive(&mut self, src: &Path, dst: &Path) -> std::io::Result<()> {
        copy_dir_recursive(src, dst)
    }

    fn run_install_sh(
        &mut self,
        install_sh: &Path,
        install_dir: &Path,
        cwd: &Path,
    ) -> std::io::Result<ExitStatus> {
        Command::new(install_sh)
            .arg("--directory")
            .arg(install_dir)
            .current_dir(cwd)
            .status()
    }
}

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
    // An environment variable is provided so integration tests can override
    // the executable directory without relying on symlinks / current_exe().
    let exe_dir: PathBuf = if let Ok(dir) = std::env::var("GT_SELF_UPDATE_EXE_DIR") {
        dir.into()
    } else {
        let exe = std::env::current_exe().map_err(|_| {
            crate::log::log_error("could not determine the location of the gt executable");
            Exit(1)
        })?;
        exe.parent().ok_or_else(|| {
            crate::log::log_error("could not determine the directory of the gt executable");
            Exit(1)
        })?.into()
    };

    self_update_with_install_dir(&exe_dir, force_install)
}

/// Thin wrapper that uses the real environment.
pub(crate) fn self_update_with_install_dir(exe_dir: &Path, force_install: bool) -> GtResult {
    let mut env = RealSelfUpdateEnv;
    self_update_with_install_dir_and_env(exe_dir, force_install, &mut env)
}

/// The core of the command, parameterised by the executable's directory and the
/// environment so it can be unit-tested with a fake installation. `exe_dir`
/// corresponds to `dir_of_gt`.
pub(crate) fn self_update_with_install_dir_and_env(
    exe_dir: &Path,
    force_install: bool,
    env: &mut dyn SelfUpdateEnv,
) -> GtResult {
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
        let current_branch = env.current_git_branch(&install_dir)?;
        let latest_tag = env.latest_remote_tag(&install_dir, "origin", ".*")?;
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
        if !env.ask_yes_or_no(&format!(
            "Do you want to run the following command to replace the current installation with the latest version:\ninstall.sh --directory \"{}\"",
            install_dir.display()
        )) {
            log_info("aborted self update");
            return Err(Exit(1));
        }
    }

    let tmp_dir = env.make_tmp_dir()?;
    let tmp_gt = tmp_dir.join("gt");
    if env.copy_dir_recursive(&install_dir, &tmp_gt).is_err() {
        die!(
            "could not copy {} to {}",
            install_dir.display(),
            tmp_gt.display()
        );
    }

    let status = env.run_install_sh(&tmp_gt.join("install.sh"), &install_dir, &tmp_gt);

    match status {
        Ok(s) if s.success() => Ok(()),
        Ok(s) => Err(Exit(s.code().unwrap_or(1))),
        Err(_) => die!("could not run install.sh in {}", tmp_gt.display()),
    }
}

/// Creates a unique temporary directory, mirroring `mktemp -d -t gt-install-XXXXXXXXXX`.
fn make_tmp_dir_real() -> Result<PathBuf, Exit> {
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
    use std::sync::atomic::{AtomicBool, Ordering as O};

    #[derive(Default)]
    struct MockEnv {
        current_git_branch: Option<Result<String, Exit>>,
        latest_remote_tag: Option<Result<String, Exit>>,
        ask_yes_or_no: bool,
        make_tmp_dir: Option<Result<PathBuf, Exit>>,
        copy_dir_recursive: Option<std::io::Result<()>>,
        run_install_sh: Option<std::io::Result<ExitStatus>>,
        run_install_sh_called: AtomicBool,
    }

    impl SelfUpdateEnv for MockEnv {
        fn current_git_branch(&mut self, _repo: &Path) -> Result<String, Exit> {
            self.current_git_branch.take().expect(
                "current_git_branch should not have been called in this test"
            )
        }

        fn latest_remote_tag(&mut self, _repo: &Path, _remote: &str, _filter: &str) -> Result<String, Exit> {
            self.latest_remote_tag.take().expect(
                "latest_remote_tag should not have been called in this test"
            )
        }

        fn ask_yes_or_no(&mut self, _question: &str) -> bool {
            self.ask_yes_or_no
        }

        fn make_tmp_dir(&mut self) -> Result<PathBuf, Exit> {
            self.make_tmp_dir.take().expect(
                "make_tmp_dir should not have been called in this test"
            )
        }

        fn copy_dir_recursive(&mut self, _src: &Path, _dst: &Path) -> std::io::Result<()> {
            self.copy_dir_recursive.take().expect(
                "copy_dir_recursive should not have been called in this test"
            )
        }

        fn run_install_sh(
            &mut self,
            _install_sh: &Path,
            _install_dir: &Path,
            _cwd: &Path,
        ) -> std::io::Result<ExitStatus> {
            self.run_install_sh_called.store(true, O::SeqCst);
            self.run_install_sh.take().expect(
                "run_install_sh should not have been called in this test"
            )
        }
    }

    fn tmp() -> PathBuf {
        static COUNTER: AtomicU32 = AtomicU32::new(0);
        let n = COUNTER.fetch_add(1, O::SeqCst);
        let d = std::env::temp_dir().join(format!("gt-su-ut-{}-{n}", std::process::id()));
        let _ = std::fs::remove_dir_all(&d);
        std::fs::create_dir_all(&d).unwrap();
        d
    }

    fn ok_status() -> ExitStatus {
        Command::new("true").status().unwrap()
    }

    fn fail_status() -> ExitStatus {
        Command::new("false").status().unwrap()
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

    #[test]
    fn git_installation_on_latest_tag_no_force_skips_update() {
        let base = tmp();
        let install_dir = base.join("install");
        let exe_dir = install_dir.join("bin");
        std::fs::create_dir_all(&exe_dir).unwrap();
        std::fs::write(install_dir.join("install.sh"), "#!/bin/sh\necho install").unwrap();
        // simulate a git installation: create .git directory
        std::fs::create_dir_all(install_dir.join(".git")).unwrap();

        let mut env = MockEnv {
            current_git_branch: Some(Ok("v1.7.0".to_string())),
            latest_remote_tag: Some(Ok("v1.7.0".to_string())),
            ..Default::default()
        };

        let res = self_update_with_install_dir_and_env(&exe_dir, false, &mut env);
        assert_eq!(res, Ok(()));
        assert!(!env.run_install_sh_called.load(O::SeqCst));
    }

    #[test]
    fn git_installation_on_latest_tag_with_force_proceeds() {
        let base = tmp();
        let install_dir = base.join("install");
        let exe_dir = install_dir.join("bin");
        std::fs::create_dir_all(&exe_dir).unwrap();
        std::fs::write(install_dir.join("install.sh"), "#!/bin/sh\necho install").unwrap();
        std::fs::create_dir_all(install_dir.join(".git")).unwrap();

        let mut env = MockEnv {
            current_git_branch: Some(Ok("v1.7.0".to_string())),
            latest_remote_tag: Some(Ok("v1.7.0".to_string())),
            make_tmp_dir: Some(Ok(base.join("tmp"))),
            copy_dir_recursive: Some(Ok(())),
            run_install_sh: Some(Ok(ok_status())),
            ..Default::default()
        };

        let res = self_update_with_install_dir_and_env(&exe_dir, true, &mut env);
        assert_eq!(res, Ok(()));
        assert!(env.run_install_sh_called.load(O::SeqCst));
    }

    #[test]
    fn git_installation_behind_tag_proceeds_to_update() {
        let base = tmp();
        let install_dir = base.join("install");
        let exe_dir = install_dir.join("bin");
        std::fs::create_dir_all(&exe_dir).unwrap();
        std::fs::write(install_dir.join("install.sh"), "#!/bin/sh\necho install").unwrap();
        std::fs::create_dir_all(install_dir.join(".git")).unwrap();

        let mut env = MockEnv {
            current_git_branch: Some(Ok("v1.6.0".to_string())),
            latest_remote_tag: Some(Ok("v1.7.0".to_string())),
            make_tmp_dir: Some(Ok(base.join("tmp"))),
            copy_dir_recursive: Some(Ok(())),
            run_install_sh: Some(Ok(ok_status())),
            ..Default::default()
        };

        let res = self_update_with_install_dir_and_env(&exe_dir, false, &mut env);
        assert_eq!(res, Ok(()));
        assert!(env.run_install_sh_called.load(O::SeqCst));
    }

    #[test]
    fn non_git_user_confirms_proceeds() {
        let base = tmp();
        let install_dir = base.join("install");
        let exe_dir = install_dir.join("bin");
        std::fs::create_dir_all(&exe_dir).unwrap();
        std::fs::write(install_dir.join("install.sh"), "#!/bin/sh\necho install").unwrap();
        // no .git directory

        let mut env = MockEnv {
            ask_yes_or_no: true,
            make_tmp_dir: Some(Ok(base.join("tmp"))),
            copy_dir_recursive: Some(Ok(())),
            run_install_sh: Some(Ok(ok_status())),
            ..Default::default()
        };

        let res = self_update_with_install_dir_and_env(&exe_dir, false, &mut env);
        assert_eq!(res, Ok(()));
        assert!(env.run_install_sh_called.load(O::SeqCst));
    }

    #[test]
    fn non_git_user_denies_aborts() {
        let base = tmp();
        let install_dir = base.join("install");
        let exe_dir = install_dir.join("bin");
        std::fs::create_dir_all(&exe_dir).unwrap();
        std::fs::write(install_dir.join("install.sh"), "#!/bin/sh\necho install").unwrap();
        // no .git directory

        let mut env = MockEnv {
            ask_yes_or_no: false,
            ..Default::default()
        };

        let res = self_update_with_install_dir_and_env(&exe_dir, false, &mut env);
        assert_eq!(res, Err(Exit(1)));
        assert!(!env.run_install_sh_called.load(O::SeqCst));
    }

    #[test]
    fn install_sh_failure_returns_exit_code() {
        let base = tmp();
        let install_dir = base.join("install");
        let exe_dir = install_dir.join("bin");
        std::fs::create_dir_all(&exe_dir).unwrap();
        std::fs::write(install_dir.join("install.sh"), "#!/bin/sh\necho install").unwrap();
        std::fs::create_dir_all(install_dir.join(".git")).unwrap();

        let mut env = MockEnv {
            current_git_branch: Some(Ok("v1.6.0".to_string())),
            latest_remote_tag: Some(Ok("v1.7.0".to_string())),
            make_tmp_dir: Some(Ok(base.join("tmp"))),
            copy_dir_recursive: Some(Ok(())),
            run_install_sh: Some(Ok(fail_status())),
            ..Default::default()
        };

        let res = self_update_with_install_dir_and_env(&exe_dir, false, &mut env);
        assert_eq!(res, Err(Exit(1)));
        assert!(env.run_install_sh_called.load(O::SeqCst));
    }

    #[test]
    fn install_sh_io_error_returns_exit_1() {
        let base = tmp();
        let install_dir = base.join("install");
        let exe_dir = install_dir.join("bin");
        std::fs::create_dir_all(&exe_dir).unwrap();
        std::fs::write(install_dir.join("install.sh"), "#!/bin/sh\necho install").unwrap();
        std::fs::create_dir_all(install_dir.join(".git")).unwrap();

        let mut env = MockEnv {
            current_git_branch: Some(Ok("v1.6.0".to_string())),
            latest_remote_tag: Some(Ok("v1.7.0".to_string())),
            make_tmp_dir: Some(Ok(base.join("tmp"))),
            copy_dir_recursive: Some(Ok(())),
            run_install_sh: Some(Err(std::io::Error::new(
                std::io::ErrorKind::Other,
                "boom",
            ))),
            ..Default::default()
        };

        let res = self_update_with_install_dir_and_env(&exe_dir, false, &mut env);
        assert_eq!(res, Err(Exit(1)));
        assert!(env.run_install_sh_called.load(O::SeqCst));
    }
}
