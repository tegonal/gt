use clap::Args;
use std::path::PathBuf;

#[derive(Args)]
pub struct RemoteArg {
	/// Name identifying this remote
	#[arg(short = 'r', long)]
	pub remote: String,
}

#[derive(Args)]
pub struct TagFilterArg {
	/// (Optional) Define a regexp pattern to filter available tags when determining the latest tag
	#[arg(long)]
	pub tag_filter: Option<String>,
}

#[derive(Args)]
pub struct WorkingDirectoryArg {
	/// (Optional) Path which gt shall use as working directory
	#[arg(short = 'w', long, default_value = ".gt")]
	pub working_directory: PathBuf,
}

#[derive(Args)]
pub struct PullCommonArgs {
	/// (Optional) If defined and GPG is not set up yet, then all keys in <WORKING_DIRECTORY>/remotes/<REMOTE>/public-keys/*.asc are imported without manual consent
	#[arg(long, default_value_t = false)]
	pub auto_trust: bool,

	#[command(flatten)]
	pub working_directory: WorkingDirectoryArg,
}
