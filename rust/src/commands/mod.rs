//! Command implementations for the `gt` tool.
//!
//! Currently only [`remote`] is implemented. Further commands (`pull`, `update`,
//! ...) can be added as sibling modules and wired up in `main.rs`.

pub mod remote;
