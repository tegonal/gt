use clap::{Parser, Subcommand};

use crate::remote::{RemoteAddArgs, RemoteListArgs, RemoteRemoveArgs};

#[derive(Parser)]
#[command(name = "gt-remote")]
#[command(about = "Utility to manage gt remotes")]
#[command(version)]
pub struct Cli {
    #[command(subcommand)]
    pub command: RemoteCommand,
}

impl Cli {
    pub fn run(&self) -> crate::error::Result<()> {
        match &self.command {
            RemoteCommand::Add(args) => args.run(),
            RemoteCommand::Remove(args) => args.run(),
            RemoteCommand::List(args) => args.run(),
        }
    }
}

#[derive(Subcommand)]
pub enum RemoteCommand {
    Add(RemoteAddArgs),
    Remove(RemoteRemoveArgs),
    List(RemoteListArgs),
}
