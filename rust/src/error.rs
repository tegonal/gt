//! Control-flow / error type used throughout the `gt` implementation.
//!
//! The original Bash code mixes `exit N` (terminate the process) and `return N`
//! (bubble up through the call chain). Because everything runs in a single
//! process, both ultimately determine the process exit code. We model this with
//! a single [`Exit`] type carrying the desired exit code; any user-facing
//! message is expected to have been printed already (mirroring how the Bash
//! `logError`/`die` helpers print before exiting).

use std::fmt;

/// Represents a requested process termination with a specific exit code.
///
/// By the time an `Exit` is produced, the relevant message has already been
/// written to stdout/stderr, exactly like `die`/`logError` + `exit` in Bash.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Exit(pub i32);

impl Exit {
    /// The exit code carried by this value.
    pub fn code(self) -> i32 {
        self.0
    }
}

impl fmt::Display for Exit {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "exit({})", self.0)
    }
}

impl std::error::Error for Exit {}

/// Result alias used by command functions.
pub type GtResult = Result<(), Exit>;

/// Logs the formatted message as an error and returns `Err(Exit(1))`.
///
/// Mirrors the Bash `die`/`returnDying` helpers.
#[macro_export]
macro_rules! die {
    ($($arg:tt)*) => {{
        $crate::log::log_error(&format!($($arg)*));
        return Err($crate::error::Exit(1));
    }};
}

/// Logs the formatted message as an error and returns `Err(Exit($code))`.
#[macro_export]
macro_rules! exit_with {
    ($code:expr, $($arg:tt)*) => {{
        $crate::log::log_error(&format!($($arg)*));
        return Err($crate::error::Exit($code));
    }};
}
