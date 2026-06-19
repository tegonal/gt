use clap::Args;

use crate::commands::common_args::WorkingDirectoryArg;

#[derive(Args)]
pub struct RemoteListArgs {
	#[command(flatten)]
	pub working_directory: WorkingDirectoryArg,
}

pub fn run(_args: RemoteListArgs) {
	// TODO: Implement remote list command
}
