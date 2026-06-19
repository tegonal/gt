use clap::Args;

use crate::commands::common_args::PullCommonArgs;

#[derive(Args)]
pub struct UpdateArgs {
	/// (Optional) If set, only the files of this remote are updated, otherwise all
	#[arg(short = 'r', long)]
	pub remote: Option<String>,

	/// (Optional) define from which tag files shall be pulled, only valid if <REMOTE> is specified
	#[arg(short = 't', long)]
	pub tag: Option<String>,

	/// (Optional) If defined, then no files are updated and instead a list with updatable files including versions is output
	#[arg(long, default_value_t = false)]
	pub list: bool,

	#[command(flatten)]
	pub pull_common: PullCommonArgs,
}

pub fn run(_args: UpdateArgs) {
	// TODO: Implement update command
}
