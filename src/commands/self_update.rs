use clap::Args;

#[derive(Args)]
pub struct SelfUpdateArgs {
	/// If set, then install.sh will be called even if gt is already on latest tag
	#[arg(long)]
	pub force: bool,
}

pub fn run(_args: SelfUpdateArgs) {
	// TODO: Implement self-update command
}
