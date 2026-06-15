mod commands;
mod config;
mod error;
mod git;
mod gpg;

use clap::{Parser, Subcommand};
use error::Result;

/// gt remote - manage git remotes for the gt (g(it)t(ools)) tool
#[derive(Parser, Debug)]
#[command(author, version = "v1.7.0-SNAPSHOT", about, long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,

    /// Path which gt shall use as working directory
    #[arg(
        short = 'w',
        long = "working-directory",
        global = true,
        default_value = ".gt"
    )]
    working_directory: String,
}

#[derive(Subcommand, Debug)]
enum Commands {
    /// Add a remote
    Add {
        /// Name identifying this remote
        #[arg(short = 'r', long = "remote")]
        remote: String,

        /// URL of the remote repository
        #[arg(short = 'u', long = "url")]
        url: String,

        /// Directory into which files are pulled
        #[arg(short = 'd', long = "directory")]
        pull_dir: Option<String>,

        /// Regexp pattern to filter available tags
        #[arg(long = "tag-filter")]
        tag_filter: Option<String>,

        /// If true, the remote does not need to have GPG key(s) defined
        #[arg(long = "unsecure", value_parser = clap::value_parser!(bool), default_value = "false")]
        unsecure: bool,
    },

    /// Remove a remote
    Remove {
        /// Name of the remote to remove
        #[arg(short = 'r', long = "remote")]
        remote: String,

        /// If true, delete all files defined in the remote's pulled.tsv
        #[arg(long = "delete-pulled-files", default_value = "false")]
        delete_pulled_files: bool,
    },

    /// List all remotes
    List,
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Add {
            remote,
            url,
            pull_dir,
            tag_filter,
            unsecure,
        } => {
            let pull_dir = pull_dir.unwrap_or_else(|| format!("lib/{}", remote));
            let tag_filter = tag_filter.unwrap_or_else(|| ".*".to_string());
            commands::add::execute(
                &cli.working_directory,
                &remote,
                &url,
                &pull_dir,
                &tag_filter,
                unsecure,
            )
        }
        Commands::Remove {
            remote,
            delete_pulled_files,
        } => commands::remove::execute(&cli.working_directory, &remote, delete_pulled_files),
        Commands::List => commands::list::execute(&cli.working_directory),
    }
}

#[cfg(test)]
mod tests {
    #[test]
    fn test_main_compiles() {
        assert!(true);
    }
}
