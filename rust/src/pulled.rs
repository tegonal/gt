//! Minimal `pulled.tsv` reader, mirroring the parts of `pulled-utils.sh` needed
//! by `remote remove --delete-pulled-files`.
//!
//! The original supports automatic migration of older `pulled.tsv` formats; that
//! logic belongs to the (not-yet-ported) `pull` infrastructure. Here we validate
//! that the file is already at the latest format and otherwise fail with the same
//! exit code (100) the Bash code uses for an unexpected header.

use std::path::{Path, PathBuf};

use crate::args::cyan;
use crate::constants::{pulled_tsv_latest_version_pragma, GT_VERSION, PULLED_TSV_HEADER, PULLED_TSV_LATEST_VERSION};
use crate::error::Exit;
use crate::log::{log_error, log_warning};
use crate::util::normalize_path;

/// A single data row of `pulled.tsv`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PulledEntry {
    pub tag: String,
    pub file: String,
    pub relative_target: String,
    pub tag_filter: String,
    pub has_placeholder: String,
    pub sha512: String,
    /// the resolved absolute path of `relative_target` (relative to the working dir)
    pub absolute_path: PathBuf,
}

/// Reads `pulled.tsv` for the given remote and returns its data entries.
///
/// Returns `Ok(None)` (and warns) if there is no `pulled.tsv`. Mirrors
/// `readPulledTsv` + `exitIfHeaderOfPulledTsvIsWrong`.
pub fn read_pulled_tsv(
    working_dir_absolute: &Path,
    remote: &str,
    pulled_tsv: &Path,
) -> Result<Option<Vec<PulledEntry>>, Exit> {
    if !pulled_tsv.is_file() {
        log_warning(&format!(
            "Looks like remote {} is broken or no file has been fetched so far, there is no pulled.tsv, skipping it",
            cyan(remote)
        ));
        return Ok(None);
    }

    let content = std::fs::read_to_string(pulled_tsv).map_err(|_| {
        log_error(&format!(
            "could not read the current pulled.tsv at {}",
            pulled_tsv.display()
        ));
        Exit(1)
    })?;
    let mut lines = content.lines();

    let version_pragma = lines.next().unwrap_or("");
    if version_pragma != pulled_tsv_latest_version_pragma() {
        log_error(&format!(
            "the format of {} is not at the latest version {PULLED_TSV_LATEST_VERSION}; automatic migration is part of the (not yet ported) pull command",
            cyan(&pulled_tsv.display().to_string())
        ));
        eprintln!("In case you updated gt, then check the release notes for migration hints:");
        eprintln!("https://github.com/tegonal/gt/releases/tag/{GT_VERSION}");
        return Err(Exit(100));
    }

    let header = lines.next().unwrap_or("");
    if header != PULLED_TSV_HEADER {
        log_error(&format!(
            "looks like the format of {} changed:",
            cyan(&pulled_tsv.display().to_string())
        ));
        eprintln!("Expected Header (after Version pragma): {PULLED_TSV_HEADER}");
        eprintln!("Current  Header (after Version pragma): {header}");
        eprintln!();
        eprintln!("In case you updated gt, then check the release notes for migration hints:");
        eprintln!("https://github.com/tegonal/gt/releases/tag/{GT_VERSION}");
        return Err(Exit(100));
    }

    let mut entries = Vec::new();
    for line in lines {
        if line.is_empty() {
            continue;
        }
        let fields: Vec<&str> = line.split('\t').collect();
        if fields.len() < 6 {
            continue;
        }
        let relative_target = fields[2].to_string();
        let absolute_path = normalize_path(&working_dir_absolute.join(&relative_target)).map_err(|_| {
            log_error(&format!(
                "could not determine local absolute path of {} of remote {remote}",
                fields[1]
            ));
            Exit(1)
        })?;
        entries.push(PulledEntry {
            tag: fields[0].to_string(),
            file: fields[1].to_string(),
            relative_target,
            tag_filter: fields[3].to_string(),
            has_placeholder: fields[4].to_string(),
            sha512: fields[5].to_string(),
            absolute_path,
        });
    }
    Ok(Some(entries))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    fn temp_file(name: &str, content: &str) -> (PathBuf, PathBuf) {
        let dir = std::env::temp_dir().join(format!("gt-pulled-test-{}-{name}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let file = dir.join("pulled.tsv");
        std::fs::write(&file, content).unwrap();
        (dir, file)
    }

    #[test]
    fn missing_pulled_tsv_returns_none() {
        let dir = std::env::temp_dir().join(format!("gt-pulled-missing-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let res = read_pulled_tsv(&dir, "r", &dir.join("does-not-exist.tsv")).unwrap();
        assert!(res.is_none());
    }

    #[test]
    fn parses_latest_format_entries() {
        let content = "#@ Version: 1.2.0\n\
tag\tfile\trelativeTarget\ttagFilter\thasPlaceholder\tsha512\n\
v1.0.0\tsrc/a.sh\t../lib/a.sh\t.*\tfalse\tabc\n\
v1.0.0\tsrc/b.sh\t../lib/b.sh\t.*\ttrue\tdef\n";
        let (dir, file) = temp_file("ok", content);
        let entries = read_pulled_tsv(&dir, "r", &file).unwrap().unwrap();
        assert_eq!(entries.len(), 2);
        assert_eq!(entries[0].tag, "v1.0.0");
        assert_eq!(entries[0].file, "src/a.sh");
        assert_eq!(entries[0].relative_target, "../lib/a.sh");
        assert_eq!(entries[1].has_placeholder, "true");
        // absolute path is resolved relative to the working dir
        assert!(entries[0].absolute_path.is_absolute());
    }

    #[test]
    fn rejects_outdated_version() {
        let content = "#@ Version: 1.1.0\ntag\tfile\trelativeTarget\ttagFilter\tsha512\n";
        let (dir, file) = temp_file("old", content);
        let err = read_pulled_tsv(&dir, "r", &file).unwrap_err();
        assert_eq!(err.code(), 100);
    }

    #[test]
    fn rejects_wrong_header() {
        let content = "#@ Version: 1.2.0\nwrong\theader\n";
        let (dir, file) = temp_file("badheader", content);
        let err = read_pulled_tsv(&dir, "r", &file).unwrap_err();
        assert_eq!(err.code(), 100);
    }
}
