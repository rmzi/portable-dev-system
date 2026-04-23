//! What PDS remembers about its own writes.
//!
//! Claude Code's `settings.json` is shared ground: team-scope files, manual
//! user edits, and PDS-managed entries all land in the same arrays. When a
//! preset is dropped from config, PDS needs to remove the entries *it* put
//! there without touching anything else. That requires state: the last set
//! of entries PDS wrote, persisted across invocations.
//!
//! Stored at `${XDG_CACHE_HOME}/pds/managed-permissions.json`. Missing file
//! = no prior managed state (first sync or post-cache-clear) — treated as
//! "PDS has never written here," so nothing is removed.

use std::path::PathBuf;

use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};

use crate::paths;

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct ManagedPermissions {
    #[serde(default)]
    pub user_allow: Vec<String>,
    #[serde(default)]
    pub user_ask: Vec<String>,
    #[serde(default)]
    pub user_deny: Vec<String>,
    #[serde(default)]
    pub project_allow: Vec<String>,
    #[serde(default)]
    pub project_ask: Vec<String>,
    #[serde(default)]
    pub project_deny: Vec<String>,
}

fn state_file() -> Result<PathBuf> {
    Ok(paths::cache_root()?.join("managed-permissions.json"))
}

pub fn load() -> Result<ManagedPermissions> {
    let path = state_file()?;
    if !path.exists() {
        return Ok(ManagedPermissions::default());
    }
    let text = std::fs::read_to_string(&path)
        .with_context(|| format!("reading {}", path.display()))?;
    let state: ManagedPermissions = serde_json::from_str(&text)
        .with_context(|| format!("parsing {}", path.display()))?;
    Ok(state)
}

pub fn save(state: &ManagedPermissions) -> Result<()> {
    let path = state_file()?;
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    let text = serde_json::to_string_pretty(state)?;
    std::fs::write(&path, text)
        .with_context(|| format!("writing {}", path.display()))?;
    Ok(())
}
