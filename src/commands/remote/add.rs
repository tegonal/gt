use clap::Args;

use crate::commands::common_args::{RemoteArg, WorkingDirectoryArg};

#[derive(Args)]
pub struct RemoteAddArgs {
	#[command(flatten)]
	pub remote: RemoteArg,

	/// URL of the remote repository
	#[arg(short = 'u', long)]
	pub url: String,

	/// (Optional) Directory into which files are pulled [default: lib/<REMOTE>]
	#[arg(short = 'd', long)]
	pub directory: Option<String>,

	/// (Optional) If set, the remote does not need to have a .gt/signing-key.public.asc defined
	#[arg(long, default_value_t = false)]
	pub unsecure: bool,

	#[command(flatten)]
	pub working_directory: WorkingDirectoryArg,
}

pub fn run(_args: RemoteAddArgs) {
	// TODO: Implement remote add command
}
