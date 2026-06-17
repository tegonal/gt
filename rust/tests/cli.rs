//! Integration tests driving the compiled `gt` binary, mirroring the behaviour
//! of the original `gt-remote.sh` (exit codes, structure created, messages).
//!
//! The `add` tests use a local `file://` git repository so they need `git` but
//! no network access and no GPG (they exercise the `--unsecure true` path where
//! the remote provides no `.gt` directory).

use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::{Command, Output, Stdio};
use std::sync::atomic::{AtomicU32, Ordering};

#[cfg(unix)]
use std::os::unix::fs::PermissionsExt;

static COUNTER: AtomicU32 = AtomicU32::new(0);

fn unique_dir(label: &str) -> PathBuf {
    let n = COUNTER.fetch_add(1, Ordering::SeqCst);
    let dir = std::env::temp_dir().join(format!("gt-it-{}-{label}-{n}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    std::fs::create_dir_all(&dir).unwrap();
    dir
}

/// Runs the `gt` binary in `cwd` with the given args, feeding `stdin` to it.
fn run(cwd: &Path, args: &[&str], stdin: &str) -> Output {
    run_env(cwd, args, stdin, &[])
}

/// Like [`run`] but with additional environment variables (e.g. `GNUPGHOME`).
fn run_env(cwd: &Path, args: &[&str], stdin: &str, envs: &[(&str, &str)]) -> Output {
    let mut cmd = Command::new(env!("CARGO_BIN_EXE_gt"));
    cmd.args(args)
        .current_dir(cwd)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped());
    for (k, v) in envs {
        cmd.env(k, v);
    }
    let mut child = cmd.spawn().expect("failed to spawn gt");
    child.stdin.take().unwrap().write_all(stdin.as_bytes()).unwrap();
    child.wait_with_output().expect("failed to wait for gt")
}

fn code(output: &Output) -> i32 {
    output.status.code().expect("process terminated by signal")
}

fn stdout(output: &Output) -> String {
    String::from_utf8_lossy(&output.stdout).into_owned()
}

fn stderr(output: &Output) -> String {
    String::from_utf8_lossy(&output.stderr).into_owned()
}

// ---------------------------------------------------------------------------
// helpers for self-update integration tests (copies the binary so
// current_exe() resolves to a controlled install directory)
// ---------------------------------------------------------------------------

fn run_binary(binary: &Path, cwd: &Path, args: &[&str], stdin: &str) -> Output {
    run_binary_env(binary, cwd, args, stdin, &[])
}

fn run_binary_env(binary: &Path, cwd: &Path, args: &[&str], stdin: &str, envs: &[(&str, &str)]) -> Output {
    let mut cmd = Command::new(binary);
    cmd.args(args)
        .current_dir(cwd)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped());
    for (k, v) in envs {
        cmd.env(k, v);
    }
    let mut child = cmd.spawn().expect("failed to spawn gt");
    child.stdin.take().unwrap().write_all(stdin.as_bytes()).unwrap();
    child.wait_with_output().expect("failed to wait for gt")
}

fn create_install_dir_in(install_dir: &Path) {
    let bin_dir = install_dir.join("bin");
    std::fs::create_dir_all(&bin_dir).unwrap();
    let gt_source = PathBuf::from(env!("CARGO_BIN_EXE_gt"));
    let gt_binary = bin_dir.join("gt");
    std::fs::copy(&gt_source, &gt_binary).unwrap();
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        std::fs::set_permissions(&gt_binary, std::fs::Permissions::from_mode(0o755)).unwrap();
    }
}

/// Creates a temporary directory containing a copied gt binary in bin/ and an
/// install.sh in the root so that self-update sees a valid installation.
fn create_install_dir(label: &str) -> PathBuf {
    let install_dir = unique_dir(label);
    create_install_dir_in(&install_dir);
    install_dir
}

/// Creates a git-based installation directory with a bare origin and a clone.
fn create_git_install_dir(label: &str) -> PathBuf {
    let base = unique_dir(label);
    let origin = base.join("origin.git");
    let install_dir = base.join("install");
    std::fs::create_dir_all(&origin).unwrap();

    Command::new("git")
        .args(["init", "--bare", "-q"])
        .current_dir(&origin)
        .status()
        .expect("git init --bare failed");

    Command::new("git")
        .args(["clone", "-q", origin.to_str().unwrap(), install_dir.to_str().unwrap()])
        .status()
        .expect("git clone failed");

    create_install_dir_in(&install_dir);
    install_dir
}

