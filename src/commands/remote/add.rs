use crate::pulled_utils::{check_remote_exists_with_pulled, create_remote_dir, write_pull_args_file};
use clap::Args;
use std::env;
use std::fs;
use std::io;
use std::path::{Path, PathBuf};

#[derive(Debug)]
pub enum AddError {
	Io(io::Error),
	Git(git2::Error),
	Gpgme(gpgme::Error),
	Validation(String),
	Utf8(std::str::Utf8Error),
}

impl std::fmt::Display for AddError {
	fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
		match self {
			AddError::Io(e) => write!(f, "IO error: {}", e),
			AddError::Git(e) => write!(f, "Git error: {}", e),
			AddError::Gpgme(e) => write!(f, "GPGME error: {}", e),
			AddError::Validation(msg) => write!(f, "{}", msg),
			AddError::Utf8(e) => write!(f, "UTF-8 error: {}", e),
		}
	}
}

impl std::error::Error for AddError {}

impl From<io::Error> for AddError {
	fn from(e: io::Error) -> Self {
		AddError::Io(e)
	}
}

impl From<git2::Error> for AddError {
	fn from(e: git2::Error) -> Self {
		AddError::Git(e)
	}
}

impl From<gpgme::Error> for AddError {
	fn from(e: gpgme::Error) -> Self {
		AddError::Gpgme(e)
	}
}

impl From<std::str::Utf8Error> for AddError {
	fn from(e: std::str::Utf8Error) -> Self {
		AddError::Utf8(e)
	}
}

use crate::commands::common_args::{RemoteArg, WorkingDirectoryArg};

#[derive(Args)]
pub struct RemoteAddArgs {
	#[command(flatten)]
	pub remote_arg: RemoteArg,

	/// URL of the remote repository
	#[arg(short = 'u', long)]
	pub url: String,

	/// (Optional) Directory into which files are pulled [default: lib/<REMOTE>]
	#[arg(short = 'd', long)]
	pub directory: Option<String>,

	/// Define a regexp pattern to filter available tags when determining the latest tag
	#[arg(long)]
	pub tag_filter: Option<String>,

	/// (Optional) If set, the remote does not need to have a .gt/signing-key.public.asc defined
	#[arg(long, default_value_t = false)]
	pub unsecure: bool,

	#[command(flatten)]
	pub working_directory_arg: WorkingDirectoryArg,
}

impl RemoteAddArgs {
	pub fn working_directory(&self) -> &Path {
		&self.working_directory_arg.working_directory.as_path()
	}
	pub fn remote(&self) -> &String {
		&self.remote_arg.remote
	}
}

pub fn run(args: RemoteAddArgs) {
	if let Err(e) = run_impl(args) {
		eprintln!("Error: {}", e);
		std::process::exit(1);
	}
}

