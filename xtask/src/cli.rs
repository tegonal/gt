use clap::{Parser, Subcommand};

use crate::commands;

#[derive(Parser)]
#[command(name = "xtask", version = env!("CARGO_PKG_VERSION"))]
#[command(about = "Workspace automation tasks")]
pub struct Cli {
    #[command(subcommand)]
    pub command: Command,
}

#[derive(Subcommand)]
pub enum Command {
    Coverage {
        #[arg(long)]
        force: bool,

		/// everything after known args
		#[arg(last = true)]
		args: Vec<String>,
    },
    ClearCache,
}

pub fn run() {
    let cli = Cli::parse();

    match cli.command {
        Command::Coverage { force, args } => {
            commands::coverage::run(force, &args);
        }
        Command::ClearCache => {
            commands::clear_cache::run();
        }
    }
}
