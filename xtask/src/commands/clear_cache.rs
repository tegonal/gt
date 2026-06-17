use std::{fs, path::PathBuf};

pub fn run() {
    let dir = PathBuf::from("target/xtask-cache");

    if dir.exists() {
        fs::remove_dir_all(&dir).unwrap();
        println!("cache cleared");
    } else {
        println!("no cache found");
    }
}
