use clap::Args;
use std::path::PathBuf;

#[derive(Args)]
pub struct RePullArgs {
	/// If set, only the remote with this name is re-pulled, otherwise all are re-pulled
	#[arg(short = 'r', long)]
	pub remote: Option<String>,

	/// If set, then only files which do not exist locally are pulled
	#[arg(long, default_value_t = true)]
	pub only_missing: bool,

	/// If set and GPG is not set up yet, then all keys are imported without manual consent
	#[arg(long)]
	pub auto_trust: bool,

	/// Path which gt shall use as working directory -- default: .gt
	#[arg(short = 'w', long)]
	pub working_directory: Option<PathBuf>,
}

pub fn run(_args: RePullArgs) {
	// TODO: Implement re-pull command
}
