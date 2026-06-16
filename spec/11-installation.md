# 11 — Installation (`install.sh`)

`install.sh` downloads a chosen (or latest) tag of `gt`, verifies all signed files against gt's **current**
public key (from the `main` branch), checks that the signing key was not revoked, and installs it,
optionally creating a symlink and zsh completion. `gt self-update` ([09](09-command-self-update.md)) runs
a copy of this script.

## CLI

```
install.sh [-t|--tag <tag>] [-d|--directory <dir>] [-ln <symlink-path>] [--root]
```

| Option | Default | Meaning |
|--------|---------|---------|
| `-t\|--tag` | latest tag of `github.com/tegonal/gt` | tag to install |
| `-d\|--directory` | `$HOME/.local/lib/gt` | installation directory |
| `-ln` | `$HOME/.local/bin/gt` (only when `-d` not given) | symlink path to create |
| `--root` | — | explicitly allow running as root |

Argument rules:
- Uses a hand-rolled `case` parser (not the gt argument parser). Each value-taking option requires a
  following value (`exitIfValueMissing`), else `die`. Unknown option/argument → `die` with usage help.
- **Root policy:** running as root (`EUID == 0`) without `--root` → `die`; `--root` without being root →
  `die`.
- A symlink (`-ln`) may only be specified together with a custom directory (`-d`); otherwise `die`.
- If no directory is given: default dir `$HOME/.local/lib/gt`; and if no symlink given either, default
  symlink `$HOME/.local/bin/gt`. If a directory **is** given but no symlink, **no** symlink is created.
- `installDir` is canonicalized with `readlink -m`. A relative `symbolicLink` is made absolute against the
  current dir.
- Latest tag determination: `git ls-remote --refs --tags <repoUrl>` → field 3 → `sort --version-sort` →
  last.

## Workflow

```mermaid
flowchart TD
    A[check git installed] --> B[parse args; resolve tag, installDir, symlink, root policy]
    B --> C{tag matches<br/>^v[0-9]+.[0-9]+.[0-9]+&#40;-RC[0-9]+&#41;?$}
    C -- no --> die1[die]
    C -- yes --> D[mktemp tmpDir: gpg/ and repo/; trap cleanup]
    D --> E["cd repo; git init; git remote add origin repoUrl;<br/>git fetch --depth=1 origin &lt;tag&gt;; git checkout -b &lt;tag&gt; FETCH_HEAD"]
    E --> F["fetch CURRENT public key from main branch via wget/curl;<br/>gpg --import into tmp gpg store"]
    F --> G[[for each *.sig under repo,<br/>excluding signing-key sig & remotes' public-keys sigs]]
    G --> H{gpg --verify sig against file}
    H -- fail --> die2[print failure → return 2]
    H -- ok --> I{signing key revoked?<br/>&#40;check once per distinct key id&#41;}
    I -- yes --> die3[error → return 3]
    I -- no --> G
    G --> J{installDir already exists?}
    J -- yes --> K[show current tag; deleteDirChmod777 installDir; rm old symlink]
    J -- no --> L
    K --> L[mkdir -p parent; mv repo → installDir]
    L --> M{symlink requested?}
    M -- yes --> N["ln -sf installDir/src/gt.sh symlink (sudo fallback)"]
    M -- no --> O[info: no symlink]
    N --> P[zsh completion install &#40;if zsh + vendor-completions found&#41;]
    O --> P
    P --> Q{symlink requested?}
    Q -- yes --> R["test: run `gt --help`; on failure print PATH guidance → exit 1"]
    Q -- no --> S[SUCCESS]
    R --> S
```

### Verification specifics (the security core)

- The chosen tag's files are verified against the **current** (main-branch) public key — not the key as
  it existed at that tag. So an install only succeeds if the chosen version's signatures are still valid
  under today's key.
- Excluded from verification: `.gt/signing-key.public.asc.sig` (the key's own sig) and
  `.gt/remotes/*/public-keys/*.sig` (consumer remote keys).
- For each distinct signing key id encountered, gt checks revocation via
  `gpg --list-keys --with-colons` looking for `^(sub|pub):r:`; a revoked key → abort with **exit `3`**.
- A failed signature check → abort with **exit `2`**.
- These two non-`1` exit codes are specific to `install.sh`.

### Post-install

- **Symlink:** `ln -sf <installDir>/src/gt.sh <symlink>`, falling back to `sudo` if needed. If an old
  install existed, its symlink is removed first.
- **zsh completion:** if zsh is detected and a `*vendor-completions` directory is found in zsh's `$fpath`,
  copy `src/install/zsh/_gt` there via `sudo` and reload `compinit`. Failure is non-fatal (logged).
- **Smoke test:** if a symlink was created, run `gt --help`; on failure, print PATH guidance (special-
  casing the zsh-with-`~/.local/bin` situation) and `exit 1`.

## Recommended bootstrap (from README)

The documented one-liner downloads `signing-key.public.asc` + `.sig` from `main`, verifies the key against
the user's gpg store, imports it into a throwaway store, downloads `install.sh` + `.sig` for the chosen
tag, verifies, then runs `install.sh`, cleaning up the temp dir. This bootstrap is what
`src/install/include-install-doc.sh` keeps in sync across the README, the GitHub workflow, and the GitLab
job (it injects the canonical `install.doc.sh` between `# see install.doc.sh` / `# end install.doc.sh`
markers). See [12](12-ci-integration.md).

## Platform notes

Tested on Ubuntu 22.04/24.04 with bash 5.x. Requires `git`; uses `wget` or (fallback) `curl`, `gpg`,
`sort --version-sort`, `readlink -m`, and (optionally) `zsh`/`sudo`. On Alpine, `gt update` needs
`bash git gnupg perl coreutils`. See [14](14-dependencies-and-environment.md).
