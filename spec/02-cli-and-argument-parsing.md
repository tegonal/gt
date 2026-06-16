# 02 — CLI, Argument Parsing, Exit Codes

This document specifies command dispatch, the shared argument-parsing semantics, shared validation
helpers, logging, and exit codes. These behaviours are common to all commands and are described once
here; the per-command docs reference them.

## 1. Top-level dispatch

Invocation form: `gt <command> [args...]`.

Commands:

| Command | Summary |
|---------|---------|
| `pull` | pull files from a previously defined remote |
| `re-pull` | re-pull files defined in `pulled.tsv` of a specific or all remotes |
| `remote` | manage remotes (sub-commands `add`, `remove`, `list`) |
| `reset` | reset one or all remotes (re-establish gpg and re-pull files) |
| `update` | update pulled files to latest or particular version |
| `self-update` | update gt to the latest version |

Special top-level arguments (reserved, handled by the dispatcher):
- `--help` → prints the command list + reserved-option help + version line.
- `--version` → prints the version line.

Dispatch rules (reference: `parseCommands`):
1. If **no** command is given → print help to stderr and exit `9`.
2. If the first token matches a known command name → run that command's function with the remaining args.
3. If it is `--help` → print help (to stdout) and return success.
4. If it is `--version` → print the version and return success.
5. Otherwise → log "unknown command" + help to stderr and return `1`.

`remote` is itself a dispatcher over `add`/`remove`/`list` with the same rules (its own `--help`/
`--version`). Note the hyphen-to-underscore mapping: a command like `re-pull` maps to function/file
`gt-re-pull` / `gt_re_pull` (only the **first** hyphen is translated in the dispatcher's function-name
mapping `${command/-/_}`, but command file names use the literal name).

### Version

Every script reports version `v1.7.0-SNAPSHOT` (constant `GT_VERSION`, also exported to the environment).
The `--version` output ends with a two-line block:

```
INFO: Version of <script>.sh is:
<version>
```

## 2. Argument parsing semantics (`parseArguments`)

All commands use a common named-argument parser. Re-implementations must reproduce these semantics:

- Arguments are **named only**; there are no positional arguments. Form is `<pattern> <value>` pairs.
- Each parameter has a **pattern** which is an alternation of accepted flags, e.g. `-r|--remote`,
  `--auto-trust`. A token matches if it equals (anchored, full-match) one of the alternatives.
- A matched parameter **consumes the next token** as its value. If a recognized flag is the last token
  (no value follows) → error "no value defined for parameter" + exit `9`.
- **Repetition: last wins.** If the same parameter appears twice, the later value overrides. (This is the
  mechanism by which user args override `pull.args` defaults, since defaults are placed first.)
- **Unknown arguments**: the default behaviour is `error` → log "unknown argument" and exit `9`. (There
  is also an `ignore` mode used internally during the two-pass parse of `gt pull`, see below.)
