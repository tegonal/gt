pub mod pull;
pub mod repull;
pub mod reset;
pub mod self_update;
pub mod update;

pub mod remote;

use clap::Subcommand;

#[derive(Subcommand)]
pub enum Commands {
	/// Pull files from a previously defined remote
	Pull(pull::PullArgs),
	/// Re-pull files defined in pulled.tsv of a specific or all remotes
	RePull(repull::RePullArgs),
	/// Manage remotes
	#[command(subcommand)]
	Remote(remote::RemoteCommands),
	/// Reset one or all remotes (re-establish gpg and re-pull files)
	Reset(reset::ResetArgs),
	/// Update pulled files to latest or particular version
	Update(update::UpdateArgs),
	/// Update gt to the latest version
	SelfUpdate(self_update::SelfUpdateArgs),
}

pub fn run(command: Commands) {
	match command {
		Commands::Pull(args) => pull::run(args),
		Commands::RePull(args) => repull::run(args),
		Commands::Remote(cmd) => remote::run(cmd),
		Commands::Reset(args) => reset::run(args),
		Commands::Update(args) => update::run(args),
		Commands::SelfUpdate(args) => self_update::run(args),
	}
}