fn write_install_sh(install_dir: &Path, content: &str) {
    let path = install_dir.join("install.sh");
    std::fs::write(&path, content).unwrap();
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o755)).unwrap();
    }
}

/// Creates a local git repo (acting as the remote) without a `.gt` directory.
fn create_source_repo(label: &str) -> PathBuf {
    let repo = unique_dir(label).join("srcrepo");
    std::fs::create_dir_all(&repo).unwrap();
    git(&repo, &["init", "-q", "-b", "main"]);
    std::fs::write(repo.join("file.txt"), "hello\n").unwrap();
    git(&repo, &["-c", "user.email=a@b.c", "-c", "user.name=test", "add", "-A"]);
    git(
        &repo,
        &[
            "-c",
            "user.email=a@b.c",
            "-c",
            "user.name=test",
            "commit",
            "-qm",
            "init",
        ],
    );
    repo
}

fn git(cwd: &Path, args: &[&str]) {
    let status = Command::new("git")
        .args(args)
        .current_dir(cwd)
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .expect("failed to run git");
    assert!(status.success(), "git {:?} failed", args);
}

// ---------------------------------------------------------------------------
// help / version / command dispatch
// ---------------------------------------------------------------------------

#[test]
fn gt_help_lists_all_commands() {
    let dir = unique_dir("help");
    let out = run(&dir, &["--help"], "");
    assert_eq!(code(&out), 0);
    let o = stdout(&out);
    assert!(o.contains("Commands:"));
    for cmd in ["pull", "re-pull", "remote", "reset", "update", "self-update"] {
        assert!(o.contains(cmd), "missing command {cmd} in help");
    }
}

#[test]
fn remote_help_lists_subcommands() {
    let dir = unique_dir("remhelp");
    let out = run(&dir, &["remote", "--help"], "");
    assert_eq!(code(&out), 0);
    let o = stdout(&out);
    assert!(o.contains("Commands:"));
    for cmd in ["add", "remove", "list"] {
        assert!(o.contains(cmd), "missing subcommand {cmd}");
    }
}

#[test]
fn subcommand_help_prints_parameters_and_returns_99() {
    let dir = unique_dir("subhelp");
    for sub in [["remote", "add"], ["remote", "remove"], ["remote", "list"]] {
        let out = run(&dir, &[sub[0], sub[1], "--help"], "");
        // add/remove --help propagate parseArguments' 99 exit code (as in Bash)
        if sub[1] == "list" {
            assert_eq!(code(&out), 0, "list --help should be 0");
        } else {
            assert_eq!(code(&out), 99, "{sub:?} --help should be 99");
        }
        let o = stdout(&out);
        assert!(o.contains("Parameters"));
        assert!(o.contains("--version"));
        assert!(o.contains("prints the version of this script"));
        assert!(o.contains("--help"));
        assert!(o.contains("prints this help"));
    }
}

#[test]
fn no_command_exits_9() {
    let dir = unique_dir("nocmd");
    let out = run(&dir, &["remote"], "");
    assert_eq!(code(&out), 9);
}

#[test]
fn unknown_command_exits_1() {
    let dir = unique_dir("unknown");
    let out = run(&dir, &["remote", "bogus"], "");
    assert_eq!(code(&out), 1);
    assert!(stderr(&out).contains("unknown command"));
}

#[test]
fn not_yet_ported_command_reports_and_exits_1() {
    let dir = unique_dir("notported");
    let out = run(&dir, &["pull"], "");
    assert_eq!(code(&out), 1);
    assert!(stderr(&out).contains("not been ported"));
}

// ---------------------------------------------------------------------------
// list
// ---------------------------------------------------------------------------

#[test]
fn list_without_working_dir_exits_9() {
    let dir = unique_dir("listnone");
    let out = run(&dir, &["remote", "list"], "");
    assert_eq!(code(&out), 9);
    assert!(stderr(&out).contains("does not exist"));
}

