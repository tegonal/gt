//! Interactive yes/no prompt mirroring `askYesOrNo` from `utility/ask.sh`.
//!
//! The original waits up to 20 seconds for an answer and interprets a missing
//! answer (timeout) as "no". `y`/`Y`/`yes` means yes, `n`/`N`/`no` means no, and
//! anything else is treated as a (warned) "no".

use std::io::{BufRead, Write};
use std::sync::mpsc;
use std::thread;
use std::time::Duration;

use crate::log::{log_info, log_warning};

const TIMEOUT_SECONDS: u64 = 20;

/// Asks the given yes/no `question`. Returns `true` for yes, `false` otherwise.
///
/// The prompt is written to stderr so it never pollutes machine-readable stdout
/// (the original frequently redirects the prompt with `>&2`).
pub fn ask_yes_or_no(question: &str) -> bool {
    eprint!(
        "\n{}{question}{} y/[n]: ",
        crate::constants::COLOR_CYAN,
        crate::constants::COLOR_RESET
    );
    let _ = std::io::stderr().flush();

    match read_line_with_timeout(Duration::from_secs(TIMEOUT_SECONDS)) {
        ReadOutcome::Line(answer) => interpret(answer.trim()),
        ReadOutcome::Timeout => {
            eprintln!();
            log_info(&format!(
                "no user interaction after {TIMEOUT_SECONDS} seconds, going to interpret that as a 'no'."
            ));
            false
        }
        // EOF (e.g. non-interactive invocation): behave conservatively as "no".
        ReadOutcome::Eof => false,
    }
}

fn interpret(answer: &str) -> bool {
    match answer {
        "y" | "Y" | "yes" => true,
        "n" | "N" | "no" => false,
        other => {
            log_warning(&format!(
                "got {}{other}{} as answer (instead of y/yes or n/no), interpreting it as a no",
                crate::constants::COLOR_CYAN,
                crate::constants::COLOR_RESET
            ));
            false
        }
    }
}

enum ReadOutcome {
    Line(String),
    Timeout,
    Eof,
}

fn read_line_with_timeout(timeout: Duration) -> ReadOutcome {
    let (tx, rx) = mpsc::channel();
    thread::spawn(move || {
        let mut line = String::new();
        let read = std::io::stdin().lock().read_line(&mut line);
        // Ignore send errors: the receiver may have timed out and gone away.
        let _ = match read {
            Ok(0) => tx.send(None),
            Ok(_) => tx.send(Some(line)),
            Err(_) => tx.send(None),
        };
    });

    match rx.recv_timeout(timeout) {
        Ok(Some(line)) => ReadOutcome::Line(line),
        Ok(None) => ReadOutcome::Eof,
        Err(mpsc::RecvTimeoutError::Timeout) => ReadOutcome::Timeout,
        Err(mpsc::RecvTimeoutError::Disconnected) => ReadOutcome::Eof,
    }
}
