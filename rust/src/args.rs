//! Argument and command parsing, mirroring `utility/parse-args.sh` and
//! `utility/parse-commands.sh`.
//!
//! These provide the same behaviour the Bash tool relies on: `--help` prints a
//! parameter/command listing and returns exit code 99, `--version` prints the
//! version and returns 99, unknown arguments/commands fail with a helpful error.

use std::collections::HashMap;

use crate::ask::ask_yes_or_no;
use crate::constants::{COLOR_CYAN, COLOR_RESET, GT_VERSION};
use crate::error::Exit;
use crate::log::{log_error, log_info, log_warning};

const BOLD_YELLOW: &str = "\x1b[1;33m";
const BOLD_CYAN: &str = "\x1b[1;36m";

/// A single named parameter definition (variable name, accepted patterns, help).
pub struct Param {
    pub name: &'static str,
    pub patterns: &'static [&'static str],
    pub help: String,
}

impl Param {
    pub fn new(name: &'static str, patterns: &'static [&'static str], help: impl Into<String>) -> Self {
        Param {
            name,
            patterns,
            help: help.into(),
        }
    }

    /// The pattern as shown in help output, e.g. `-r|--remote`.
    fn display_pattern(&self) -> String {
        self.patterns.join("|")
    }

    fn matches(&self, arg: &str) -> bool {
        self.patterns.contains(&arg)
    }
}

/// Prints `INFO: Version of gt is:\n<version>` (mirrors `printVersion`).
pub fn print_version(version: &str) {
    log_info(&format!("Version of gt is:\n{version}"));
}

/// Parses the given `args` against the `params` definitions.
///
/// Returns a map from parameter name to the provided value. `--help`/`--version`
/// short-circuit with `Err(Exit(99))` after printing. Mirrors `parseArguments`.
pub fn parse_arguments(
    params: &[Param],
    examples: &str,
    version: &str,
    args: &[String],
) -> Result<HashMap<String, String>, Exit> {
    parse_arguments_inner(params, examples, version, args, false)
}

/// Like [`parse_arguments`], but ignores unknown arguments rather than
/// returning an error. Used by the two-pass `gt pull` parser (first pass).
pub fn parse_arguments_lenient(
    params: &[Param],
    examples: &str,
    version: &str,
    args: &[String],
) -> Result<HashMap<String, String>, Exit> {
    parse_arguments_inner(params, examples, version, args, true)
}

fn parse_arguments_inner(
    params: &[Param],
    examples: &str,
    version: &str,
    args: &[String],
    ignore_unknown: bool,
) -> Result<HashMap<String, String>, Exit> {
    let mut values: HashMap<String, String> = HashMap::new();
    let mut num_parsed = 0usize;

    let mut i = 0;
    while i < args.len() {
        let arg = &args[i];
        if arg == "--help" {
            print_help(params, examples, version);
            if num_parsed != 0 {
                log_warning(
                    "there were arguments defined prior to --help, they were all ignored and instead the help is shown",
                );
            } else if args.len() - i > 1 {
                log_warning(
                    "there were arguments defined after --help, they will all be ignored, you might want to remove --help",
                );
            }
            return Err(Exit(99));
        }
        if arg == "--version" {
            if num_parsed != 0 {
                log_warning(
                    "there were arguments defined prior to --version, they will all be ignored and instead printVersion will be called",
                );
            }
            print_version(version);
            return Err(Exit(99));
        }

        let mut matched = false;
        for param in params {
            if param.matches(arg) {
                if i + 1 >= args.len() {
                    log_error(&format!(
                        "no value defined for parameter {BOLD_CYAN}{}{COLOR_RESET} (pattern {})",
                        param.name,
                        param.display_pattern()
                    ));
                    ask_print_help(params, examples, version);
                    return Err(Exit(9));
                }
                values.insert(param.name.to_string(), args[i + 1].clone());
                matched = true;
                num_parsed += 1;
                i += 1; // consume the value
                break;
            }
        }

        if !matched {
            if ignore_unknown {
                if arg.starts_with('-') && i + 1 < args.len() {
                    i += 1; // skip the value too
                }
            } else {
                if arg.starts_with('-') && i + 1 < args.len() {
                    log_error(&format!(
                        "unknown argument {BOLD_CYAN}{arg}{COLOR_RESET} (and value {})",
                        args[i + 1]
                    ));
                } else {
                    log_error(&format!("unknown argument {BOLD_CYAN}{arg}{COLOR_RESET}"));
                }
                ask_print_help(params, examples, version);
                return Err(Exit(9));
            }
        }
        i += 1;
    }

    Ok(values)
}

fn ask_print_help(params: &[Param], examples: &str, version: &str) {
    if ask_yes_or_no("Shall I print the help for you?") {
        print_help(params, examples, version);
    }
}

/// Verifies that every parameter in `required` is present in `values`.
///
/// On any missing parameter it logs an error per missing one, prints the help
/// and returns `Err(Exit(1))`. Mirrors `exitIfNotAllArgumentsSet`.
pub fn exit_if_not_all_arguments_set(
    params: &[Param],
    values: &HashMap<String, String>,
    examples: &str,
    version: &str,
) -> Result<(), Exit> {
    let mut good = true;
    for param in params {
        if !values.contains_key(param.name) {
            log_error(&format!("{} not set via {}", param.name, param.display_pattern()));
            good = false;
        }
    }
    if !good {
        eprintln!();
        eprintln!("following the help documentation:");
        eprintln!();
        print_help(params, examples, version);
        return Err(Exit(1));
    }
    Ok(())
}

/// Prints the parameter help listing (mirrors `parse_args_printHelp`).
pub fn print_help(params: &[Param], examples: &str, version: &str) {
    let max_length = params.iter().map(|p| p.display_pattern().len()).max().unwrap_or(0) + 2;

    println!("{BOLD_YELLOW}Parameters:{COLOR_RESET}");
    for param in params {
        let pattern = param.display_pattern();
        if param.help.is_empty() {
            println!("{pattern}");
        } else {
            println!("{pattern:<max_length$} {}", param.help);
        }
    }
    println!();
    println!("--help     prints this help");
    println!("--version  prints the version of this script");

    if !examples.is_empty() {
        println!();
        println!("{BOLD_YELLOW}Examples:{COLOR_RESET}");
        println!("{examples}");
    }
    println!();
    print_version(version);
}

/// A command definition: name plus a (possibly empty) help text.
pub struct Command {
    pub name: &'static str,
    pub help: &'static str,
}

/// Outcome of [`parse_command`]: which command was selected (and the remaining
/// args) or that help/version was handled.
pub enum CommandSelection<'a> {
    Selected { name: &'static str, rest: &'a [String] },
    Handled,
}

