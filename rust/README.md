# gt — Rust implementation

A Rust re-implementation of the [`gt`](https://github.com/tegonal/gt) tool.

Currently only the **`remote`** command (`add` / `list` / `remove`) is ported,
translated from the original Bash `src/gt-remote.sh`. The module layout mirrors
the Bash helper files so the remaining commands (`pull`, `update`, …) can be
added incrementally — see `src/lib.rs` for where to wire them up.

## Dev environment

The project uses the standard Rust toolchain (Rust 1.96 / edition 2021) with the
standard formatter and linter:

```bash
# install the toolchain (if not already present)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
rustup component add rustfmt clippy

# build / run
cargo build
cargo run -- remote list

# format & lint
cargo fmt
cargo clippy --all-targets -- -D warnings

# tests (unit + integration)
cargo test
```

There are **no third-party dependencies**: the implementation relies only on the
standard library plus the `git` and `gpg` command line tools — exactly like the
original Bash implementation, which keeps behaviour identical.

## Layout

| Module           | Mirrors (Bash)                                  |
|------------------|-------------------------------------------------|
| `log` / `ask`    | `utility/log.sh`, `utility/ask.sh`              |
| `args`           | `utility/parse-args.sh`, `parse-commands.sh`    |
| `constants`      | `common-constants.source.sh`                    |
| `paths`          | `paths.source.sh`                               |
| `git` / `gpg`    | `git`/`gpg` wrappers from `utils.sh`            |
| `util`           | `deleteDirChmod777`, path checks, …             |
| `pulled`         | `pulled-utils.sh` (read side)                   |
| `commands::remote` | `gt-remote.sh`                                |

## Behaviour parity

The implementation preserves the original's user-facing behaviour: coloured
`INFO`/`WARNING`/`ERROR`/`SUCCESS` log prefixes, the `--help`/`--version`
handling (including the exit code `99` that `add`/`remove --help` propagate), the
interactive yes/no prompts with a 20-second timeout, the on-disk layout under
`<workingDir>/remotes/<remote>/`, and the GPG trust/verification flow.

Integration tests in `tests/cli.rs` drive the compiled binary and cover the
`--unsecure` path (local `file://` repo, no GPG needed) as well as the full
secure path using a freshly generated GPG key.