#[test]
fn list_with_working_dir_outside_exits_1() {
    let dir = unique_dir("listoutside");
    std::fs::create_dir_all(dir.join(".gt")).unwrap();
    let out = run(&dir, &["remote", "list", "-w", ".."], "");
    assert_eq!(code(&out), 1);
    assert!(stderr(&out).contains("is not inside of"));
}

#[test]
fn list_empty_prints_hint() {
    let dir = unique_dir("listempty");
    std::fs::create_dir_all(dir.join(".gt")).unwrap();
    let out = run(&dir, &["remote", "list"], "");
    assert_eq!(code(&out), 0);
    assert!(stdout(&out).contains("No remote defined yet."));
}

#[test]
fn list_shows_sorted_remote_names() {
    let dir = unique_dir("listsorted");
    for name in ["zeta", "alpha", "mike"] {
        std::fs::create_dir_all(dir.join(".gt").join("remotes").join(name)).unwrap();
    }
    let out = run(&dir, &["remote", "list"], "");
    assert_eq!(code(&out), 0);
    assert_eq!(stdout(&out).trim(), "alpha\nmike\nzeta");
}

// ---------------------------------------------------------------------------
// add (unsecure, local file:// repo without .gt)
// ---------------------------------------------------------------------------

#[test]
fn add_unsecure_creates_structure() {
    let src = create_source_repo("addok");
    let consumer = unique_dir("addconsumer");
    std::fs::create_dir_all(consumer.join(".gt")).unwrap(); // avoid the "create workdir?" prompt
    let url = format!("file://{}", src.display());

    let out = run(
        &consumer,
        &["remote", "add", "-r", "myremote", "-u", &url, "--unsecure", "true"],
        "",
    );
    assert_eq!(code(&out), 0, "stderr: {}", stderr(&out));

    let remote_dir = consumer.join(".gt/remotes/myremote");
    assert!(remote_dir.join("pull.args").is_file());
    assert!(remote_dir.join("gitconfig").is_file());
    assert!(remote_dir.join("public-keys/gpg").is_dir());
    assert!(remote_dir.join("repo/.git").is_dir());

    let pull_args = std::fs::read_to_string(remote_dir.join("pull.args")).unwrap();
    assert!(pull_args.contains("--directory \"lib/myremote\""));
    assert!(pull_args.contains("--unsecure true"));

    // list now shows the remote
    let list = run(&consumer, &["remote", "list"], "");
    assert_eq!(stdout(&list).trim(), "myremote");
}

#[test]
fn add_with_custom_pull_dir_and_tag_filter() {
    let src = create_source_repo("addcustom");
    let consumer = unique_dir("addcustomconsumer");
    std::fs::create_dir_all(consumer.join(".gt")).unwrap();
    let url = format!("file://{}", src.display());

    let out = run(
        &consumer,
        &[
            "remote",
            "add",
            "-r",
            "r1",
            "-u",
            &url,
            "-d",
            "scripts/lib/r1",
            "--tag-filter",
            "^v[0-9]+",
            "--unsecure",
            "true",
        ],
        "",
    );
    assert_eq!(code(&out), 0, "stderr: {}", stderr(&out));
    let pull_args = std::fs::read_to_string(consumer.join(".gt/remotes/r1/pull.args")).unwrap();
    assert!(pull_args.contains("--directory \"scripts/lib/r1\""));
    assert!(pull_args.contains("--tag-filter \"^v[0-9]+\""));
}

#[test]
fn add_invalid_remote_name_exits_1() {
    let dir = unique_dir("addbadname");
    std::fs::create_dir_all(dir.join(".gt")).unwrap();
    let out = run(&dir, &["remote", "add", "-r", "bad name", "-u", "http://x"], "");
    assert_eq!(code(&out), 1);
    assert!(stderr(&out).contains("remote names need to match the regex"));
}

#[test]
fn add_missing_required_args_exits_1() {
    let dir = unique_dir("addmissing");
    std::fs::create_dir_all(dir.join(".gt")).unwrap();
    let out = run(&dir, &["remote", "add"], "");
    assert_eq!(code(&out), 1);
    let e = stderr(&out);
    assert!(e.contains("remote not set via -r|--remote"));
    assert!(e.contains("url not set via -u|--url"));
}