/// Parses the leading command token of `args` against `commands`.
///
/// Mirrors `parseCommands`: prints help with no command (exit 9), dispatches a
/// known command, handles `--help`/`--version`, errors on unknown (exit 1).
pub fn parse_command<'a>(
    commands: &[Command],
    version: &str,
    caller: &str,
    args: &'a [String],
) -> Result<CommandSelection<'a>, Exit> {
    let Some(first) = args.first() else {
        log_error(&format!(
            "no command passed to {caller}, following the output of --help\n"
        ));
        print_commands_help(commands, version);
        return Err(Exit(9));
    };

    if let Some(cmd) = commands.iter().find(|c| c.name == first) {
        return Ok(CommandSelection::Selected {
            name: cmd.name,
            rest: &args[1..],
        });
    }
    match first.as_str() {
        "--help" => {
            print_commands_help(commands, version);
            Ok(CommandSelection::Handled)
        }
        "--version" => {
            print_version(version);
            Ok(CommandSelection::Handled)
        }
        other => {
            log_error(&format!(
                "unknown command {COLOR_CYAN}{other}{COLOR_RESET}, following the output of --help\n"
            ));
            print_commands_help(commands, version);
            Err(Exit(1))
        }
    }
}

/// Prints the command help listing (mirrors `parse_commands_printHelp`).
pub fn print_commands_help(commands: &[Command], version: &str) {
    let max_length = commands.iter().map(|c| c.name.len()).max().unwrap_or(0) + 2;

    println!("{BOLD_YELLOW}Commands:{COLOR_RESET}");
    for cmd in commands {
        if cmd.help.is_empty() {
            println!("{}", cmd.name);
        } else {
            println!("{:<max_length$} {}", cmd.name, cmd.help);
        }
    }
    println!();
    println!("--help     prints this help");
    println!("--version  prints the version of this script");
    println!();
    print_version(version);
}

/// Convenience helper returning a `cyan`-highlighted string like the Bash code's
/// `\033[0;36m%s\033[0m`.
pub fn cyan(s: &str) -> String {
    format!("{COLOR_CYAN}{s}{COLOR_RESET}")
}

/// The default tool version constant, re-exported for convenience.
pub fn default_version() -> &'static str {
    GT_VERSION
}
