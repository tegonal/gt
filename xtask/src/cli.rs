use crate::commands;
use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(name = "xtask", version = env!("CARGO_PKG_VERSION"))]
#[command(about = "Workspace automation tasks")]
pub struct Cli {
	#[command(subcommand)]
	pub command: Command,
}

#[derive(Subcommand)]
pub enum Command {
	// TODO remove again once we have an actual command
	#[command(about = "formats rust and toml files and tries to execute the automatic fixes")]
	Cleanup,
	TaploFormat,
}

pub fn run() {
	let cli = Cli::parse();
	match cli.command {
		Command::Cleanup => commands::cleanup::run(),
		Command::TaploFormat => commands::taplo::format(),
	}
}
