#![allow(dead_code)]

use std::fs::{self, File};
use std::io::{self, BufRead, BufReader, Write};
use std::path::Path;

pub const PULLED_TSV_VERSION: &str = "1.2.0";
pub const PULLED_TSV_VERSION_PRAGMA: &str = "#@ Version: 1.2.0";
pub const PULLED_TSV_HEADER: &str = "tag\tfile\trelativeTarget\ttagFilter\thasPlaceholder\tsha512";

/// Represents a single row in the `pulled.tsv` database file.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PulledTsvEntry {
	pub tag: String,
	pub file: String,
	pub relative_target: String,
	pub tag_filter: String,
	pub has_placeholder: String,
	pub sha512: String,
}

impl PulledTsvEntry {
	/// Serialises the entry into a single TSV row (without trailing newline).
	pub fn to_tsv_row(&self) -> String {
		format!(
			"{}\t{}\t{}\t{}\t{}\t{}",
			self.tag, self.file, self.relative_target, self.tag_filter, self.has_placeholder, self.sha512
		)
	}

	/// Parses a single TSV row into a [`PulledTsvEntry`].
	///
	/// Returns `None` if the row does not contain exactly six tab-separated fields.
	pub fn parse_from_row(row: &str) -> Option<Self> {
		let parts: Vec<&str> = row.split('\t').collect();
		if parts.len() != 6 {
			return None;
		}
		Some(Self {
			tag: parts[0].to_string(),
			file: parts[1].to_string(),
			relative_target: parts[2].to_string(),
			tag_filter: parts[3].to_string(),
			has_placeholder: parts[4].to_string(),
			sha512: parts[5].to_string(),
		})
	}
}

/// In-memory representation of the `pulled.tsv` database file.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PulledTsv {
	pub entries: Vec<PulledTsvEntry>,
}

impl PulledTsv {
	/// Creates an empty `PulledTsv`.
	pub fn new() -> Self {
		Self { entries: Vec::new() }
	}

	/// Serialises the entire database, including the version pragma and header.
	pub fn to_file_content(&self) -> String {
		let mut content = format!("{}\n{}\n", PULLED_TSV_VERSION_PRAGMA, PULLED_TSV_HEADER);
		for entry in &self.entries {
			content.push_str(&entry.to_tsv_row());
			content.push('\n');
		}
		content
	}

	/// Parses `pulled.tsv` content.
	///
	/// Validates the version pragma on the first line and the header on the second line.
	pub fn parse_from_str(content: &str) -> io::Result<Self> {
		let mut lines = content.lines();

		let version = lines.next().ok_or_else(|| {
			io::Error::new(
				io::ErrorKind::InvalidData,
				"pulled.tsv is empty, missing version pragma",
			)
		})?;
		if version != PULLED_TSV_VERSION_PRAGMA {
			return Err(io::Error::new(
				io::ErrorKind::InvalidData,
				format!("unexpected version pragma: {}", version),
			));
		}

		let header = lines
			.next()
			.ok_or_else(|| io::Error::new(io::ErrorKind::InvalidData, "pulled.tsv is missing header line"))?;
		if header != PULLED_TSV_HEADER {
			return Err(io::Error::new(
				io::ErrorKind::InvalidData,
				format!("unexpected header: {}", header),
			));
		}

		let mut entries = Vec::new();
		for line in lines {
			if line.is_empty() {
				continue;
			}
			if let Some(entry) = PulledTsvEntry::parse_from_row(line) {
				entries.push(entry);
			} else {
				return Err(io::Error::new(
					io::ErrorKind::InvalidData,
					format!("invalid TSV row: {}", line),
				));
			}
		}

		Ok(Self { entries })
	}

	/// Writes the serialised database to `path`.
	pub fn write_to_file(&self, path: &Path) -> io::Result<()> {
		fs::write(path, self.to_file_content())
	}
}

impl Default for PulledTsv {
	fn default() -> Self {
		Self::new()
	}
}

/// Writes the `pull.args` file inside `remote_dir`.
///
/// The file stores the default arguments that `gt pull` will use for this remote:
///
/// ```text
/// --directory "<pull_dir>"
/// --tag-filter "<tag_filter>"   # only if tag_filter != ".*"
/// --unsecure true               # only if unsecure == true
/// ```
pub fn write_pull_args_file(remote_dir: &Path, pull_dir: &str, tag_filter: &str, unsecure: bool) -> io::Result<()> {
	let pull_args_file = remote_dir.join("pull.args");
	let mut file = File::create(&pull_args_file)?;

	writeln!(file, "--directory \"{}\"", pull_dir)?;

	if tag_filter != ".*" {
		writeln!(file, "--tag-filter \"{}\"", tag_filter)?;
	}

	if unsecure {
		writeln!(file, "--unsecure true")?;
	}

	file.flush()?;
	Ok(())
}

