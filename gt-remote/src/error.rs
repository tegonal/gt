use thiserror::Error;

#[derive(Error, Debug)]
pub enum GtRemoteError {
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("Git error: {0}")]
    Git(String),

    #[error("GPG error: {0}")]
    Gpg(String),

    #[error("Configuration error: {0}")]
    Config(String),

    #[error("Remote '{0}' already exists")]
    RemoteExists(String),

    #[error("Remote '{0}' does not exist")]
    RemoteNotFound(String),

    #[error("Invalid remote name: {0} (must match ^[a-zA-Z0-9_-]+$)")]
    InvalidRemoteName(String),

    #[error("Working directory does not exist: {0}")]
    WorkingDirNotFound(String),

    #[error("Failed to fetch from remote: {0}")]
    FetchError(String),

    #[error("No GPG keys found in remote")]
    NoGpgKeys,

    #[error("Invalid URL: {0}")]
    InvalidUrl(String),
}

pub type Result<T> = std::result::Result<T, GtRemoteError>;
