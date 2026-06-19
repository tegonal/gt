use clap::Args;
use std::path::PathBuf;

#[derive(Args)]
pub struct PullArgs {
	/// Name of the remote repository
	#[arg(short = 'r', long)]
	pub remote: String,

	/// Git tag used to pull the file/directory
	#[arg(short = 't', long)]
	pub tag: String,

	/// Path in remote repository which shall be pulled (file or directory)
	#[arg(short = 'p', long)]
	pub path: String,

	/// Directory into which files are pulled -- default: pull directory of this remote
	#[arg(short = 'd', long)]
	pub directory: Option<String>,

	/// If set, files are put into the pull directory without the path specified
	#[arg(long)]
	pub chop_path: bool,

	/// If you want to use a different file name then the one specified in the remote
	#[arg(long)]
	pub target_file_name: Option<String>,

	/// Define a regexp pattern to filter available tags when determining the latest tag
	#[arg(long)]
	pub tag_filter: Option<String>,

	/// If set and GPG is not set up yet, then all keys are imported without manual consent
	#[arg(long)]
	pub auto_trust: bool,

	/// If set, the remote does not need to have GPG key(s) defined
	#[arg(long)]
	pub unsecure: bool,

	/// If set, implies --unsecure and does not verify even if gpg keys are in store
	#[arg(long)]
	pub unsecure_no_verification: bool,

	/// Path which gt shall use as working directory -- default: .gt
	#[arg(short = 'w', long)]
	pub working_directory: Option<PathBuf>,
}

pub fn run(_args: PullArgs) {
	// TODO: Implement pull command
}
