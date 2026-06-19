use clap::Args;
use std::path::PathBuf;

#[derive(Args)]
pub struct RemoteListArgs {
	/// Path which gt shall use as working directory -- default: .gt
	#[arg(short = 'w', long)]
	pub working_directory: Option<PathBuf>,
}

pub fn run(_args: RemoteListArgs) {
	// TODO: Implement remote list command
}