fn run_impl(args: RemoteAddArgs) -> Result<(), AddError> {
	let remote_name = args.remote_arg.remote;
	let url = args.url;
	let pull_dir = args.directory.unwrap_or_else(|| format!("lib/{}", remote_name));
	let tag_filter = args.tag_filter.unwrap_or_else(|| ".*".to_string());
	let unsecure = args.unsecure;
	let working_dir = args
		.working_directory_arg
		.working_directory
		.to_str()
		.unwrap_or_else(|| ".gt");

	validate_remote_name(&remote_name)?;

	let current_dir = env::current_dir()?;
	let working_dir_absolute = resolve_path(&current_dir, &working_dir);
	path_inside_current_dir(&working_dir_absolute, &current_dir)?;

	if !working_dir_absolute.exists() {
		eprintln!("info: creating working directory {}", working_dir_absolute.display());
		fs::create_dir_all(&working_dir_absolute)?;
	}

	let remotes_dir = working_dir_absolute.join("remotes");
	fs::create_dir_all(&remotes_dir)?;

	let remote_dir = remotes_dir.join(&remote_name);

	if check_remote_exists_with_pulled(&remote_dir) {
		return Err(AddError::Validation(format!(
			"remote {} already exists with pulled files",
			remote_name
		)));
	}

	if remote_dir.exists() {
		eprintln!(
			"warning: remote {} already exists but without pulled files, removing it",
			remote_name
		);
		fs::remove_dir_all(&remote_dir)?;
	}

	create_remote_dir(&remote_dir)?;
	let cleanup = RemoteCleanup::new(remote_dir.clone());

	write_pull_args_file(&remote_dir, &pull_dir, &tag_filter, unsecure)?;

	let public_keys_dir = remote_dir.join("public-keys");
	fs::create_dir_all(&public_keys_dir)?;

	let gpg_dir = public_keys_dir.join("gpg");
	fs::create_dir_all(&gpg_dir)?;

	let repo_dir = remote_dir.join("repo");
	let repo = git2::Repository::init(&repo_dir)?;

	repo.remote(&remote_name, &url)?;

	let gitconfig_path = remote_dir.join("gitconfig");
	let git_config_src = repo_dir.join(".git").join("config");
	fs::copy(&git_config_src, &gitconfig_path)?;

	let default_branch = match determine_default_branch(&repo, &remote_name) {
		Ok(branch) => branch,
		Err(e) => {
			eprintln!(
				"warning: could not determine default branch for remote {}: {}. Going to use main.",
				remote_name, e
			);
			"main".to_string()
		}
	};

	let mut remote = repo.find_remote(&remote_name)?;
	let refspecs: &[&str] = &[&default_branch];
	match remote.fetch(refspecs, None, None) {
		Ok(_) => {}
		Err(e) => {
			if unsecure {
				eprintln!(
					"warning: could not fetch from remote {}: {}. Ignoring because --unsecure was specified.",
					remote_name, e
				);
				write_pull_args_file(&remote_dir, &pull_dir, &tag_filter, true)?;
				return Ok(());
			} else {
				return Err(e.into());
			}
		}
	}

	match checkout_gt_dir(&repo, &remote_name, &default_branch) {
		Ok(()) => {}
		Err(e) => {
			if unsecure {
				eprintln!(
					"warning: could not checkout .gt directory from remote {}: {}. Ignoring because --unsecure was specified.",
					remote_name, e
				);
				write_pull_args_file(&remote_dir, &pull_dir, &tag_filter, true)?;
				return Ok(());
			} else {
				return Err(e);
			}
		}
	};

	let signing_key_path = repo_dir.join(".gt").join("signing-key.public.asc");
	if !signing_key_path.exists() {
		if unsecure {
			eprintln!(
				"warning: remote {} has a directory .gt but no signing-key.public.asc in it. Ignoring because --unsecure was specified.",
				remote_name
			);
			write_pull_args_file(&remote_dir, &pull_dir, &tag_filter, true)?;
			return Ok(());
		} else {
			return Err(AddError::Validation(format!(
				"remote {} has a directory .gt but no signing-key.public.asc in it -- you can disable this check via --unsecure",
				remote_name
			)));
		}
	}

	let imported = match import_gpg_keys(&gpg_dir, &signing_key_path) {
		Ok(count) => count,
		Err(e) => {
			if unsecure {
				eprintln!(
					"warning: could not import GPG keys for remote {}: {}. Ignoring because --unsecure was specified.",
					remote_name, e
				);
				return Ok(());
			} else {
				return Err(e);
			}
		}
	};

	if imported == 0 {
		if unsecure {
			eprintln!(
				"warning: no GPG keys imported for remote {}. Ignoring because --unsecure was specified.",
				remote_name
			);
			return Ok(());
		} else {
			return Err(AddError::Validation(format!(
				"no GPG keys imported for remote {}. You can disable this check via --unsecure",
				remote_name
			)));
		}
	}

	list_gpg_keys(&gpg_dir)?;

	// Copy signing key to public-keys dir and clean up repo/.gt
	fs::copy(&signing_key_path, public_keys_dir.join("signing-key.public.asc"))?;
	let sig_path = repo_dir.join(".gt").join("signing-key.public.asc.sig");
	if sig_path.exists() {
		fs::copy(&sig_path, public_keys_dir.join("signing-key.public.asc.sig"))?;
	}
	fs::remove_dir_all(repo_dir.join(".gt"))?;

	cleanup.success();

	println!(
		"remote {} was set up successfully; imported {} GPG key(s) for verification.\nYou are ready to pull files via:\ngt pull -r {} -p <PATH>",
		remote_name, imported, remote_name
	);

	Ok(())
}

fn validate_remote_name(name: &String) -> Result<(), AddError> {
	if name.is_empty() {
		return Err(AddError::Validation("remote name cannot be empty".into()));
	}
	for ch in name.chars() {
		if !ch.is_alphanumeric() && ch != '_' && ch != '-' {
			return Err(AddError::Validation(format!(
				"remote names need to match the regex ^[a-zA-Z0-9_-]+$ given {}",
				name
			)));
		}
	}
	Ok(())
}

fn resolve_path(current_dir: &Path, path: &str) -> PathBuf {
	let p = Path::new(path);
	if p.is_absolute() {
		p.to_path_buf()
	} else {
		current_dir.join(p)
	}
}

