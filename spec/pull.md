# gt pull - Specification

## Overview

The `gt pull` command pulls files or directories from a configured remote repository at a specific tag, with GPG verification.


## Pull Workflow

```mermaid
sequenceDiagram
    participant User
    participant gt-pull
    participant Git
    participant GPG
    participant FileSystem

    User->>gt-pull: gt pull -r <remote> -t <tag> -p <path>
    gt-pull->>FileSystem: Read local pull.args defined for remote <remote>
    gt-pull->>FileSystem: Merge arguments with command-line
    gt-pull->>FileSystem: Create pull directory if needed
    gt-pull->>GPG: Check/initialize GPG directory
    alt GPG not set up
        GPG->>FileSystem: Import signing-key.public.asc
        alt --auto-trust true
            GPG-->>gt-pull: Auto-trust keys
        else
            GPG-->>gt-pull: User confirms trust
        end
    end
    gt-pull->>Git: Fetch tag from remote
    gt-pull->>Git: Checkout tag and path
    alt --unsecure-no-verification is set
		GPG-->>gt-pull: Skip verification entirely
	else
    	alt file with signature
			Git->>FileSystem: Checkout file.sig
			gt-pull->>GPG: Verify signature
			GPG-->>gt-pull: Verification result
			alt verification fails
				GPG-->>User: Error: verification failed
			end
		else
			alt --unsecure is set
				GPG-->>gt-pull: Proceed without .sig file
			else
				GPG-->>User: Error: .sig file missing and no unsecure flags set
			end
		end
    end
    gt-pull->>FileSystem: Execute pull-hook before
    gt-pull->>FileSystem: Move file to target
    gt-pull->>FileSystem: Execute pull-hook after
    gt-pull->>FileSystem: Update pulled.tsv
    gt-pull-->>User: Success
```

---

## Detailed Workflow Steps

### 1. Argument Parsing

Arguments are parsed in two phases:

1. **First parse**: Extract `workingDir` and `remote` to locate `pull.args`
2. **Second parse**: Merge stored arguments with command-line arguments

```bash
# Read stored arguments from pull.args
while read -r line; do
    eval 'args+=('"$line"');'
done <"$pullArgsFile"

# Parse with merged arguments
parseArguments params "$examples" "$GT_VERSION" "${args[@]}"
```

### 2. GPG Setup

```mermaid
graph TD
    A[Start Pull] --> B{GPG Dir exists?}
    B -->|No| C{signing-key.asc exists?}
    B -->|Yes| D{Check key revocation}
    C -->|Yes| E[Import key]
    C -->|No| F{--unsecure true?}
    E --> G{Import successful?}
    G -->|Yes| H[Proceed with pull]
    G -->|No| I{--unsecure true?}
    I -->|Yes| H
    I -->|No| J[Error: Key import failed]
    F -->|Yes| K[Skip verification]
    F -->|No| L[Error: No signing key]
    D --> M{Key revoked?}
    M -->|Yes| N[Error: Key revoked]
    M -->|No| H
    K --> H
```

### 3. File Checkout

1. Fetch the specified tag from remote:
   ```bash
   gitFetchTagFromRemote "$remote" "$repo" "$tagToPull"
   ```

2. Checkout the file/directory:
   ```bash
   git -C "$repo" checkout "tags/$tagToPull" -- "$path"
   ```

3. For files, also fetch signature:
   ```bash
   git -C "$repo" checkout "tags/$tagToPull" -- "$path.sig"
   ```

### 4. Verification

For each file:

```bash
if [[ $doVerification == true ]]; then
    if [[ -f "$sigFile" ]]; then
        gpg --homedir "$gpgDir" --verify "$sigFile" "$absoluteFile"
        
        # Check for key revocation
        keyData=$(getSigningGpgKeyData "$sigFile" "$gpgDir")
        keyId=$(extractGpgKeyIdFromKeyData "$keyData")
        isGpgKeyInKeyDataRevoked "$keyData"
    else
        if [[ $unsecureNoVerification == true ]]; then
            # Skip verification entirely
            echo "Skipping verification due to --unsecure-no-verification"
        elif [[ $unsecure == true ]]; then
            # Proceed without .sig file
            echo "Proceeding without .sig file due to --unsecure"
        else
            # Error: .sig file missing and no unsecure flags set
            echo "Error: .sig file missing and no unsecure flags set"
            exit 1
        fi
    fi
fi
```

### 5. File Processing

For each file found in the checkout:

