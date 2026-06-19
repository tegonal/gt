pub mod add;
pub mod list;
pub mod remove;

use clap::Subcommand;

#[derive(Subcommand)]
pub enum RemoteCommands {
	/// Add a remote
	Add(add::RemoteAddArgs),
	/// Remove a remote
	Remove(remove::RemoteRemoveArgs),
	/// List all remotes
	List(list::RemoteListArgs),
}

pub fn run(cmd: RemoteCommands) {
	match cmd {
		RemoteCommands::Add(args) => add::run(args),
		RemoteCommands::Remove(args) => remove::run(args),
		RemoteCommands::List(args) => list::run(args),
	}
}
