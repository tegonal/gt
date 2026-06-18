use crate::commands::{helpers, taplo};

pub fn run() {
	helpers::run_command("cargo", &["fmt"], &[]);
	taplo::format();
	helpers::run_command("cargo", &["fix", "--allow-dirty"], &[]);
}
