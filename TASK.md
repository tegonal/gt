# Goal

Implement the `gt remote add` command in the file `src/commands/remote/add.rs`.

# Instructions

1. Read the current bash implementation in function `gt_remote_add()`  in `src/gt-remote.sh`
3. Implement the remote add in rust in `src/commands/remote/add.rs`.
4. Write tests for the command in the same file.
5. Verify that the code compiles, passes the linter and formatter, and that all tests pass.

# Requirements

- For git operations, use the git2 crate and translate the git CLI calls in the bash implementation to git2 function calls.
- For gpg operations, use the gpgme crate and translate the gpg CLI calls in the bash implementation to gpgme function calls.
- For operations regarding the pulled.tsv database file, create `src/pulled-utils.rs` and add functions there.
