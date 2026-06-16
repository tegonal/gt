# Migration from Bash to Rust

## Migration of pulled.tsv

In a first step, the pull command has been migrated WITHOUT migration of the pulled.tsv between versions. This should be added later.

## Fully implement the 30-day perioic check

The 30-day periodic check has not been fully implemented yet in Rust, because the 'reset' command is not ported yet.

## Switch to crates instead of external tools?

Currently, the tool is implemented with a zero-dependency policy. If desirable, the following extenal tools could be replaces with 
Rust crates:

 - sha2sum => sha2
 - grep => regex
 - git
 - gpg

