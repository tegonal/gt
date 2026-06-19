use clap::Args;

#[derive(Args)]
pub struct SelfUpdateArgs {
	/// (Optional) If Defined, then install.sh will be called even if gt is already on latest tag
	#[arg(long, default_value_t = false)]
	pub force: bool,
}

pub fn run(_args: SelfUpdateArgs) {
	// TODO: Implement self-update command
}
