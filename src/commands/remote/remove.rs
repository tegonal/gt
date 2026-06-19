use clap::Args;

use crate::commands::common_args::{RemoteArg, WorkingDirectoryArg};

#[derive(Args)]
pub struct RemoteRemoveArgs {
	#[command(flatten)]
	pub remote: RemoteArg,

	/// (Optional) If defined, then all files defined in the remote's pulled.tsv are deleted as well
	#[arg(long, default_value_t = false)]
	pub delete_pulled_files: bool,

	#[command(flatten)]
	pub working_directory: WorkingDirectoryArg,
}

pub fn run(_args: RemoteRemoveArgs) {
	// TODO: Implement remote remove command
}
