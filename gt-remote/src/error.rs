use thiserror::Error;

#[derive(Error, Debug)]
pub enum Error {
    #[error("Invalid remote name '{name}': must match pattern {pattern}")]
    InvalidRemoteName { name: String, pattern: String },

    #[error("Path '{path}' for {path_type} is outside of current directory")]
    PathOutsideCurrentDir { path_type: String, path: String },

    #[error("Remote '{remote}' already exists with pulled files")]
    RemoteExists { remote: String },

    #[error("Remote '{remote}' already exists but without pulled files")]
    RemoteExistsEmpty { remote: String },

    #[error("Remote '{remote}' not found")]
    RemoteNotFound { remote: String },

    #[error("Remote has no .gt directory in default branch: {branch}")]
    NoGtDirectory { branch: String },

    #[error("Remote has no signing-key.public.asc in .gt directory")]
    NoSigningKey,

    #[error("No GPG keys imported for remote '{remote}'")]
    NoGpgKeysImported { remote: String },

    #[error("Git error: {0}")]
    Git(String),

    #[error("GPG error: {0}")]
    Gpg(String),

    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("Generic error: {0}")]
    Generic(String),

    #[error("User cancelled operation")]
    Cancelled,
}

pub type Result<T> = std::result::Result<T, Error>;
