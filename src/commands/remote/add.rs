use clap::Args;

#[derive(Args)]
pub struct RemoteAddArgs {
	/// Name identifying this remote
	#[arg(short = 'r', long)]
	pub remote: String,

	/// URL of the remote repository
	#[arg(short = 'u', long)]
	pub url: String,

	/// Directory into which files are pulled -- default: lib/<remote>
	#[arg(short = 'd', long)]
	pub directory: Option<String>,

	/// Define a regexp pattern to filter available tags when determining the latest tag
	#[arg(long)]
	pub tag_filter: Option<String>,

	/// If set, the remote does not need to have GPG key(s) defined
	#[arg(long)]
	pub unsecure: bool,

	/// Path which gt shall use as working directory -- default: .gt
	#[arg(short = 'w', long)]
	pub working_directory: Option<String>,
}

pub fn run(_args: RemoteAddArgs) {
	// TODO: Implement remote add command
}