#[test]
fn add_existing_remote_with_pulled_files_exits_1() {
    let dir = unique_dir("addexisting");
    let remote_dir = dir.join(".gt/remotes/dup");
    std::fs::create_dir_all(&remote_dir).unwrap();
    std::fs::write(remote_dir.join("pulled.tsv"), "x").unwrap();
    let out = run(
        &dir,
        &["remote", "add", "-r", "dup", "-u", "http://x", "--unsecure", "true"],
        "",
    );
    assert_eq!(code(&out), 1);
    assert!(stderr(&out).contains("already exists with pulled files"));
}

// ---------------------------------------------------------------------------
// remove
// ---------------------------------------------------------------------------

#[test]
fn remove_nonexistent_remote_exits_9() {
    let dir = unique_dir("rmnone");
    std::fs::create_dir_all(dir.join(".gt/remotes/other")).unwrap();
    let out = run(&dir, &["remote", "remove", "-r", "nope"], "");
    assert_eq!(code(&out), 9);
    assert!(stderr(&out).contains("does not exist"));
    // it lists the existing remotes
    assert!(stdout(&out).contains("other"));
}

#[test]
fn remove_simple_remote_succeeds() {
    let dir = unique_dir("rmsimple");
    let remote_dir = dir.join(".gt/remotes/gone");
    std::fs::create_dir_all(remote_dir.join("public-keys")).unwrap();
    std::fs::write(remote_dir.join("pull.args"), "x").unwrap();

    let out = run(&dir, &["remote", "remove", "-r", "gone"], "");
    assert_eq!(code(&out), 0, "stderr: {}", stderr(&out));
    assert!(stdout(&out).contains("removed remote"));
    assert!(!remote_dir.exists());
}

#[test]
fn remove_with_delete_pulled_files_deletes_listed_files() {
    let dir = unique_dir("rmpulled");
    // working dir layout: .gt/remotes/r ; pulled files live relative to .gt
    let gt = dir.join(".gt");
    let remote_dir = gt.join("remotes/r");
    std::fs::create_dir_all(&remote_dir).unwrap();
    // create a pulled file at <.gt>/../lib/a.sh i.e. <dir>/lib/a.sh
    std::fs::create_dir_all(dir.join("lib")).unwrap();
    let pulled_file = dir.join("lib/a.sh");
    std::fs::write(&pulled_file, "content").unwrap();

    let tsv = "#@ Version: 1.2.0\n\
tag\tfile\trelativeTarget\ttagFilter\thasPlaceholder\tsha512\n\
v1.0.0\tsrc/a.sh\t../lib/a.sh\t.*\tfalse\tabc\n";
    std::fs::write(remote_dir.join("pulled.tsv"), tsv).unwrap();

    let out = run(
        &dir,
        &["remote", "remove", "-r", "r", "--delete-pulled-files", "true"],
        "",
    );
    assert_eq!(code(&out), 0, "stderr: {}", stderr(&out));
    assert!(stdout(&out).contains("deleted 1 pulled files"));
    assert!(!pulled_file.exists(), "pulled file should have been deleted");
    assert!(!remote_dir.exists());
}

#[test]
fn add_then_remove_round_trip() {
    let src = create_source_repo("roundtrip");
    let consumer = unique_dir("roundtripconsumer");
    std::fs::create_dir_all(consumer.join(".gt")).unwrap();
    let url = format!("file://{}", src.display());

    let add = run(
        &consumer,
        &["remote", "add", "-r", "rt", "-u", &url, "--unsecure", "true"],
        "",
    );
    assert_eq!(code(&add), 0, "add stderr: {}", stderr(&add));

    let remove = run(&consumer, &["remote", "remove", "-r", "rt"], "");
    assert_eq!(code(&remove), 0, "remove stderr: {}", stderr(&remove));

    let list = run(&consumer, &["remote", "list"], "");
    assert!(stdout(&list).contains("No remote defined yet."));
}

// ---------------------------------------------------------------------------
// self-update
// ---------------------------------------------------------------------------

#[test]
fn self_update_help_prints_parameters_and_returns_99() {
    let dir = unique_dir("suhelp");
    let out = run(&dir, &["self-update", "--help"], "");
    assert_eq!(code(&out), 99);
    let o = stdout(&out);
    assert!(o.contains("Parameters"));
    assert!(o.contains("--force"));
    assert!(o.contains("--help"));
    assert!(o.contains("prints this help"));
}

