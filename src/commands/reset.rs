use clap::Args;
use std::path::PathBuf;

#[derive(Args)]
pub struct ResetArgs {
	/// If set, only the remote with this name is reset, otherwise all are reset
	#[arg(short = 'r', long)]
	pub remote: Option<String>,

	/// If set, then only the gpg keys are reset but the files are not re-pulled
	#[arg(long)]
	pub gpg_only: bool,

	/// Path which gt shall use as working directory -- default: .gt
	#[arg(short = 'w', long)]
	pub working_directory: Option<PathBuf>,
}

pub fn run(_args: ResetArgs) {
	// TODO: Implement reset command
}
