mod args;
mod config;
mod error;
mod git;
mod gpg;
mod paths;
mod remote;

use args::Cli;
use clap::Parser;
use error::Result;

fn main() -> Result<()> {
    let cli = Cli::parse();
    cli.run()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::config::validate_remote_name;
    use crate::paths::RemotePaths;
    use tempfile::TempDir;

    #[test]
    fn test_validate_remote_name_valid() {
        assert!(validate_remote_name("my-remote").is_ok());
        assert!(validate_remote_name("my_remote").is_ok());
        assert!(validate_remote_name("remote123").is_ok());
        assert!(validate_remote_name("a").is_ok());
        assert!(validate_remote_name("MY-REMOTE_123").is_ok());
    }

    #[test]
    fn test_validate_remote_name_invalid() {
        assert!(validate_remote_name("my remote").is_err());
        assert!(validate_remote_name("my.remote").is_err());
        assert!(validate_remote_name("my/remote").is_err());
        assert!(validate_remote_name("my@remote").is_err());
        assert!(validate_remote_name("").is_err());
    }

    #[test]
    fn test_remote_paths_creation() {
        let temp_dir = TempDir::new().unwrap();
        let working_dir = temp_dir.path().join(".gt");
        std::fs::create_dir_all(&working_dir).unwrap();

        let paths = RemotePaths::new(&working_dir, "test-remote");

        assert_eq!(
            paths.remote_dir,
            working_dir.join("remotes").join("test-remote")
        );
        assert_eq!(
            paths.repo_dir,
            working_dir.join("remotes").join("test-remote").join("repo")
        );
        assert_eq!(
            paths.public_keys_dir,
            working_dir
                .join("remotes")
                .join("test-remote")
                .join("public-keys")
        );
        assert_eq!(
            paths.gpg_dir,
            working_dir
                .join("remotes")
                .join("test-remote")
                .join("public-keys")
                .join("gpg")
        );
        assert_eq!(
            paths.pulled_tsv,
            working_dir
                .join("remotes")
                .join("test-remote")
                .join("pulled.tsv")
        );
        assert_eq!(
            paths.pull_args,
            working_dir
                .join("remotes")
                .join("test-remote")
                .join("pull.args")
        );
    }

    #[test]
    fn test_cli_parsing_add() {
        let cli = Cli::parse_from([
            "gt-remote",
            "add",
            "-r",
            "test-remote",
            "-u",
            "https://github.com/test/repo",
        ]);

        match cli.command {
            crate::args::RemoteCommand::Add(args) => {
                assert_eq!(args.remote, "test-remote");
                assert_eq!(args.url, "https://github.com/test/repo");
                assert!(args.directory.is_none());
                assert!(args.tag_filter.is_none());
                assert!(args.unsecure.is_none());
                assert!(args.working_directory.is_none());
            }
            _ => panic!("Expected Add command"),
        }
    }

    #[test]
    fn test_cli_parsing_add_with_all_options() {
        let cli = Cli::parse_from([
            "gt-remote",
            "add",
            "-r",
            "test-remote",
            "-u",
            "https://github.com/test/repo",
            "-d",
            "my/dir",
            "--tag-filter",
            "^v[0-9]+",
            "--unsecure",
            "true",
            "-w",
            ".github/.gt",
        ]);

        match cli.command {
            crate::args::RemoteCommand::Add(args) => {
                assert_eq!(args.remote, "test-remote");
                assert_eq!(args.url, "https://github.com/test/repo");
                assert_eq!(args.directory, Some("my/dir".to_string()));
                assert_eq!(args.tag_filter, Some("^v[0-9]+".to_string()));
                assert_eq!(args.unsecure, Some(true));
                assert_eq!(args.working_directory, Some(".github/.gt".to_string()));
            }
            _ => panic!("Expected Add command"),
        }
    }

    #[test]
    fn test_cli_parsing_remove() {
        let cli = Cli::parse_from([
            "gt-remote",
            "remove",
            "-r",
            "test-remote",
            "--delete-pulled-files",
            "true",
        ]);

        match cli.command {
            crate::args::RemoteCommand::Remove(args) => {
                assert_eq!(args.remote, "test-remote");
                assert_eq!(args.delete_pulled_files, Some(true));
                assert!(args.working_directory.is_none());
            }
            _ => panic!("Expected Remove command"),
        }
    }

    #[test]
    fn test_cli_parsing_list() {
        let cli = Cli::parse_from(["gt-remote", "list", "-w", ".github/.gt"]);

        match cli.command {
            crate::args::RemoteCommand::List(args) => {
                assert_eq!(args.working_directory, Some(".github/.gt".to_string()));
            }
            _ => panic!("Expected List command"),
        }
    }

    #[test]
    fn test_cli_help() {
        let result = Cli::try_parse_from(["gt-remote", "--help"]);
        assert!(result.is_err());
    }
}
