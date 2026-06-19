use clap::Args;

use crate::commands::common_args::WorkingDirectoryArg;

#[derive(Args)]
pub struct ResetArgs {
	/// (Optional) If set, only the remote with this name is reset, otherwise all are reset
	#[arg(short = 'r', long)]
	pub remote: Option<String>,

	/// (Optional) If defined, then only the gpg keys are reset but the files are not re-pulled
	#[arg(long, default_value_t = false)]
	pub only_gpg: bool,

	#[command(flatten)]
	pub working_directory: WorkingDirectoryArg,
}

pub fn run(_args: ResetArgs) {
	// TODO: Implement reset command
}
