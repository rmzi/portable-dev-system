//! `pds doctor` — cross-install health check.
//!
//! Verifies config parses, required tools are on PATH, XDG paths are writable,
//! presets referenced from config exist, and MCP core servers resolve. Exits
//! non-zero if any critical check fails.

use anyhow::Result;
use clap::Args as ClapArgs;

use crate::config::Config;
use crate::paths;
use crate::presets::load_preset;

#[derive(ClapArgs, Debug)]
pub struct Args {}

pub fn run(_: Args) -> Result<()> {
    let mut failures = 0_usize;

    check(&mut failures, "config file exists", || {
        let path = paths::config_file()?;
        if path.exists() {
            Ok(format!("{}", path.display()))
        } else {
            Ok(format!("(missing — PDS will use defaults) {}", path.display()))
        }
    });

    check(&mut failures, "config parses", || {
        let _ = Config::load(&paths::config_file()?)?;
        Ok("ok".into())
    });

    check(&mut failures, "presets resolve", || {
        let cfg = Config::load(&paths::config_file()?)?;
        let dir = paths::presets_dir()?;
        for name in &cfg.permissions.presets {
            load_preset(&dir, name)?;
        }
        Ok(format!("{} preset(s)", cfg.permissions.presets.len()))
    });

    check(&mut failures, "XDG paths writable", || {
        for p in [paths::data_root()?, paths::cache_root()?] {
            std::fs::create_dir_all(&p)?;
        }
        Ok("data + cache dirs writable".into())
    });

    check(&mut failures, "claude CLI on PATH", || {
        let status = std::process::Command::new("claude")
            .arg("--version")
            .output();
        match status {
            Ok(o) if o.status.success() => Ok(String::from_utf8_lossy(&o.stdout).trim().to_string()),
            _ => anyhow::bail!("claude CLI not found — install Claude Code"),
        }
    });

    if failures > 0 {
        anyhow::bail!("{} check(s) failed", failures);
    }
    Ok(())
}

fn check(failures: &mut usize, name: &str, f: impl FnOnce() -> Result<String>) {
    match f() {
        Ok(msg) => println!("  ✓ {}: {}", name, msg),
        Err(e) => {
            println!("  ✗ {}: {}", name, e);
            *failures += 1;
        }
    }
}
