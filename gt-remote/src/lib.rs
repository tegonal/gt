pub mod commands;
pub mod config;
pub mod error;
pub mod git;
pub mod gpg;

pub use error::Result;

#[cfg(test)]
mod tests {
    use super::commands;
    use super::config;
    use super::git;
    use std::fs;
    use tempfile::TempDir;

    #[test]
    fn test_paths_structure() {
        let temp_dir = TempDir::new().unwrap();
        let working_dir = temp_dir.path().join(".gt");
        fs::create_dir_all(&working_dir).unwrap();

        let remote_name = "test-remote";
        let remote_dir = working_dir.join("remotes").join(remote_name);
        let public_keys_dir = remote_dir.join("public-keys");
        let repo = remote_dir.join("repo");
        let gpg_dir = public_keys_dir.join("gpg");

        assert_eq!(remote_dir, working_dir.join("remotes").join(remote_name));
        assert_eq!(public_keys_dir, remote_dir.join("public-keys"));
        assert_eq!(repo, remote_dir.join("repo"));
        assert_eq!(gpg_dir, public_keys_dir.join("gpg"));
    }

    #[test]
    fn test_resolve_working_dir_absolute() {
        let temp_dir = TempDir::new().unwrap();
        let path = temp_dir.path().to_path_buf();

        let resolved = config::resolve_working_dir(path.to_str().unwrap()).unwrap();
        assert_eq!(resolved, path);
    }

    #[test]
    fn test_resolve_working_dir_relative() {
        let current_dir = std::env::current_dir().unwrap();
        let working_dir = ".gt";

        let resolved = config::resolve_working_dir(working_dir).unwrap();
        assert_eq!(resolved, current_dir.join(working_dir));
    }

    #[test]
    fn test_remote_name_validation() {
        let valid_names = vec!["test", "test-remote", "test_remote", "test123", "Test123"];
        let invalid_names = vec!["test.remote", "test remote", "test/remote", ""];

        for name in valid_names {
            assert!(
                !name.is_empty()
                    && name
                        .chars()
                        .all(|c| c.is_alphanumeric() || c == '-' || c == '_'),
                "{} should be valid",
                name
            );
        }

        for name in invalid_names {
            assert!(
                name.is_empty()
                    || !name
                        .chars()
                        .all(|c| c.is_alphanumeric() || c == '-' || c == '_'),
                "{} should be invalid",
                name
            );
        }
    }

    #[test]
    fn test_exit_if_path_outside_of_inside() {
        let current_dir = std::env::current_dir().unwrap();
        let inside_path = current_dir.join(".gt");

        let result = config::exit_if_path_outside_of(&current_dir, &inside_path, "test");
        assert!(result.is_ok());
    }

    #[test]
    fn test_list_remotes_empty() {
        let temp_dir = TempDir::new().unwrap();
        let working_dir = temp_dir.path().join(".gt");
        fs::create_dir_all(&working_dir).unwrap();

        let result = commands::list::execute(working_dir.to_str().unwrap());
        assert!(result.is_ok());
    }

    #[test]
    fn test_list_remotes_with_remotes() {
        let temp_dir = TempDir::new().unwrap();
        let working_dir = temp_dir.path().join(".gt");
        let remotes_dir = working_dir.join("remotes");
        fs::create_dir_all(remotes_dir.join("remote1")).unwrap();
        fs::create_dir_all(remotes_dir.join("remote2")).unwrap();

        let result = commands::list::execute(working_dir.to_str().unwrap());
        assert!(result.is_ok());
    }

    #[test]
    fn test_remove_nonexistent_remote() {
        let temp_dir = TempDir::new().unwrap();
        let working_dir = temp_dir.path().join(".gt");
        fs::create_dir_all(&working_dir).unwrap();

        let result = commands::remove::execute(working_dir.to_str().unwrap(), "nonexistent", false);
        assert!(result.is_err());
    }

    #[test]
    fn test_remove_remote() {
        let temp_dir = TempDir::new().unwrap();
        let working_dir = temp_dir.path().join(".gt");
        let remote_dir = working_dir.join("remotes").join("test-remote");
        fs::create_dir_all(&remote_dir).unwrap();

        let result = commands::remove::execute(working_dir.to_str().unwrap(), "test-remote", false);
        assert!(result.is_ok());
        assert!(!remote_dir.exists());
    }

    #[test]
    fn test_git_init_git_dir() {
        let temp_dir = TempDir::new().unwrap();
        let repo_path = temp_dir.path().join("repo");

        let result = git::init_git_dir(&repo_path);
        assert!(result.is_ok());
        assert!(repo_path.join(".git").exists());
    }

    #[test]
    fn test_get_remote_default_branch_with_real_remote() {
        let temp_dir = TempDir::new().unwrap();
        let repo_path = temp_dir.path().join("repo");

        // Initialize a local git repo
        git::init_git_dir(&repo_path).unwrap();

        // Add a real remote
        git::add_remote(&repo_path, "origin", "https://github.com/tegonal/gt.git").unwrap();

        // Fetch refs to get branch information
        let status = std::process::Command::new("git")
            .arg("-C")
            .arg(&repo_path)
            .arg("fetch")
            .arg("--depth")
            .arg("1")
            .arg("origin")
            .status()
            .unwrap();
        assert!(status.success());

        // Now try to get the default branch
        let result = git::get_remote_default_branch(&repo_path, "origin");
        assert!(result.is_ok());
        let branch = result.unwrap();
        // Most modern repos use 'main' as default
        assert!(!branch.is_empty());
    }
}
