use clap::Args;
use std::path::PathBuf;

#[derive(Args)]
pub struct UpdateArgs {
	/// If set, only the files of this remote are updated, otherwise all
	#[arg(short = 'r', long)]
	pub remote: Option<String>,

	/// Define from which tag files shall be pulled, only valid if remote via -r is specified
	#[arg(short = 't', long)]
	pub tag: Option<String>,

	/// If set, then no files are updated and instead a list with updatable files is output
	#[arg(long)]
	pub list: bool,

	/// If set and GPG is not set up yet, then all keys are imported without manual consent
	#[arg(long)]
	pub auto_trust: bool,

	/// Path which gt shall use as working directory -- default: .gt
	#[arg(short = 'w', long)]
	pub working_directory: Option<PathBuf>,
}

pub fn run(_args: UpdateArgs) {
	// TODO: Implement update command
}
