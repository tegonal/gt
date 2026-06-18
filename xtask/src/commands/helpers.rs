use std::process::{Command, ExitStatus};

pub fn run_command(cmd: &str, args: &[&str], envs: &[(&str, &str)]) -> ExitStatus {
	println!("> {} {}", cmd, args.join(" "));

	let status = Command::new(cmd)
		.envs(envs.iter().copied())
		.args(args)
		.status()
		.unwrap_or_else(|e| {
			eprintln!("Failed to execute {}: {e}", cmd);
			std::process::exit(1);
		});

	if !status.success() {
		eprintln!("Command failed: {} {:?}", cmd, args);
		std::process::exit(status.code().unwrap_or(1));
	}

	status
}