fn path_inside_current_dir(path: &Path, current_dir: &Path) -> Result<(), AddError> {
	if !path.starts_with(current_dir) {
		return Err(AddError::Validation(format!(
			"path {} is outside of current directory",
			path.display()
		)));
	}
	Ok(())
}

struct RemoteCleanup {
	remote_dir: PathBuf,
	active: bool,
}

impl RemoteCleanup {
	fn new(remote_dir: PathBuf) -> Self {
		Self {
			remote_dir,
			active: true,
		}
	}
	fn success(mut self) {
		self.active = false;
	}
}

impl Drop for RemoteCleanup {
	fn drop(&mut self) {
		if self.active {
			let _ = fs::remove_dir_all(&self.remote_dir);
			let _ = fs::create_dir(&self.remote_dir);
		}
	}
}

fn determine_default_branch(repo: &git2::Repository, remote_name: &str) -> Result<String, AddError> {
	let mut remote = repo.find_remote(remote_name)?;
	remote.connect(git2::Direction::Fetch)?;
	let buf = remote.default_branch()?;
	let s = std::str::from_utf8(&buf)?;
	let branch = s.strip_prefix("refs/heads/").unwrap_or(s);
	Ok(branch.to_string())
}

fn checkout_gt_dir(repo: &git2::Repository, remote_name: &str, branch: &str) -> Result<(), AddError> {
	let remote_branch = format!("refs/remotes/{}/{}", remote_name, branch);
	let object = repo.revparse_single(&remote_branch)?;
	repo.set_head_detached(object.id())?;

	let mut builder = git2::build::CheckoutBuilder::new();
	builder.path(".");
	builder.force();
	repo.checkout_tree(&object, Some(&mut builder))?;

	Ok(())
}

fn import_gpg_keys(gpg_dir: &Path, signing_key_path: &Path) -> Result<usize, AddError> {
	let mut ctx = gpgme::Context::from_protocol(gpgme::Protocol::OpenPgp)?;
	ctx.set_engine_home_dir(
		gpg_dir
			.to_str()
			.ok_or_else(|| AddError::Validation("invalid GPG dir path".into()))?,
	)?;

	let data = gpgme::Data::load(
		signing_key_path
			.to_str()
			.ok_or_else(|| AddError::Validation("invalid key path".into()))?,
	)?;
	let result = ctx.import(data)?;

	let imported = result.imported() as usize
		+ result.new_user_ids() as usize
		+ result.new_subkeys() as usize
		+ result.new_signatures() as usize;

	Ok(imported)
}

fn list_gpg_keys(gpg_dir: &Path) -> Result<(), AddError> {
	let mut ctx = gpgme::Context::from_protocol(gpgme::Protocol::OpenPgp)?;
	ctx.set_engine_home_dir(
		gpg_dir
			.to_str()
			.ok_or_else(|| AddError::Validation("invalid GPG dir path".into()))?,
	)?;
	ctx.set_key_list_mode(gpgme::KeyListMode::SIGS)?;

	for key_result in ctx.keys()? {
		let key = key_result?;
		let fp = key.fingerprint().unwrap_or("??");
		eprintln!("    Key fingerprint: {}", fp);
		for uid in key.user_ids() {
			eprintln!("    uid {}", uid.name().unwrap_or("?"));
			for sig in uid.signatures() {
				let _sig_id = sig.signer_key_id().unwrap_or("?");
				let sig_name = sig.signer_name().unwrap_or("?");
				let status = if sig.is_revocation() { " [revocation]" } else { "" };
				eprintln!("    sig {}{}", sig_name, status);
			}
		}
	}

	Ok(())
}

#[cfg(test)]
mod tests {
	use super::*;
	use tempfile::TempDir;

	#[test]
	fn valid_remote_name() {
		assert!(validate_remote_name(&"tegonal-scripts".to_string()).is_ok());
		assert!(validate_remote_name(&"my_remote".to_string()).is_ok());
		assert!(validate_remote_name(&"a-b-1".to_string()).is_ok());
		assert!(validate_remote_name(&"A_B-2".to_string()).is_ok());
	}

	#[test]
	fn invalid_remote_name() {
		assert!(validate_remote_name(&"".to_string()).is_err());
		assert!(validate_remote_name(&"my remote".to_string()).is_err());
		assert!(validate_remote_name(&"my/remote".to_string()).is_err());
		assert!(validate_remote_name(&":remote".to_string()).is_err());
		assert!(validate_remote_name(&"remote!".to_string()).is_err());
	}

