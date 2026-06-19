use clap::Args;

use crate::commands::common_args::PullCommonArgs;

#[derive(Args)]
pub struct RePullArgs {
	/// (Optional) If set, only files from the remote with this name is re-pulled, otherwise all are re-pulled
	#[arg(short = 'r', long)]
	pub remote: Option<String>,

	/// (Optional) f defined, then only files which do not exist locally are pulled
	#[arg(long, default_value_t = true)]
	pub only_missing: bool,

	#[command(flatten)]
	pub pull_common: PullCommonArgs,
}

pub fn run(_args: RePullArgs) {
	// TODO: Implement re-pull command
}
