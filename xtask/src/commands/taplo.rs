use crate::commands::helpers;

pub fn format() {
	helpers::run_command("taplo", &["fmt"], &[("RUST_LOG", "warn")]);
}
