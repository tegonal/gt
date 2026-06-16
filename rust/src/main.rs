//! Binary entry point for the `gt` tool.

use std::process::ExitCode;

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    match gt::run(&args) {
        Ok(()) => ExitCode::SUCCESS,
        Err(exit) => {
            let code = exit.code();
            // ExitCode only carries a u8; clamp like a shell would (codes are 0-255).
            ExitCode::from((code & 0xff) as u8)
        }
    }
}
