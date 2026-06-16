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
    let out = run(&dir, &["update"], "");
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

// ---------------------------------------------------------------------------
// helpers for pull tests
// ---------------------------------------------------------------------------

fn create_source_repo_with_file(label: &str, subpath: &str, content: &str) -> PathBuf {
    let repo = unique_dir(label).join("srcrepo");
    std::fs::create_dir_all(&repo).unwrap();
    git(&repo, &["init", "-q", "-b", "main"]);
    let file = repo.join(subpath);
    std::fs::create_dir_all(file.parent().unwrap()).unwrap();
    std::fs::write(&file, content).unwrap();
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

fn tag_repo(repo: &Path, tag: &str) {
    git(repo, &["tag", tag]);
}

// ---------------------------------------------------------------------------
// pull
// ---------------------------------------------------------------------------

#[test]
fn pull_single_file_success() {
    let src = create_source_repo_with_file("pullfile", "src/hello.sh", "#!/bin/bash\n");
    tag_repo(&src, "v0.1.0");

    let consumer = unique_dir("pullfile-consumer");
    std::fs::create_dir_all(consumer.join(".gt")).unwrap();
    let url = format!("file://{}", src.display());

    let add = run(
        &consumer,
        &["remote", "add", "-r", "myremote", "-u", &url, "--unsecure", "true"],
        "",
    );
    assert_eq!(code(&add), 0, "add stderr: {}", stderr(&add));

    let out = run(
        &consumer,
        &["pull", "-r", "myremote", "-p", "src/hello.sh", "-t", "v0.1.0"],
        "",
    );
    assert_eq!(code(&out), 0, "stderr: {}", stderr(&out));
    assert!(stdout(&out).contains("pulled from"));

    let pulled_file = consumer.join("lib/myremote/src/hello.sh");
    assert!(pulled_file.is_file());
    let content = std::fs::read_to_string(&pulled_file).unwrap();
    assert_eq!(content, "#!/bin/bash\n");
}

#[test]
fn pull_directory_success() {
    let src = create_source_repo_with_file("pulldir", "scripts/lib/a.sh", "a\n");
    let b = src.join("scripts/lib/b.sh");
    std::fs::write(&b, "b\n").unwrap();
    git(&src, &["-c", "user.email=a@b.c", "-c", "user.name=test", "add", "-A"]);
    git(
        &src,
        &[
            "-c",
            "user.email=a@b.c",
            "-c",
            "user.name=test",
            "commit",
            "-qm",
            "add-b",
        ],
    );
    tag_repo(&src, "v1.0.0");

    let consumer = unique_dir("pulldir-consumer");
    std::fs::create_dir_all(consumer.join(".gt")).unwrap();
    let url = format!("file://{}", src.display());

    let add = run(
        &consumer,
        &["remote", "add", "-r", "dirremote", "-u", &url, "--unsecure", "true"],
        "",
    );
    assert_eq!(code(&add), 0);

    let out = run(
        &consumer,
        &["pull", "-r", "dirremote", "-p", "scripts/lib/", "-t", "v1.0.0"],
        "",
    );
    assert_eq!(code(&out), 0, "stderr: {}", stderr(&out));
    assert!(stdout(&out).contains("files pulled"));

    assert!(consumer.join("lib/dirremote/scripts/lib/a.sh").is_file());
    assert!(consumer.join("lib/dirremote/scripts/lib/b.sh").is_file());
}

#[test]
fn pull_chop_path_file() {
    let src = create_source_repo_with_file("chopfile", "src/utils.sh", "utils\n");
    tag_repo(&src, "v0.2.0");

    let consumer = unique_dir("chopfile-consumer");
    std::fs::create_dir_all(consumer.join(".gt")).unwrap();
    let url = format!("file://{}", src.display());

    let add = run(
        &consumer,
        &["remote", "add", "-r", "chopremote", "-u", &url, "--unsecure", "true"],
        "",
    );
    assert_eq!(code(&add), 0);

    let out = run(
        &consumer,
        &[
            "pull",
            "-r",
            "chopremote",
            "-p",
            "src/utils.sh",
            "-t",
            "v0.2.0",
            "--chop-path",
            "true",
        ],
        "",
    );
    assert_eq!(code(&out), 0, "stderr: {}", stderr(&out));

    assert!(consumer.join("lib/chopremote/utils.sh").is_file());
}

#[test]
fn pull_chop_path_directory() {
    let src = create_source_repo_with_file("chopdir", "src/lib/a.sh", "a\n");
    tag_repo(&src, "v0.3.0");

    let consumer = unique_dir("chopdir-consumer");
    std::fs::create_dir_all(consumer.join(".gt")).unwrap();
    let url = format!("file://{}", src.display());

    let add = run(
        &consumer,
        &["remote", "add", "-r", "chopdremote", "-u", &url, "--unsecure", "true"],
        "",
    );
    assert_eq!(code(&add), 0);

    let out = run(
        &consumer,
        &[
            "pull",
            "-r",
            "chopdremote",
            "-p",
            "src/lib/",
            "-t",
            "v0.3.0",
            "--chop-path",
            "true",
        ],
        "",
    );
    assert_eq!(code(&out), 0, "stderr: {}", stderr(&out));

    assert!(consumer.join("lib/chopdremote/a.sh").is_file());
}

#[test]
fn pull_target_file_name() {
    let src = create_source_repo_with_file("rename", "src/old.sh", "old\n");
    tag_repo(&src, "v0.4.0");

    let consumer = unique_dir("rename-consumer");
    std::fs::create_dir_all(consumer.join(".gt")).unwrap();
    let url = format!("file://{}", src.display());

    let add = run(
        &consumer,
        &["remote", "add", "-r", "renremote", "-u", &url, "--unsecure", "true"],
        "",
    );
    assert_eq!(code(&add), 0);

    let out = run(
        &consumer,
        &[
            "pull",
            "-r",
            "renremote",
            "-p",
            "src/old.sh",
            "-t",
            "v0.4.0",
            "--target-file-name",
            "new.sh",
        ],
        "",
    );
    assert_eq!(code(&out), 0, "stderr: {}", stderr(&out));

    assert!(consumer.join("lib/renremote/src/new.sh").is_file());
}

#[test]
fn pull_directory_with_target_file_name_fails() {
    let src = create_source_repo_with_file("dirtgt", "dir/a.sh", "a\n");
    tag_repo(&src, "v0.5.0");

    let consumer = unique_dir("dirtgt-consumer");
    std::fs::create_dir_all(consumer.join(".gt")).unwrap();
    let url = format!("file://{}", src.display());

    let add = run(
        &consumer,
        &["remote", "add", "-r", "dtgremote", "-u", &url, "--unsecure", "true"],
        "",
    );
    assert_eq!(code(&add), 0);

    let out = run(
        &consumer,
        &[
            "pull",
            "-r",
            "dtgremote",
            "-p",
            "dir/",
            "-t",
            "v0.5.0",
            "--target-file-name",
            "x.sh",
        ],
        "",
    );
    assert_eq!(code(&out), 1);
    assert!(stderr(&out).contains("cannot specify"));
}

#[test]
fn pull_leading_slash_in_path_fails() {
    let src = create_source_repo_with_file("slash", "a.sh", "a\n");
    tag_repo(&src, "v0.6.0");

    let consumer = unique_dir("slash-consumer");
    std::fs::create_dir_all(consumer.join(".gt")).unwrap();
    let url = format!("file://{}", src.display());

    let add = run(
        &consumer,
        &["remote", "add", "-r", "slremote", "-u", &url, "--unsecure", "true"],
        "",
    );
    assert_eq!(code(&add), 0);

    let out = run(
        &consumer,
        &["pull", "-r", "slremote", "-p", "/a.sh", "-t", "v0.6.0"],
        "",
    );
    assert_eq!(code(&out), 1);
    assert!(stderr(&out).contains("Leading / not allowed"));
}

#[test]
fn pull_target_file_name_with_slash_fails() {
    let src = create_source_repo_with_file("tgtslash", "a.sh", "a\n");
    tag_repo(&src, "v0.7.0");

    let consumer = unique_dir("tgtslash-consumer");
    std::fs::create_dir_all(consumer.join(".gt")).unwrap();
    let url = format!("file://{}", src.display());

    let add = run(
        &consumer,
        &["remote", "add", "-r", "tsremote", "-u", &url, "--unsecure", "true"],
        "",
    );
    assert_eq!(code(&add), 0);

    let out = run(
        &consumer,
        &[
            "pull",
            "-r",
            "tsremote",
            "-p",
            "a.sh",
            "-t",
            "v0.7.0",
            "--target-file-name",
            "b/c.sh",
        ],
        "",
    );
    assert_eq!(code(&out), 1);
    assert!(stderr(&out).contains("/ not allowed in the targetFileName"));
}

#[test]
fn pull_missing_required_args_fails() {
    let dir = unique_dir("missing");
    std::fs::create_dir_all(dir.join(".gt")).unwrap();
    let out = run(&dir, &["pull", "-r", "missing-remote"], "");
    assert_eq!(code(&out), 1);
    assert!(stderr(&out).contains("path not set"));
}

#[test]
fn pull_same_tag_sha_changed_warns_and_refuses() {
    let src = create_source_repo_with_file("sha", "src/f.sh", "v1\n");
    tag_repo(&src, "v1.0.0");

    let consumer = unique_dir("sha-consumer");
    std::fs::create_dir_all(consumer.join(".gt")).unwrap();
    let url = format!("file://{}", src.display());

    let add = run(
        &consumer,
        &["remote", "add", "-r", "sharemote", "-u", &url, "--unsecure", "true"],
        "",
    );
    assert_eq!(code(&add), 0);

    // First pull at v1.0.0
    let first = run(
        &consumer,
        &["pull", "-r", "sharemote", "-p", "src/f.sh", "-t", "v1.0.0"],
        "",
    );
    assert_eq!(code(&first), 0, "first pull stderr: {}", stderr(&first));

    // Overwrite source file with different content and commit + tag again
    std::fs::write(src.join("src/f.sh"), "v2\n").unwrap();
    git(&src, &["-c", "user.email=a@b.c", "-c", "user.name=test", "add", "-A"]);
    git(
        &src,
        &["-c", "user.email=a@b.c", "-c", "user.name=test", "commit", "-qm", "v2"],
    );
    git(&src, &["tag", "-d", "v1.0.0"]);
    tag_repo(&src, "v1.0.0");

    // Delete the local tag in the consumer repo so the new tag content is fetched
    let consumer_repo = consumer.join(".gt/remotes/sharemote/repo");
    git(&consumer_repo, &["tag", "-d", "v1.0.0"]);

    // Re-pull at the same tag — sha should differ, so it should refuse
    let second = run(
        &consumer,
        &["pull", "-r", "sharemote", "-p", "src/f.sh", "-t", "v1.0.0"],
        "",
    );
    assert_eq!(code(&second), 1, "second pull should fail: {}", stderr(&second));
    assert!(stderr(&second).contains("sha512") || stderr(&second).contains("0 files"));
}

#[test]
fn pull_auto_detect_latest_tag_with_filter() {
    let src = create_source_repo_with_file("latest", "file.txt", "hello\n");
    git(
        &src,
        &[
            "-c",
            "user.email=a@b.c",
            "-c",
            "user.name=test",
            "commit",
            "--allow-empty",
            "-qm",
            "empty",
        ],
    );
    tag_repo(&src, "v2.0.0");
    tag_repo(&src, "v1.0.0");
    tag_repo(&src, "beta-1.0");

    let consumer = unique_dir("latest-consumer");
    std::fs::create_dir_all(consumer.join(".gt")).unwrap();
    let url = format!("file://{}", src.display());

    let add = run(
        &consumer,
        &["remote", "add", "-r", "latremote", "-u", &url, "--unsecure", "true"],
        "",
    );
    assert_eq!(code(&add), 0);

    let out = run(
        &consumer,
        &["pull", "-r", "latremote", "-p", "file.txt", "--tag-filter", "^v[0-9]+"],
        "",
    );
    assert_eq!(code(&out), 0, "stderr: {}", stderr(&out));
    assert!(stdout(&out).contains("pulled from"));

    // Should have pulled v2.0.0 (latest matching ^v[0-9]+)
    let tsv = consumer.join(".gt/remotes/latremote/pulled.tsv");
    let tsv_content = std::fs::read_to_string(&tsv).unwrap();
    assert!(
        tsv_content.contains("v2.0.0"),
        "should pull v2.0.0, got:\n{tsv_content}"
    );
}

/// Regression test for the `with_extension("sig")` bug:
/// a file like `install.sh` with a corresponding `install.sh.sig`
/// should be found, not `install.sig`.
#[test]
fn pull_finds_sig_file_with_compound_extension() {
    let src = create_source_repo_with_file("sigbug", "install.sh", "#!/bin/bash\n");
    // create the .sig file and commit it
    std::fs::write(src.join("install.sh.sig"), "detached-sig\n").unwrap();
    git(&src, &["-c", "user.email=a@b.c", "-c", "user.name=test", "add", "-A"]);
    git(
        &src,
        &[
            "-c",
            "user.email=a@b.c",
            "-c",
            "user.name=test",
            "commit",
            "-qm",
            "add-sig",
        ],
    );
    tag_repo(&src, "v1.0.0");

    let consumer = unique_dir("sigbug-consumer");
    std::fs::create_dir_all(consumer.join(".gt")).unwrap();
    let url = format!("file://{}", src.display());

    let add = run(
        &consumer,
        &["remote", "add", "-r", "sigremote", "-u", &url, "--unsecure", "true"],
        "",
    );
    assert_eq!(code(&add), 0, "add stderr: {}", stderr(&add));

    // Fake a gpg store so that do_verification stays true:
    // gpg_dir must exist and contain trustdb.gpg so unsecure+do_verification doesn't disable it.
    let gpg_dir = consumer.join(".gt/remotes/sigremote/public-keys/gpg");
    std::fs::create_dir_all(&gpg_dir).unwrap();
    std::fs::write(gpg_dir.join("trustdb.gpg"), "").unwrap();

    let out = run(
        &consumer,
        &["pull", "-r", "sigremote", "-p", "install.sh", "-t", "v1.0.0"],
        "",
    );

    // The bug makes gt look for install.sig instead of install.sh.sig,
    // so verification warns "no corresponding *.sig file" and 0 files are pulled.
    // With the fix the sig is found; gpg verification will fail (fake key),
    // which also leads to "0 files" / exit 1 but via the "gpg verification failed" path.
    // We distinguish the two by checking the stderr.
    assert!(
        !stdout(&out).contains("no corresponding *.sig"),
        "gt should find install.sh.sig, not look for install.sig -- bug!\nstdout: {}",
        stdout(&out)
    );
}
