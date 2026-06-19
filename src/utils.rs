use std::sync::OnceLock;
use std::path::PathBuf;

static DIR_OF_GT_LOCK: OnceLock<PathBuf> = OnceLock::new();

pub(crate) fn dir_of_gt() -> PathBuf {
	DIR_OF_GT_LOCK
		.get_or_init(|| {
			std::env::current_exe()
				.unwrap()
				.parent()
				.unwrap()
				.to_path_buf()
		})
		.clone()
}
