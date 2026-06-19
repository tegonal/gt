use clap::Args;

use crate::commands::common_args::{PullCommonArgs, RemoteArg, TagFilterArg};

#[derive(Args)]
pub struct PullArgs {
	#[command(flatten)]
	pub remote: RemoteArg,

	/// Git tag used to pull the file/directory
	#[arg(short = 't', long)]
	pub tag: String,

	//TODO 2.0.0 I think path should not be an option but an argument
	/// Path in remote repository which shall be pulled (file or directory)
	#[arg(short = 'p', long)]
	pub path: String,

	/// (Optional) Directory into which files are pulled [default: pull directory of this remote (defined during "remote add" and stored in <WORKING_DIRECTORY>/<REMOTE>/pull.args)]
	#[arg(short = 'd', long)]
	pub directory: Option<String>,

	/// (Optional) If defined, then files are put into the pull directory without the path specified. For files this means they are put directly into the pull directory
	#[arg(long)]
	pub chop_path: bool,

	/// (Optional) If you want to use a different file name then the one specified in the remote [default: name as specified in the remote]
	#[arg(long)]
	pub target_file_name: Option<String>,

	/// (Optional) If defined, the remote does not need to have GPG key(s) defined in gpg database or at <WORKING_DIRECTORY>/remotes/<REMOTE>/*.asc
	#[arg(long, default_value_t = false)]
	pub unsecure: bool,

	/// (Optional) If defined, implies --unsecure and does not verify even if gpg keys are in store or at <WORKING_DIRECTORY>/remotes/<REMOTE>/*.asc
	#[arg(long)]
	pub unsecure_no_verification: bool,

	/// Define a regexp pattern to filter available tags when determining the latest tag
	#[command(flatten)]
	pub tag_filter: TagFilterArg,

	#[command(flatten)]
	pub pull_common: PullCommonArgs,
}

pub fn run(_args: PullArgs) {
	// TODO: Implement pull command
}
