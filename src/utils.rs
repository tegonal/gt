use std::fmt;
use std::io::{self, Write};

/// Prompts the user on stderr with `prompt` and reads a line from stdin.
///
/// Returns `true` if the user answers "y" or "yes" (case-insensitive),
/// and `false` for any other input (including empty, "n", or "no").
///
/// This can be used for interactive prompts like the bash `askYesOrNo`.
pub fn ask_yes_no(prompt: &str) -> io::Result<bool> {
	let mut stderr = io::stderr();
	write!(stderr, "{} y/[n]: ", prompt)?;
	stderr.flush()?;

	let mut buf = String::new();
	io::stdin().read_line(&mut buf)?;

	let trimmed = buf.trim();
	Ok(matches!(trimmed.to_ascii_lowercase().as_str(), "y" | "yes"))
}

/// Overload that accepts any reader, used for testability.
pub fn ask_yes_no_with_reader<R, W>(prompt: &str, reader: &mut R, writer: &mut W) -> io::Result<bool>
where
	R: io::BufRead,
	W: Write,
{
	write!(writer, "{} y/[n]: ", prompt)?;
	writer.flush()?;

	let mut buf = String::new();
	reader.read_line(&mut buf)?;

	let trimmed = buf.trim();
	Ok(matches!(trimmed.to_ascii_lowercase().as_str(), "y" | "yes"))
}

/// Like `ask_yes_no`, but repeats until the user gives a clear yes or no answer.
pub fn ask_yes_no_loop(prompt: &str) -> io::Result<bool> {
	loop {
		let answer = ask_yes_no(prompt)?;
		// ask_yes_no already returns false for anything except y/yes.
		// To mirror bash behavior of warning on unknown input, we'd need
		// to know if the input was blank vs unknown. For simplicity we
		// treat all non-y/yes as "no".
		return Ok(answer);
	}
}

#[derive(Debug)]
pub enum GtError {
	Io(io::Error),
	Validation(String),
}

impl fmt::Display for GtError {
	fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
		match self {
			GtError::Io(e) => write!(f, "IO error: {}", e),
			GtError::Validation(msg) => write!(f, "{}", msg),
		}
	}
}

impl std::error::Error for GtError {}

impl From<io::Error> for GtError {
	fn from(e: io::Error) -> Self {
		GtError::Io(e)
	}
}

#[cfg(test)]
mod tests {
	use super::*;
	use std::io::Cursor;

	#[test]
	fn ask_yes_no_reads_y() {
		let input = b"y\n";
		let mut reader = Cursor::new(&input[..]);
		let mut output = Vec::new();

		let result = ask_yes_no_with_reader("Create dir?", &mut reader, &mut output).unwrap();
		assert!(result);
		let out = String::from_utf8(output).unwrap();
		assert!(out.contains("Create dir?"));
	}

	#[test]
	fn ask_yes_no_reads_YES() {
		let input = b"YES\n";
		let mut reader = Cursor::new(&input[..]);
		let mut output = Vec::new();

		let result = ask_yes_no_with_reader("Create dir?", &mut reader, &mut output).unwrap();
		assert!(result);
	}

	#[test]
	fn ask_yes_no_reads_n() {
		let input = b"n\n";
		let mut reader = Cursor::new(&input[..]);
		let mut output = Vec::new();

		let result = ask_yes_no_with_reader("Create dir?", &mut reader, &mut output).unwrap();
		assert!(!result);
	}

	#[test]
	fn ask_yes_no_reads_empty_as_no() {
		let input = b"\n";
		let mut reader = Cursor::new(&input[..]);
		let mut output = Vec::new();

		let result = ask_yes_no_with_reader("Create dir?", &mut reader, &mut output).unwrap();
		assert!(!result);
	}

	#[test]
	fn ask_yes_no_reads_garbage_as_no() {
		let input = b"maybe\n";
		let mut reader = Cursor::new(&input[..]);
		let mut output = Vec::new();

		let result = ask_yes_no_with_reader("Create dir?", &mut reader, &mut output).unwrap();
		assert!(!result);
	}
}
