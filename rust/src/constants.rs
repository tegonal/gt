//! Constants shared across the `gt` commands.
//!
//! Mirrors `src/common-constants.source.sh` of the original Bash implementation.
//! Only the constants required by the `remote` command are defined for now; more
//! can be added as further commands are ported.

/// Version of the tool. Mirrors `GT_VERSION` in the Bash sources.
pub const GT_VERSION: &str = "v1.7.0-SNAPSHOT-rust";

// ----- ANSI colour codes (matching the Bash log/ask helpers) -----------------
pub const COLOR_RESET: &str = "\x1b[0m";
pub const COLOR_CYAN: &str = "\x1b[0;36m";
pub const COLOR_MAGENTA: &str = "\x1b[0;35m";

// ----- `--remote` ------------------------------------------------------------
pub const REMOTE_PARAM_PATTERN_LONG: &str = "--remote";
pub const REMOTE_PARAM_PATTERN: &[&str] = &["-r", "--remote"];

// ----- `--working-directory` -------------------------------------------------
pub const WORKING_DIR_PARAM_PATTERN_LONG: &str = "--working-directory";
pub const WORKING_DIR_PARAM_PATTERN: &[&str] = &["-w", "--working-directory"];
pub const DEFAULT_WORKING_DIR: &str = ".gt";

// ----- `--directory` (pull directory) ----------------------------------------
pub const PULL_DIR_PARAM_PATTERN_LONG: &str = "--directory";
pub const PULL_DIR_PARAM_PATTERN: &[&str] = &["-d", "--directory"];

// ----- `--tag-filter` --------------------------------------------------------
pub const TAG_FILTER_PARAM_PATTERN_LONG: &str = "--tag-filter";
pub const TAG_FILTER_PARAM_PATTERN: &[&str] = &["--tag-filter"];
pub const TAG_FILTER_PARAM_DOCU: &str =
    "(optional) define a regexp pattern (as supported by grep -E) to filter available tags when determining the latest tag";

// ----- `--unsecure` ----------------------------------------------------------
pub const UNSECURE_PARAM_PATTERN_LONG: &str = "--unsecure";
pub const UNSECURE_PARAM_PATTERN: &[&str] = &["--unsecure"];

// ----- `--auto-trust` --------------------------------------------------------
pub const AUTO_TRUST_PARAM_PATTERN_LONG: &str = "--auto-trust";

// ----- `--force` (self-update) -----------------------------------------------
pub const FORCE_PARAM_PATTERN_LONG: &str = "--force";
pub const FORCE_PARAM_PATTERN: &[&str] = &["--force"];

// ----- `--url` ---------------------------------------------------------------
pub const URL_PARAM_PATTERN: &[&str] = &["-u", "--url"];

// ----- `--delete-pulled-files` -----------------------------------------------
pub const DELETE_PULLED_FILES_PARAM_PATTERN: &[&str] = &["--delete-pulled-files"];

// ----- pulled.tsv ------------------------------------------------------------
pub const PULLED_TSV_LATEST_VERSION: &str = "1.2.0";
pub const PULLED_TSV_LATEST_VERSION_PRAGMA_WITHOUT_VERSION: &str = "#@ Version: ";
pub const PULLED_TSV_HEADER: &str = "tag\tfile\trelativeTarget\ttagFilter\thasPlaceholder\tsha512";

/// Name of the public signing key that a remote must provide.
pub const SIGNING_KEY_ASC: &str = "signing-key.public.asc";

/// The latest `pulled.tsv` version pragma line (`#@ Version: 1.2.0`).
pub fn pulled_tsv_latest_version_pragma() -> String {
    format!("{PULLED_TSV_LATEST_VERSION_PRAGMA_WITHOUT_VERSION}{PULLED_TSV_LATEST_VERSION}")
}

/// Documentation string for the `--working-directory` parameter.
pub fn working_dir_param_docu() -> String {
    format!("(optional) path which gt shall use as working directory -- default: {DEFAULT_WORKING_DIR}")
}