#[test]
fn self_update_version_returns_99() {
    let dir = unique_dir("suversion");
    let out = run(&dir, &["self-update", "--version"], "");
    assert_eq!(code(&out), 99);
    assert!(stdout(&out).contains("Version of gt is"));
}

#[test]
fn self_update_corrupt_installation_exits_1() {
    // The test binary lives in target/<profile>/, whose parent has no install.sh,
    // so self-update must report the corrupt-installation error and exit 1.
    let dir = unique_dir("sucorrupt");
    let out = run(&dir, &["self-update"], "");
    assert_eq!(code(&out), 1);
    assert!(stderr(&out).contains("there is no install.sh"));
}

#[test]
fn self_update_unknown_arg_exits_9() {
    let dir = unique_dir("suunknown");
    // answer the "shall I print the help?" prompt with "n"
    let out = run(&dir, &["self-update", "--bogus", "x"], "n\n");
    assert_eq!(code(&out), 9);
    assert!(stderr(&out).contains("unknown argument"));
}

#[test]
fn self_update_non_git_user_says_yes() {
    let install_dir = create_install_dir("suyes");
    write_install_sh(&install_dir, "#!/bin/sh\nexit 0");
    let exe_dir = install_dir.join("bin");
    let out = run_binary_env(
        &exe_dir.join("gt"),
        &install_dir,
        &["self-update"],
        "y\n",
        &[("GT_SELF_UPDATE_EXE_DIR", exe_dir.to_str().unwrap())],
    );
    assert_eq!(code(&out), 0, "stderr: {}", stderr(&out));
}

#[test]
fn self_update_non_git_user_says_no() {
    let install_dir = create_install_dir("suno");
    write_install_sh(&install_dir, "#!/bin/sh\nexit 0");
    let exe_dir = install_dir.join("bin");
    let out = run_binary_env(
        &exe_dir.join("gt"),
        &install_dir,
        &["self-update"],
        "n\n",
        &[("GT_SELF_UPDATE_EXE_DIR", exe_dir.to_str().unwrap())],
    );
    assert_eq!(code(&out), 1, "stderr: {}", stderr(&out));
    assert!(stdout(&out).contains("aborted self update"), "stdout: {}", stdout(&out));
}

#[test]
fn self_update_install_sh_fails_with_exit_code() {
    let install_dir = create_install_dir("sufail");
    write_install_sh(&install_dir, "#!/bin/sh\nexit 42");
    let exe_dir = install_dir.join("bin");
    let out = run_binary_env(
        &exe_dir.join("gt"),
        &install_dir,
        &["self-update"],
        "y\n",
        &[("GT_SELF_UPDATE_EXE_DIR", exe_dir.to_str().unwrap())],
    );
    assert_eq!(code(&out), 42, "stderr: {}", stderr(&out));
}

#[test]
fn self_update_git_already_latest() {
    let install_dir = create_git_install_dir("sugitlatest");
    git(&install_dir, &["-c", "user.email=a@b.c", "-c", "user.name=t", "commit", "--allow-empty", "-qm", "init"]);
    git(&install_dir, &["tag", "v1.0.0"]);
    git(&install_dir, &["push", "-q", "origin", "v1.0.0"]);
    // Delete the local tag so that creating a branch with the same name does
    // not make git rev-parse --abbrev-ref HEAD return heads/v1.0.0.
    git(&install_dir, &["tag", "-d", "v1.0.0"]);
    git(&install_dir, &["checkout", "-b", "v1.0.0"]);
    write_install_sh(&install_dir, "#!/bin/sh\nexit 0");
    let exe_dir = install_dir.join("bin");
    let out = run_binary_env(
        &exe_dir.join("gt"),
        &install_dir,
        &["self-update"],
        "",
        &[("GT_SELF_UPDATE_EXE_DIR", exe_dir.to_str().unwrap())],
    );
    assert_eq!(code(&out), 0, "stderr: {}", stderr(&out));
    assert!(stdout(&out).contains("already installed"), "stdout: {}", stdout(&out));
}

