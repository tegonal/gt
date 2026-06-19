use crate::utils;
use anyhow::{Context, bail};
use clap::Args;
use std::fs;
use std::ops::Not;

#[derive(Args)]
pub struct SelfUpdateArgs {
	/// (Optional) If Defined, then install.sh will be called even if gt is already on latest tag
	#[arg(long, default_value_t = false)]
	pub force: bool,
}

pub fn run(args: SelfUpdateArgs) {
	match run_internal(args) {
		Ok(()) => {}
		Err(err) => {
			eprintln!("{err:#}");
			std::process::exit(1);
		}
	}
}

fn run_internal(_args: SelfUpdateArgs) -> anyhow::Result<()> {
	let dir_of_gt = utils::dir_of_gt();
	let install_dir = fs::canonicalize(dir_of_gt.join(".."))
		.with_context(|| format!("Failed to resolve install_dir from {:?}", dir_of_gt))?;
	let install_sh = install_dir.join("install.sh");
	if install_sh.is_file().not() {
		bail!(
			"looks like the previous installation is corrupt, there is no install.sh in {}\n\
			Please re-install gt according to:\n\
			https://github.com/tegonal/gt#installation",
			install_dir.display()
		)
	}
	if install_dir.join(".git").is_dir() {}
	Ok(())
}
