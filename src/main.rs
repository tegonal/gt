use clap::Parser;

mod commands;

#[derive(Parser)]
#[command(name = "gt")]
#[command(about, version,author, disable_help_subcommand = true)]
struct Cli {
	#[command(subcommand)]
	command: commands::Commands,
}

fn main() {
	let cli = Cli::parse();
	commands::run(cli.command);
}