#[test]
fn self_update_git_force_reinstalls() {
    let install_dir = create_git_install_dir("sugitforce");
    git(&install_dir, &["-c", "user.email=a@b.c", "-c", "user.name=t", "commit", "--allow-empty", "-qm", "init"]);
    git(&install_dir, &["tag", "v1.0.0"]);
    git(&install_dir, &["push", "-q", "origin", "v1.0.0"]);
    // Delete the local tag so the branch name is unambiguous.
    git(&install_dir, &["tag", "-d", "v1.0.0"]);
    git(&install_dir, &["checkout", "-b", "v1.0.0"]);
    write_install_sh(&install_dir, "#!/bin/sh\nexit 0");
    let exe_dir = install_dir.join("bin");
    let out = run_binary_env(
        &exe_dir.join("gt"),
        &install_dir,
        &["self-update", "--force", "true"],
        "",
        &[("GT_SELF_UPDATE_EXE_DIR", exe_dir.to_str().unwrap())],
    );
    assert_eq!(code(&out), 0, "stderr: {}", stderr(&out));
    // It should mention it's reinstalling despite being on latest.
    assert!(
        stdout(&out).contains("going to re-install it"),
        "stdout: {}",
        stdout(&out)
    );
}

#[test]
fn self_update_git_behind_tag_proceeds() {
    let install_dir = create_git_install_dir("sugitbehind");
    git(&install_dir, &["-c", "user.email=a@b.c", "-c", "user.name=t", "commit", "--allow-empty", "-qm", "init"]);
    git(&install_dir, &["tag", "v1.0.0"]);
    git(&install_dir, &["push", "-q", "origin", "v1.0.0"]);
    // Stay on default branch (e.g. main), which differs from the tag
    write_install_sh(&install_dir, "#!/bin/sh\nexit 0");
    let exe_dir = install_dir.join("bin");
    let out = run_binary_env(
        &exe_dir.join("gt"),
        &install_dir,
        &["self-update"],
        "",
        &[("GT_SELF_UPDATE_EXE_DIR", exe_dir.to_str().unwrap())],
    );
    assert_eq!(code(&out), 0, "stderr: {}", stderr(&out));
    // It proceeds to update successfully
}

#[test]
fn self_update_temp_dir_creation_fails() {
    let install_dir = create_install_dir("sutempfail");
    write_install_sh(&install_dir, "#!/bin/sh\nexit 0");

    // make a read-only parent directory so create_dir_all fails
    let bad_tmp = install_dir.join("badtmp");
    std::fs::create_dir_all(&bad_tmp).unwrap();
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        std::fs::set_permissions(&bad_tmp, std::fs::Permissions::from_mode(0o555)).unwrap();
    }

    let exe_dir = install_dir.join("bin");
    let out = run_binary_env(
        &exe_dir.join("gt"),
        &install_dir,
        &["self-update"],
        "y\n",
        &[
            ("GT_SELF_UPDATE_EXE_DIR", exe_dir.to_str().unwrap()),
            ("TMPDIR", bad_tmp.to_str().unwrap()),
        ],
    );

    #[cfg(unix)]
    {
        std::fs::set_permissions(&bad_tmp, std::fs::Permissions::from_mode(0o755)).unwrap();
    }
    let _ = std::fs::remove_dir_all(&bad_tmp);

    assert_eq!(code(&out), 1, "stderr: {}", stderr(&out));
}

#[test]
fn self_update_copy_dir_recursive_fails() {
    let install_dir = create_install_dir("sucopyfail");
    write_install_sh(&install_dir, "#!/bin/sh\nexit 0");
    // add an unreadable file inside the install dir so copy_dir_recursive fails
    let unreadable = install_dir.join("unreadable.txt");
    std::fs::write(&unreadable, "secret").unwrap();
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        std::fs::set_permissions(&unreadable, std::fs::Permissions::from_mode(0o000)).unwrap();
    }

    let exe_dir = install_dir.join("bin");
    let out = run_binary_env(
        &exe_dir.join("gt"),
        &install_dir,
        &["self-update"],
        "y\n",
        &[("GT_SELF_UPDATE_EXE_DIR", exe_dir.to_str().unwrap())],
    );

    #[cfg(unix)]
    {
        std::fs::set_permissions(&unreadable, std::fs::Permissions::from_mode(0o644)).unwrap();
    }

    assert_eq!(code(&out), 1, "stderr: {}", stderr(&out));
}