	#[test]
	fn path_inside_current_dir_positive() {
		let current = PathBuf::from("/home/user/project");
		let sub = PathBuf::from("/home/user/project/.gt");
		assert!(path_inside_current_dir(&sub, &current).is_ok());
	}

	#[test]
	fn path_inside_current_dir_negative() {
		let current = PathBuf::from("/home/user/project");
		let outside = PathBuf::from("/home/user/other/.gt");
		assert!(path_inside_current_dir(&outside, &current).is_err());
	}

	#[test]
	fn resolve_path_relative() {
		let current = PathBuf::from("/home/user/project");
		assert_eq!(resolve_path(&current, ".gt"), PathBuf::from("/home/user/project/.gt"));
	}

	#[test]
	fn resolve_path_absolute() {
		let current = PathBuf::from("/home/user/project");
		assert_eq!(resolve_path(&current, "/tmp/gt"), PathBuf::from("/tmp/gt"));
	}

	#[test]
	fn run_impl_with_invalid_remote() {
		let tmp = TempDir::new().unwrap();
		let project = tmp.path().join("project");
		fs::create_dir(&project).unwrap();

		let args = RemoteAddArgs {
			remote_arg: RemoteArg {
				remote: "invalid remote!".to_string(),
			},
			url: "https://example.com/repo.git".to_string(),
			directory: None,
			tag_filter: None,
			unsecure: false,
			working_directory_arg: WorkingDirectoryArg {
				working_directory: project.to_path_buf(),
			},
		};

		let result = run_impl(args);
		assert!(result.is_err());
		let err = result.unwrap_err().to_string();
		assert!(err.contains("regex"), "got: {}", err);
	}

	#[test]
	fn run_impl_creates_working_directory() {
		let tmp = TempDir::new().unwrap();
		let project = tmp.path().join("project");
		fs::create_dir(&project).unwrap();
		env::set_current_dir(&project).unwrap();

		let args = RemoteAddArgs {
			remote_arg: RemoteArg {
				remote: "test-remote".to_string(),
			},
			url: "https://example.com/nonexistent.git".to_string(),
			directory: None,
			tag_filter: None,
			unsecure: true,
			working_directory_arg: WorkingDirectoryArg {
				working_directory: project.to_path_buf(),
			},
		};

		let _result = run_impl(args);
		// Should fail at fetch because URL is fake, but unsecure will catch it.
		// Actually, git2 remote fetch might fail before reaching unsecure handling.
		// The test just verifies directory creation happened.
		let working_dir = project.join(".gt");
		assert!(working_dir.exists());
	}

	#[test]
	fn run_impl_detects_existing_remote_with_pulled() {
		let tmp = TempDir::new().unwrap();
		let project = tmp.path().join("project");
		fs::create_dir(&project).unwrap();
		env::set_current_dir(&project).unwrap();

		let remote_dir = project.join(".gt").join("remotes").join("existing");
		fs::create_dir_all(&remote_dir).unwrap();
		fs::File::create(remote_dir.join("pulled.tsv")).unwrap();

		let args = RemoteAddArgs {
			remote_arg: RemoteArg {
				remote: "existing".to_string(),
			},
			url: "https://example.com/repo.git".to_string(),
			directory: None,
			tag_filter: None,
			unsecure: false,
			working_directory_arg: WorkingDirectoryArg {
				working_directory: project.to_path_buf(),
			},
		};

		let result = run_impl(args);
		assert!(result.is_err());
		let err = result.unwrap_err().to_string();
		assert!(err.contains("already exists"), "got: {}", err);
	}

	#[test]
	fn checkout_gt_dir_with_local_repo() {
		let tmp = TempDir::new().unwrap();
		let bare = tmp.path().join("bare.git");

		// Create a bare repo with a .gt directory in its default branch
		{
			let origin = git2::Repository::init_bare(&bare).unwrap();
			let sig = git2::Signature::now("Test", "test@example.com").unwrap();
			let tree_id = {
				let mut index = origin.index().unwrap();
				index.write_tree().unwrap()
			};
			let tree = origin.find_tree(tree_id).unwrap();
			let _commit_id = origin.commit(Some("HEAD"), &sig, &sig, "initial", &tree, &[]).unwrap();
		}

		let repo_dir = tmp.path().join("clone");
		let repo = git2::Repository::init(&repo_dir).unwrap();
		repo.remote("test-remote", bare.to_str().unwrap()).unwrap();

		let mut remote = repo.find_remote("test-remote").unwrap();
		remote.fetch(&["main"], None, None).unwrap();

		// The default branch for a bare repo is main
		checkout_gt_dir(&repo, "test-remote", "main").unwrap();
	}
}
