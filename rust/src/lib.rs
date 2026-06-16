//! Rust re-implementation of the `gt` tool.
//!
//! This crate currently implements the `remote` command (`add`/`list`/`remove`),
//! translated from the original Bash sources in `src/`. The module layout mirrors
//! the Bash helper files so that the remaining commands can be ported
//! incrementally:
//!
//! - [`log`] / [`ask`] — user-facing output and prompts (`utility/log.sh`, `ask.sh`)
//! - [`args`] — argument & command parsing (`utility/parse-args.sh`, `parse-commands.sh`)
//! - [`constants`] / [`paths`] — shared constants and path layout
//! - [`git`] / [`gpg`] — thin wrappers over the `git`/`gpg` CLIs
//! - [`util`] / [`pulled`] — filesystem helpers and `pulled.tsv` handling
//! - [`commands`] — the actual commands

pub mod args;
pub mod ask;
pub mod commands;
pub mod constants;
pub mod error;
pub mod git;
pub mod gpg;
pub mod log;
pub mod paths;
pub mod pulled;
pub mod util;

use args::{parse_command, print_version, Command, CommandSelection};
use constants::GT_VERSION;
use error::{Exit, GtResult};
use log::log_error;

/// Top-level dispatch for the `gt` tool. Mirrors `src/gt.sh`.
///
/// Only `remote` is implemented; the remaining commands are listed (so `--help`
/// and the overall UX match the original) but currently report that they have
/// not been ported yet.
pub fn run(args: &[String]) -> GtResult {
    let commands = [
        Command {
            name: "pull",
            help: "pull files from a previously defined remote",
        },
        Command {
            name: "re-pull",
            help: "re-pull files defined in pulled.tsv of a specific or all remotes",
        },
        Command {
            name: "remote",
            help: "manage remotes",
        },
        Command {
            name: "reset",
            help: "reset one or all remotes (re-establish gpg and re-pull files)",
        },
        Command {
            name: "update",
            help: "update pulled files to latest or particular version",
        },
        Command {
            name: "self-update",
            help: "update gt to the latest version",
        },
    ];

    match parse_command(&commands, GT_VERSION, "gt.sh", args)? {
        CommandSelection::Selected { name, rest } => match name {
            "remote" => commands::remote::run(rest),
            "self-update" => commands::self_update::run(rest),
            other => not_yet_implemented(other),
        },
        CommandSelection::Handled => Ok(()),
    }
}

fn not_yet_implemented(command: &str) -> GtResult {
    log_error(&format!(
        "the command '{command}' has not been ported to the Rust implementation yet (only 'remote' and 'self-update' are available so far)"
    ));
    Err(Exit(1))
}

/// Re-export so binaries can print the version directly if needed.
pub fn print_tool_version() {
    print_version(GT_VERSION);
}
