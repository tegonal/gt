use sha2::{Digest, Sha256};
use std::{
    fs,
    path::PathBuf,
    process::{Command, exit},
};
use url::Url;

pub fn run(force: bool, llvm_cov_args: &[String]) {
    let key = cache_key();
    let cache_dir = PathBuf::from("target/xtask-cache").join(&key);
    let coverage_file = cache_dir.join("coverage.json");
	let abs = fs::canonicalize(&coverage_file).unwrap();
	let url = Url::from_file_path(&abs).unwrap();
	//
    // if !force && coverage_file.exists() {
    //     println!("cache hit: {}", url);
    //     return;
    // }

    println!("cache miss → running cargo llvm-cov");

    fs::create_dir_all(&cache_dir).unwrap();

    let status = Command::new("cargo")
        .args([
            "llvm-cov",
            // "--json",
            // "--output-path",
            // coverage_file.to_str().unwrap(),
        ])
		.args(llvm_cov_args)
        .status()
        .expect("failed to run cargo llvm-cov");

    if !status.success() {
        exit(status.code().unwrap_or(1));
    }

    println!("stored → {}", url);
}

fn cache_key() -> String {
    let git = cmd("git", &["rev-parse", "HEAD"]);
    let lock = hash_file("Cargo.lock");
    let rustc = cmd("rustc", &["--version"]);
    let cov = cmd("cargo", &["llvm-cov", "--version"]);

    sha256(format!("{git}{lock}{rustc}{cov}"))
}

fn cmd(exe: &str, args: &[&str]) -> String {
    let out = Command::new(exe)
        .args(args)
        .output()
        .expect("command failed");

    String::from_utf8_lossy(&out.stdout).trim().to_string()
}

fn hash_file(path: &str) -> String {
    let data = fs::read(path).unwrap_or_default();
    sha256(data)
}

fn sha256<T: AsRef<[u8]>>(data: T) -> String {
    let mut h = Sha256::new();
    h.update(data);
    hex::encode(h.finalize())
}
