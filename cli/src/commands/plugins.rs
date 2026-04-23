//! `pds plugins install` — declarative plugin install via `claude plugins install`.
//!
//! Called both as its own subcommand and implicitly from `pds sync`. Fills a
//! real gap: Claude Code has no native "install these if missing" primitive;
//! `enabledPlugins` in settings.json only toggles what's already installed.

use anyhow::{Context, Result};
use clap::{Args as ClapArgs, Subcommand};

use crate::config::Config;
use crate::paths;

#[derive(ClapArgs, Debug)]
pub struct Args {
    #[command(subcommand)]
    pub action: Action,
}

#[derive(Subcommand, Debug)]
pub enum Action {
    /// Install plugins listed in config.plugins.install.
    Install {
        #[arg(long)]
        dry_run: bool,
    },
    /// List currently-installed plugins per `claude plugins list`.
    List,
}

pub fn run(args: Args) -> Result<()> {
    let cfg = Config::load(&paths::config_file()?)?;
    match args.action {
        Action::Install { dry_run } => {
            apply(&cfg, dry_run)?;
            Ok(())
        }
        Action::List => {
            let status = std::process::Command::new("claude")
                .args(["plugins", "list"])
                .status()
                .context("running `claude plugins list` — is the Claude Code CLI on PATH?")?;
            if !status.success() {
                anyhow::bail!("claude plugins list failed");
            }
            Ok(())
        }
    }
}

/// Apply `config.plugins.install` by shelling out to `claude plugins install`.
/// Idempotent: skips plugins already present. Returns true if any install ran.
pub fn apply(cfg: &Config, dry_run: bool) -> Result<bool> {
    if cfg.plugins.install.is_empty() {
        return Ok(false);
    }
    let installed = list_installed().unwrap_or_default();
    let mut did_work = false;
    for plugin in &cfg.plugins.install {
        if installed.iter().any(|i| i == plugin) {
            continue;
        }
        println!("plugins: would install {}", plugin);
        did_work = true;
        if !dry_run {
            let status = std::process::Command::new("claude")
                .args(["plugins", "install", plugin])
                .status()
                .with_context(|| format!("running `claude plugins install {}`", plugin))?;
            if !status.success() {
                anyhow::bail!("claude plugins install {} failed", plugin);
            }
        }
    }
    Ok(did_work)
}

fn list_installed() -> Result<Vec<String>> {
    let out = std::process::Command::new("claude")
        .args(["plugins", "list", "--format", "json"])
        .output()
        .context("running `claude plugins list --format json`")?;
    if !out.status.success() {
        // Fallback: `claude plugins list` (plain text). Best-effort parse.
        return Ok(Vec::new());
    }
    let v: serde_json::Value = serde_json::from_slice(&out.stdout).unwrap_or_default();
    let items = match v {
        serde_json::Value::Array(a) => a,
        serde_json::Value::Object(obj) => obj
            .get("plugins")
            .and_then(|x| x.as_array())
            .cloned()
            .unwrap_or_default(),
        _ => vec![],
    };
    Ok(items
        .into_iter()
        .filter_map(|item| match item {
            serde_json::Value::String(s) => Some(s),
            serde_json::Value::Object(o) => o
                .get("name")
                .and_then(|x| x.as_str())
                .map(|s| s.to_string()),
            _ => None,
        })
        .collect())
}