```mermaid
graph TD
    A[Find files] --> B{File is signature?}
    B -->|Yes| C[Skip]
    B -->|No| D{Verification enabled?}
    D -->|Yes| E{Has .sig file?}
    D -->|No| F[Move file]
    E -->|Yes| G[Verify signature]
    E -->|No| H{--unsecure-no-verification?}
    G --> I{Valid?}
    I -->|Yes| F
    I -->|No| J[Skip file]
    H -->|Yes| F
    H -->|No| K{--unsecure?}
    K -->|Yes| F
    K -->|No| L[Skip file, error]
    F --> L[Execute before hook]
    L --> M[Check placeholders]
    M -->|Has placeholders| N[Replace placeholders]
    M -->|No placeholders| O[Move file]
    N --> O
    O --> P[Execute after hook]
    P --> Q[Update pulled.tsv]
```

### 6. pulled.tsv Update

Entry format:
```
<tag>\t<file>\t<relativeTarget>\t<tagFilter>\t<hasPlaceholder>\t<sha512>
```

Logic:
- **New file**: Append entry
- **Existing file, different tag**: Replace entry, warn
- **Existing file, same tag, different SHA**: Warn and skip
- **Existing file, same tag, same SHA**: Overwrite

---

## Pull Hooks

### Before Hook

Executed before moving file to target:

```bash
function gt_pullHook_<REMOTE>_before() {
    local -r tag=$1 source=$2 target=$3
    # Modify source file before move
}
```

### After Hook

Executed after moving file to target:

```bash
function gt_pullHook_<REMOTE>_after() {
    local -r tag=$1 source=$2 target=$3
    # Modify target file after move
}
```

### Hook Location

`.gt/remotes/<REMOTE>/pull-hook.sh`

---

## Placeholder Replacement

When updating files with placeholders:

```mermaid
graph TD
    A[File has placeholders] --> B{Tag changed?}
    B -->|No| C[Skip replacement]
    B -->|Yes| D[Extract placeholders from current file]
    D --> E[Extract placeholders from original tag]
    E --> F[Compare each placeholder]
    F --> G{Content changed?}
    G -->|Yes| H[Keep user version]
    G -->|No| I[Use remote version]
    H --> J[Write to temp file]
    I --> J
    J --> K[Replace original with temp]
```

---

## Examples

```bash
# Pull specific file at specific tag
gt pull -r tegonal-scripts -t v0.1.0 -p src/utility/update-bash-docu.sh

# Pull directory
gt pull -r tegonal-scripts -t v0.1.0 -p src/utility/

# Pull with custom directory, chop path
gt pull -r tegonal-scripts -t v0.1.0 -d .github --chop-path true -p .github/CODE_OF_CONDUCT.md

# Pull latest version with tag filter
gt pull -r tegonal-scripts -p src/utility/checks.sh --tag-filter "^v3.*"

# Auto-trust GPG keys
gt pull -r tegonal-scripts --auto-trust true -p src/utility/checks.sh

# Pull without GPG verification
gt pull -r tegonal-scripts --unsecure true -p src/utility/checks.sh

# Rename file during pull
gt pull -r tegonal-scripts -p src/utility/ask.sh --target-file-name asking.sh
```

---

## Verification States

| State | doVerification | Description |
|-------|----------------|-------------|
| Full verification | `true` | Verify signatures, check key revocation |
| Unsecure | `false` | Skip verification, no GPG setup required |
| Unsecure-no-verification | `false` | Skip verification even if GPG is available |

---

## Error Handling

| Error Condition | Exit Code | Message |
|-----------------|-----------|---------|
| Working directory missing | 1 | Exit if working directory does not exist |
| Remote not found | 1 | Remote directory does not exist |
| Path outside current dir | 1 | Target path is outside current directory |
| No signature file | 1 | File has no .sig (unless --unsecure) |
| GPG verification failed | 1 | Signature verification failed |
| Key revoked | 1 | Signing key has been revoked |
| Checkout failed | 1 | Tag or path does not exist |
| Pull hook failed | 1 | Before/after hook returned error |

---

## Performance Considerations

1. **Git checkout**: Only fetches requested tag, not entire history
2. **Signature verification**: Per-file GPG verification
3. **Placeholder detection**: Single grep per file
4. **SHA calculation**: SHA-512 computed once per file

---

## Side Effects

1. Creates pull directory structure
2. Initializes GPG directory (if needed)
3. Updates `pulled.tsv`
4. Moves files from temp location to target
5. Executes pull hooks
