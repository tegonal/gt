//! Logging helpers mirroring `lib/.../utility/log.sh`.
//!
//! `logInfo`, `logWarning` and `logSuccess` write to stdout, `logError` writes
//! to stderr -- each prefixed with a coloured level marker. Callers pass an
//! already-formatted message (use `format!`), which may itself embed ANSI colour
//! codes (e.g. [`crate::constants::COLOR_CYAN`]).

use std::io::Write;

const INFO_PREFIX: &str = "\x1b[0;34mINFO\x1b[0m: ";
const WARNING_PREFIX: &str = "\x1b[0;93mWARNING\x1b[0m: ";
const ERROR_PREFIX: &str = "\x1b[0;31mERROR\x1b[0m: ";
const SUCCESS_PREFIX: &str = "\x1b[0;32mSUCCESS\x1b[0m: ";

/// `logInfo` -- writes an info message (with trailing newline) to stdout.
pub fn log_info(msg: &str) {
    println!("{INFO_PREFIX}{msg}");
}

/// `logWarning` -- writes a warning message (with trailing newline) to stdout.
pub fn log_warning(msg: &str) {
    println!("{WARNING_PREFIX}{msg}");
}

/// `logError` -- writes an error message (with trailing newline) to stderr.
pub fn log_error(msg: &str) {
    let mut stderr = std::io::stderr();
    let _ = writeln!(stderr, "{ERROR_PREFIX}{msg}");
}

/// `logSuccess` -- writes a success message (with trailing newline) to stdout.
pub fn log_success(msg: &str) {
    println!("{SUCCESS_PREFIX}{msg}");
}