/// Reads the `pull.args` file from `remote_dir` and returns each non-empty line.
///
/// Returns an empty `Vec` if the file does not exist.
pub fn read_pull_args_file(remote_dir: &Path) -> io::Result<Vec<String>> {
	let pull_args_file = remote_dir.join("pull.args");
	if !pull_args_file.exists() {
		return Ok(Vec::new());
	}

	let file = File::open(&pull_args_file)?;
	let reader = BufReader::new(file);
	let mut lines = Vec::new();

	for line in reader.lines() {
		let line = line?;
		if !line.trim().is_empty() {
			lines.push(line);
		}
	}

	Ok(lines)
}

/// Returns `true` if `remote_dir` exists **and** contains a `pulled.tsv` file.
///
/// This is used to detect whether a remote has already been set up with pulled files.
pub fn check_remote_exists_with_pulled(remote_dir: &Path) -> bool {
	if !remote_dir.exists() {
		return false;
	}
	let pulled_tsv = remote_dir.join("pulled.tsv");
	pulled_tsv.exists()
}

/// Creates the remote directory.
///
/// Fails if the directory already exists (mirrors `mkdir` without `-p`).
pub fn create_remote_dir(remote_dir: &Path) -> io::Result<()> {
	fs::create_dir(remote_dir)
}

#[cfg(test)]
mod tests {
	use super::*;
	use tempfile::TempDir;

	#[test]
	fn pulled_tsv_roundtrip() {
		let mut tsv = PulledTsv::new();
		tsv.entries.push(PulledTsvEntry {
			tag: "v1.0.0".to_string(),
			file: "src/foo.sh".to_string(),
			relative_target: "../lib/foo.sh".to_string(),
			tag_filter: ".*".to_string(),
			has_placeholder: "false".to_string(),
			sha512: "abc123".to_string(),
		});

		let content = tsv.to_file_content();
		let parsed = PulledTsv::parse_from_str(&content).unwrap();
		assert_eq!(tsv.entries, parsed.entries);
	}

	#[test]
	fn parse_tsv_entry_from_row() {
		let row = "v4.12.0\tsrc/utility/io.sh\t../lib/io.sh\t.*\tfalse\tabc123";
		let entry = PulledTsvEntry::parse_from_row(row).unwrap();
		assert_eq!(entry.tag, "v4.12.0");
		assert_eq!(entry.file, "src/utility/io.sh");
		assert_eq!(entry.relative_target, "../lib/io.sh");
		assert_eq!(entry.tag_filter, ".*");
		assert_eq!(entry.has_placeholder, "false");
		assert_eq!(entry.sha512, "abc123");
	}

	#[test]
	fn write_and_read_pull_args() {
		let tmp = TempDir::new().unwrap();
		let remote_dir = tmp.path().join("my-remote");
		fs::create_dir(&remote_dir).unwrap();

		write_pull_args_file(&remote_dir, "lib/my-remote", ".*", false).unwrap();
		let lines = read_pull_args_file(&remote_dir).unwrap();
		assert_eq!(lines, vec!["--directory \"lib/my-remote\""]);
	}

	#[test]
	fn write_and_read_pull_args_with_all_options() {
		let tmp = TempDir::new().unwrap();
		let remote_dir = tmp.path().join("my-remote");
		fs::create_dir(&remote_dir).unwrap();

		write_pull_args_file(&remote_dir, "lib/my-remote", "^v[0-9]+\\.[0-9]+\\.[0-9]+$", true).unwrap();
		let lines = read_pull_args_file(&remote_dir).unwrap();
		assert_eq!(
			lines,
			vec![
				"--directory \"lib/my-remote\"",
				"--tag-filter \"^v[0-9]+\\.[0-9]+\\.[0-9]+$\"",
				"--unsecure true",
			]
		);
	}

	#[test]
	fn check_remote_exists_with_pulled_detects_pulled_tsv() {
		let tmp = TempDir::new().unwrap();
		let remote_dir = tmp.path().join("remote");
		fs::create_dir(&remote_dir).unwrap();
		assert!(!check_remote_exists_with_pulled(&remote_dir));

		File::create(remote_dir.join("pulled.tsv")).unwrap();
		assert!(check_remote_exists_with_pulled(&remote_dir));
	}

	#[test]
	fn create_remote_dir_creates_directory() {
		let tmp = TempDir::new().unwrap();
		let remote_dir = tmp.path().join("new-remote");
		assert!(!remote_dir.exists());

		create_remote_dir(&remote_dir).unwrap();
		assert!(remote_dir.is_dir());

		// Creating again should fail
		assert!(create_remote_dir(&remote_dir).is_err());
	}
}
