use clap::Args;
use std::path::PathBuf;

#[derive(Args)]
pub struct RemoteRemoveArgs {
	/// Define the name of the remote which shall be removed
	#[arg(short = 'r', long)]
	pub remote: String,

	/// If set, then all files defined in the remote's pulled.tsv are deleted as well
	#[arg(long)]
	pub delete_pulled_files: bool,

	/// Path which gt shall use as working directory -- default: .gt
	#[arg(short = 'w', long)]
	pub working_directory: Option<PathBuf>,
}

pub fn run(_args: RemoteRemoveArgs) {
	// TODO: Implement remote remove command
}
