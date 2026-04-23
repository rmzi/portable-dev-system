//! XDG path resolution.
//!
//! Every PDS filesystem location flows through this module so the layout is
//! declared in exactly one place. Federation-facing: this is the first
//! candidate to extract into a shared `federation-xdg` crate once we
//! migrate the CLI into the monorepo.

use std::path::PathBuf;

use anyhow::{Context, Result};

pub fn config_home() -> Result<PathBuf> {
    if let Ok(p) = std::env::var("XDG_CONFIG_HOME") {
        if !p.is_empty() {
            return Ok(PathBuf::from(p));
        }
    }
    Ok(dirs::home_dir().context("no home dir")?.join(".config"))
}

pub fn data_home() -> Result<PathBuf> {
    if let Ok(p) = std::env::var("XDG_DATA_HOME") {
        if !p.is_empty() {
            return Ok(PathBuf::from(p));
        }
    }
    Ok(dirs::home_dir()
        .context("no home dir")?
        .join(".local")
        .join("share"))
}

pub fn cache_home() -> Result<PathBuf> {
    if let Ok(p) = std::env::var("XDG_CACHE_HOME") {
        if !p.is_empty() {
            return Ok(PathBuf::from(p));
        }
    }
    Ok(dirs::home_dir().context("no home dir")?.join(".cache"))
}

pub fn config_file() -> Result<PathBuf> {
    Ok(config_home()?.join("pds").join("config.yaml"))
}

pub fn data_root() -> Result<PathBuf> {
    Ok(data_home()?.join("pds"))
}

pub fn cache_root() -> Result<PathBuf> {
    Ok(cache_home()?.join("pds"))
}

pub fn fingerprint_file() -> Result<PathBuf> {
    Ok(cache_root()?.join("sync-fingerprint.sha256"))
}

pub fn home_claude_settings() -> Result<PathBuf> {
    Ok(dirs::home_dir()
        .context("no home dir")?
        .join(".claude")
        .join("settings.json"))
}

#[allow(dead_code)] // wired in upcoming MCP-core sync; kept here to avoid a later churn
pub fn home_claude_json() -> Result<PathBuf> {
    Ok(dirs::home_dir().context("no home dir")?.join(".claude.json"))
}

/// Global gitignore — respects `git config --global core.excludesFile` when
/// present, else defaults to `${XDG_CONFIG_HOME}/git/ignore`.
pub fn global_gitignore() -> Result<PathBuf> {
    let output = std::process::Command::new("git")
        .args(["config", "--global", "--path", "core.excludesFile"])
        .output();
    if let Ok(out) = output {
        if out.status.success() {
            let s = String::from_utf8_lossy(&out.stdout).trim().to_string();
            if !s.is_empty() {
                return Ok(PathBuf::from(shellexpand(&s)));
            }
        }
    }
    Ok(config_home()?.join("git").join("ignore"))
}

fn shellexpand(p: &str) -> String {
    if let Some(rest) = p.strip_prefix("~/") {
        if let Some(home) = dirs::home_dir() {
            return home.join(rest).to_string_lossy().into_owned();
        }
    }
    p.to_string()
}

/// Plugin root — where preset files and other shipped assets live.
/// Resolution order: CLAUDE_PLUGIN_ROOT env → PDS_PLUGIN_ROOT env → exe path walk-up.
pub fn plugin_root() -> Result<PathBuf> {
    for var in ["CLAUDE_PLUGIN_ROOT", "PDS_PLUGIN_ROOT"] {
        if let Ok(p) = std::env::var(var) {
            if !p.is_empty() {
                return Ok(PathBuf::from(p));
            }
        }
    }
    // Fallback: walk up from the binary until we find a directory containing
    // `config-presets/` — works both for the installed layout
    // (<plugin_root>/bin/pds) and the dev layout (<repo>/cli/target/debug/pds).
    let exe = std::env::current_exe()?;
    for ancestor in exe.ancestors().skip(1) {
        if ancestor.join("config-presets").is_dir() {
            return Ok(ancestor.to_path_buf());
        }
    }
    anyhow::bail!(
        "could not locate plugin root from binary path {} — set CLAUDE_PLUGIN_ROOT or PDS_PLUGIN_ROOT",
        exe.display()
    )
}

pub fn presets_dir() -> Result<PathBuf> {
    Ok(plugin_root()?.join("config-presets"))
}