- `--help` anywhere → print parameter help and return `99`. (`99` is the sentinel meaning "help/version
  was requested"; callers treat it specially and do **not** treat it as failure.)
- `--version` → print version, return `99`.
- `--help` and `--version` are **reserved** and must not be used as parameter patterns.

### Help text format

`Parameters:` section lists each `pattern` left-padded to the max pattern width + 2, followed by its help
text (patterns with empty help print just the pattern). Then:

```
--help     prints this help
--version  prints the version of this script
```

then an optional `Examples:` block, then the version line. Exact layout is reproduced for the documented
snippets in the project README but is not otherwise normative.

### Boolean options

Boolean options take an explicit value: `--chop-path true`, `--unsecure true`, etc. There are no bare
flags (e.g. `--unsecure` alone is **not** accepted; a value must follow). `exitIfArgIsNotBoolean`
validates that a value is exactly `true` or `false` where applicable.

### Required-argument enforcement (`exitIfNotAllArgumentsSet`)

After defaults are filled in, each declared parameter that is still unset is reported
("`<name>` not set via `<pattern>`"); if any are missing, the help is printed and the process exits `1`.
Set parameters are made read-only.

## 3. Two-pass parsing in `gt pull`

`gt pull` parses twice (reference: `gt_pull_parse_args`):

1. **First pass** (ignore-unknown, output discarded): parse the raw `$@` just to learn `workingDir` and
   `remote`. This is needed because `pull.args` lives at `<workingDir>/remotes/<remote>/pull.args` and
   must be located before the real parse.
2. Load `pull.args` lines (if the file exists) into an argument array, then append the user's `$@`.
3. **Second pass** (error-on-unknown): parse `pull.args`-then-user args. Because user args come last and
   last-wins, the user can override any default.

This two-pass approach must be preserved so that `-w`/`-r` given on the command line correctly locate
`pull.args`, and so that defaults in `pull.args` are overridable.

## 4. Shared validation order

Most commands follow this validation sequence (important because it determines which error a user sees
first):

1. Determine `currentDir` = process working directory (fail if it cannot be determined).
2. Fill defaults for optional parameters.
3. **`exitIfWorkingDirDoesNotExist`** — the working dir must exist (else exit `9`). (Exception: `remote
   add` instead *offers to create it*.)
4. **`exitIfPathNamedIsOutsideOf workingDir … currentDir`** — the working dir must be inside the current
   directory (else exit via the check, code from `checkPathIsInsideOf`). This is a security boundary: gt
   refuses to operate on a working dir outside the directory it was invoked from.
5. `exitIfNotAllArgumentsSet`.
6. Resolve `workingDirAbsolute` via `readlink -m`.
7. Command-specific checks (remote existence, path well-formedness, etc.).

`checkPathIsInsideOf(path, root)` resolves both with `realpath -m` and returns true iff the absolute path
**string-prefix-matches** the absolute root. (Implication: a sibling dir whose name starts with the root
name could prefix-match; the reference relies on this simple check. A faithful re-implementation may use
proper path-component containment but must still reject genuinely-outside paths and accept the working
dir equal to / inside current dir.)

The exact stderr message for the outside-of check is:
`the given <name> <path> is not inside of <root>` (used by the test-suite; `<name>` e.g.
`working directory`).

## 5. Path / name validation rules

- **Remote name** must match `^[a-zA-Z0-9_-]+$` (enforced in `remote add`).
- **Pull `--path`** must not start with `/` (leading slash rejected with a `die`).
- **`--target-file-name`** must not contain `/`.
- **`--target-file-name`** may not be combined with pulling a **directory** (error; suggests pulling the
  directory and renaming via `pulled.tsv`).
- Every resolved target file is re-checked to be inside `currentDir` before writing (defense-in-depth so
  `re-pull` of a tampered `pulled.tsv` cannot write outside the project).

## 6. Logging

Colorized log helpers write to stdout/stderr with prefixes. Levels: `INFO` (blue), `SUCCESS` (green),
`WARNING` (yellow), `ERROR` (red). Errors and most diagnostics go to **stderr**; normal results and
`remote list` output go to **stdout**. ANSI color codes are emitted unconditionally (no TTY detection in
the reference). Re-implementations SHOULD keep the stdout/stderr split (machine consumers parse stdout,
e.g. `remote list`), and SHOULD keep messages on the same streams.

## 7. Exit codes

`gt` uses the following exit codes. These are part of the contract for scripting/CI:

| Code | Meaning / origin |
|------|------------------|
| `0` | success |
| `1` | generic failure: `die`, verification failed, "0 files pulled", self-update declined, remote-add GPG missing without `--unsecure`, etc. |
| `9` | usage / environment errors: missing command, unknown/invalid argument, missing required argument, missing value for an argument, working dir does not exist, remote dir does not exist, `parseFnArgs`/array-shape programming errors |
| `10` | user aborted a destructive `remote remove` at a confirmation prompt (pull-hook present, or chose to abort rather than delete) |
| `100` | `pulled.tsv` header could not be reconciled (format changed and no automatic migration matched the header) |
| `2`, `3` | only inside `install.sh`: signature verification failed (`2`) / signing key revoked (`3`) — see [11](11-installation.md) |

Additional notes:
- `remote add` uses `exit 9` when the user declines to create a missing working directory.
- The help/version sentinel `99` from the argument parser is internal and never the process exit code in
  normal use (it is translated to success).
- A command that pulls **0** files when at least one was expected returns `1` ("most likely verification
  failed").

## 8. Self-update check hook

`pull`, `re-pull`, and `update` call `gt_checkForSelfUpdate` at the very end (on success). This is a
throttled (every 15 days) check for a newer `gt` release; see [09](09-command-self-update.md). It is part
of normal command flow and must be reproduced (or made configurable) for behavioural parity, though it is
a non-fatal, interactive convenience.

## 9. Common optional parameters (canonical patterns)

These patterns recur across commands (reference: `src/common-constants.source.sh`):

| Variable | Pattern | Default |
|----------|---------|---------|
| remote | `-r\|--remote` | (command-dependent; required for `pull`) |
| workingDir | `-w\|--working-directory` | `.gt` |
| pullDir | `-d\|--directory` | `lib/<remote>` (remote add) / remote's configured dir (pull) |
| tag | `-t\|--tag` | latest matching tag |
| path | `-p\|--path` | (required for `pull`) |
| tagFilter | `--tag-filter` | `.*` |
| autoTrust | `--auto-trust` | `false` |
| unsecure | `--unsecure` | `false` (or the value of `--unsecure-no-verification`) |
| forceNoVerification | `--unsecure-no-verification` | `false` |
| chopPath | `--chop-path` | `false` |
| targetFileName | `--target-file-name` | `""` (keep source name) |
| gpgOnly | `--gpg-only` | `false` |
| list | `--list` | `false` |
| onlyMissing | `--only-missing` | `true` |
| deletePulledFiles | `--delete-pulled-files` | `false` |
| force (self-update) | `--force` | `false` |
