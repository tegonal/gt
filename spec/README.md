# gt Specifications Index

This directory contains detailed specifications for `gt` (g(it)t(ools)), which can be used to re-implement the tool in a different language (e.g., Rust).

## Specification Files

| File | Description |
|------|-------------|
| [overview.md](overview.md) | High-level overview, directory structure, data structures, and core concepts |
| [remote.md](remote.md) | `gt remote` command specification (add, remove, list) |
| [pull.md](pull.md) | `gt pull` command specification |
| [re-pull.md](re-pull.md) | `gt re-pull` command specification |
| [reset.md](reset.md) | `gt reset` command specification |
| [update.md](update.md) | `gt update` command specification |
| [self-update.md](self-update.md) | `gt self-update` command specification |
| [internal-utilities.md](internal-utilities.md) | Internal utility functions, data structures, and constants |

## Quick Links

- **[Command Hierarchy](overview.md#command-hierarchy)** - Overview of all commands
- **[Directory Structure](overview.md#directory-structure)** - How gt organizes its files
- **[pulled.tsv Format](overview.md#pulled-tsv-format)** - Data structure for tracking pulled files
- **[GPG Verification](overview.md#security-model)** - Security model and verification process

## Usage

These specifications describe the complete functionality of gt as implemented in the Bash source code. Each specification includes:

- Command parameters and their meanings
- Workflows with Mermaid diagrams
- Example usage
- Error handling
- Implementation notes
- Relationships to other commands

## Verification Checklist

To verify completeness, ensure each command from `gt --help` is covered:

- [x] **pull** - [pull.md](pull.md)
- [x] **re-pull** - [re-pull.md](re-pull.md)
- [x] **remote** (add, remove, list) - [remote.md](remote.md)
- [x] **reset** - [reset.md](reset.md)
- [x] **update** - [update.md](update.md)
- [x] **self-update** - [self-update.md](self-update.md)

## Key Concepts

### Working Directory

All gt operations use a working directory (default: `.gt`) that stores:
- Remote configurations
- GPG keys
- Pull hooks
- State information

### GPG Verification

Every pulled file is verified:
1. Signature file (`*.sig`) is fetched
2. GPG verifies the signature
3. Signing key is checked for revocation

### Placeholders

Files can contain customizable sections:
```
# gt-placeholder-myconfig-start
# User-specific content
# gt-placeholder-myconfig-end
```

These are preserved during updates.

### Tag-based Pulling

Files are pulled from Git tags (not branches). Each file has a tag filter that determines which tags are valid during updates.
