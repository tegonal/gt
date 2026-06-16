# 14 — External Dependencies, Environment & Platform Assumptions

This document lists the external behaviours `gt` relies on, so a re-implementation knows what to replicate
(via libraries or by shelling out) and what environmental assumptions hold.

## 1. Required external programs

| Program | Used for |
|---------|----------|
| `git` | fetching tags/branches, `ls-remote`, shallow `fetch`, `checkout`, `show`, `hash-object`, `diff`, `init`, `remote` |
| `gpg` | verifying signatures, importing keys, ownertrust, listing keys/sigs/packets, revocation/expiration data |
| `perl` | revocation-data extraction (regex over `--list-sigs`), key-id extraction, placeholder helpers, install-doc injection |
| `coreutils` | `sha512sum`, `cut`, `sort --version-sort`, `find -print0`, `realpath`, `readlink -m`, `basename`, `dirname`, `mktemp`, `date`, `head`/`tail`, `chmod` |
| `grep` (`-E`) | tag filtering, header/entry matching, key-state checks |
| `sed` | version/major extraction, highlighting |
| `wget` or `curl` | `install.sh` fetching the current public key (wget preferred, curl fallback) |
| `bash` ≥ 5 | the implementation language (uses `shopt -s inherit_errexit`) |
| `zsh`, `sudo` | optional: completion install |

A faithful port should reproduce the **observable behaviour** of these (especially `git` and `gpg`
semantics). Shelling out to `git`/`gpg` is the most compatible approach; using native libraries is
acceptable if the trust/verification decisions match [03](03-gpg-trust-model.md) exactly.

## 2. Key `git` invocations (semantics to preserve)

- **Latest tag:** `git ls-remote --refs --tags <remoteOrUrl>` → take the tag name (3rd `/`-delimited
  field) → `sort --version-sort` → filter by `grep -E <tagFilter>` → last line. Empty ⇒ error.
- **Tag existence:** compare against `git ls-remote -t <remote>` / `git tag` output.
- **Fetch a tag:** shallow `git fetch --depth 1 <remote> refs/tags/<tag>:refs/tags/<tag>` (skipped if the
  tag already exists locally).
- **Checkout a path at a tag:** `git -C <repo> checkout tags/<tag> -- <path>`.
- **Default branch:** `git ls-remote --symref <remote> HEAD` → parse `ref: refs/heads/<branch>`; fallback
  `main`.
- **Fetch `.gt` from default branch:** `git fetch --depth 1 <remote> <branch>` then
  `git checkout <remote>/<branch> -- .gt`.
- **Old version of a file (placeholders):** `git show tags/<entryTag>:<repoPath>`.
- **Char-level diff (for warnings):** stores both strings via `git hash-object -w --stdin` and runs
  `git diff --word-diff=color --word-diff-regex .` (cosmetic; not behaviorally essential).

## 3. Key `gpg` invocations (semantics to preserve)

See [03](03-gpg-trust-model.md) §7 for the parsing details. Summary:
- Verify detached signature: `gpg --homedir <dir> --verify <file>.sig <file>` (per-file uses the remote's
  `gpgDir`; the signing-key signature uses the **user's** default store).
- Import (dry-run then real) and set ownertrust to ultimate (`5`).
- Key state via `--list-keys --with-colons` (`pub`/`sub` validity field: `e`=expired, `r`=revoked).
- Signature creation date via `--list-packets`; revocation timestamp via `--list-sigs --with-colons`.
- gpg home paths ≥ 100 chars are symlinked under a temp dir to avoid the socket-path length limit.

## 4. Environment variables

- `GT_VERSION` — exported by gt; the version string (`v1.7.0-SNAPSHOT`).
- `CDPATH` — explicitly `unset` at startup of every script (so `cd` is predictable).
- `LC_TIME` — affects the "user format" date used in some informational messages
  (`date +%x` / `timestampToDateInUserFormat`).
- CI-only: `PUBLIC_GPG_KEYS_WE_TRUST`, `DO_GT_UPDATE`, `GT_UPDATE_API_TOKEN`, `AUTO_PR_TOKEN`,
  `AUTO_PR_FORK_NAME`, plus GitLab built-ins (`CI_API_V4_URL`, `CI_PROJECT_ID`, `CI_JOB_ID`,
  `GITBOT_*`) — see [12](12-ci-integration.md).

## 5. Path resolution conventions

- `workingDir`, `pullDir`, install dirs are canonicalized with `readlink -m` (no existence requirement).
- "inside of" checks use `realpath -m` + string-prefix comparison (see
  [02](02-cli-and-argument-parsing.md) §4).
- Targets in `pulled.tsv` are stored **relative to the working directory** so the ledger is portable
  across machines and absolute locations.

## 6. Bash-specific behaviours that affect semantics

- `set -euo pipefail` + `shopt -s inherit_errexit` everywhere: any unguarded command failure aborts; this
  underlies the many `|| die`/`|| return $?` patterns. A re-implementation should treat each shelled-out
  command's failure as fatal unless the reference explicitly tolerates it (`|| true`).
- The reference uses transient file descriptors (`withCustomOutputInput`, fds 5/6/7/8/20/21) to iterate
  `pulled.tsv` while simultaneously running sub-pulls that themselves read files; the net effect is simply
  "iterate the ledger, calling a callback per row" — re-implementations can use ordinary iteration.
- Argument arrays from `pull.args` are built with `eval 'args+=(<line>)'`, i.e. shell word-splitting with
  quote handling (see [01](01-concepts-and-data-model.md) §3).

## 7. Platform support

- Officially tested: Ubuntu 22.04 & 24.04, bash 5.x.
- Other distros may work with the right packages (Alpine: `apk add bash git gnupg perl coreutils` to make
  `gt update` work; other commands may need more).
- BSD/macOS: `date` lacks GNU `%3N`; `timestampInMs` falls back to `gdate`, then `perl`, then
  seconds-with-`000`. A re-implementation should compute millisecond timestamps natively.

## 8. Out of scope (explicitly not features of gt)

To bound the spec (per the task's "covers all current features but not more"):
- No dependency resolution between pulled files.
- No pulling from arbitrary branches or commit SHAs — **tags only**.
- No pushing changes back to remotes.
- No partial-line editing of pulled files except via placeholders/hooks.
- No lockfile/parallelism guarantees beyond what git/gpg provide.