// ---------------------------------------------------------------------------
// add (secure path with a real, generated GPG key)
// ---------------------------------------------------------------------------

/// Runs `gpg` with an isolated homedir; returns whether it succeeded.
fn gpg_ok(homedir: &Path, args: &[&str], stdin: Option<&str>) -> bool {
    let mut cmd = Command::new("gpg");
    cmd.env("GNUPGHOME", homedir)
        .args(args)
        .stdout(Stdio::null())
        .stderr(Stdio::null());
    if stdin.is_some() {
        cmd.stdin(Stdio::piped());
    }
    let Ok(mut child) = cmd.spawn() else { return false };
    if let Some(input) = stdin {
        let _ = child.stdin.take().unwrap().write_all(input.as_bytes());
    }
    child.wait().map(|s| s.success()).unwrap_or(false)
}

#[test]
fn add_secure_verifies_imports_and_trusts_key() {
    let base = unique_dir("secure");
    let store = base.join("userstore");
    std::fs::create_dir_all(&store).unwrap();
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        std::fs::set_permissions(&store, std::fs::Permissions::from_mode(0o700)).unwrap();
    }

    // generate a signing key in the (isolated) user store
    let params = "%no-protection\nKey-Type: RSA\nKey-Length: 2048\n\
Name-Real: Test Signer\nName-Email: signer@test.local\nExpire-Date: 0\n%commit\n";
    let params_file = base.join("keyparams");
    std::fs::write(&params_file, params).unwrap();
    if !gpg_ok(&store, &["--batch", "--gen-key", params_file.to_str().unwrap()], None) {
        eprintln!("skipping add_secure_*: gpg key generation not available in this environment");
        return;
    }

    // build the source repo with a .gt directory holding the public key + signature
    let src = base.join("srcrepo");
    let gt = src.join(".gt");
    std::fs::create_dir_all(&gt).unwrap();
    assert!(gpg_ok(
        &store,
        &[
            "--armor",
            "--output",
            gt.join("signing-key.public.asc").to_str().unwrap(),
            "--export",
            "signer@test.local"
        ],
        None,
    ));
    assert!(gpg_ok(
        &store,
        &[
            "--output",
            gt.join("signing-key.public.asc.sig").to_str().unwrap(),
            "--detach-sign",
            gt.join("signing-key.public.asc").to_str().unwrap(),
        ],
        None,
    ));
    git(&src, &["init", "-q", "-b", "main"]);
    git(&src, &["-c", "user.email=a@b.c", "-c", "user.name=t", "add", "-A"]);
    git(
        &src,
        &["-c", "user.email=a@b.c", "-c", "user.name=t", "commit", "-qm", "init"],
    );

    // consumer adds the remote *without* --unsecure -> must verify & import the key
    let consumer = base.join("consumer");
    std::fs::create_dir_all(consumer.join(".gt")).unwrap();
    let url = format!("file://{}", src.display());
    let out = run_env(
        &consumer,
        &["remote", "add", "-r", "secure", "-u", &url],
        "",
        &[("GNUPGHOME", store.to_str().unwrap())],
    );

    assert_eq!(code(&out), 0, "stdout: {}\nstderr: {}", stdout(&out), stderr(&out));
    assert!(stdout(&out).contains("was set up successfully"));

    let remote_dir = consumer.join(".gt/remotes/secure");
    // public key + signature were moved into public-keys, gpg store populated
    assert!(remote_dir.join("public-keys/signing-key.public.asc").is_file());
    assert!(remote_dir.join("public-keys/signing-key.public.asc.sig").is_file());
    assert!(remote_dir.join("public-keys/gpg/signing-key.last-check.txt").is_file());
    // the temporary repo/.gt checkout was cleaned up
    assert!(!remote_dir.join("repo/.gt").exists());
    // pull.args must NOT contain --unsecure on the secure path
    let pull_args = std::fs::read_to_string(remote_dir.join("pull.args")).unwrap();
    assert!(pull_args.contains("--directory \"lib/secure\""));
    assert!(!pull_args.contains("--unsecure"));
}
