//! Command implementations for the `gt` tool.
//!
//! Currently [`remote`] and [`self_update`] are implemented. Further commands
//! (`pull`, `update`, ...) can be added as sibling modules and wired up in
//! `main.rs`.

pub mod remote;
pub mod self_update;
