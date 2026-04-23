use anyhow::Result;
use clap::{Parser, Subcommand};

mod commands;
mod config;
mod diff;
mod managed_state;
mod paths;
mod presets;

#[derive(Parser)]
#[command(
    name = "pds",
    version,
    about = "Portable Development System — user-preference sync CLI",
    long_about = "pds reads ${XDG_CONFIG_HOME:-~/.config}/pds/config.yaml and fans it out \
                  to the sinks Claude Code consumes: ~/.claude/settings.json, \
                  ~/.claude.json, core.excludesFile, and per-project .claude/settings.json seeds."
)]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    /// Fan config.yaml out to Claude Code settings sinks. Default is dry-run.
    Sync(commands::sync::Args),
    /// Read a value from config.yaml. Designed for hook scripts: `pds config get health.serious_min`.
    Config(commands::config::Args),
    /// Promote local-hot diary/telemetry/journal files to S3.
    Archive(commands::archive::Args),
    /// Run install-health checks across config, paths, deps.
    Doctor(commands::doctor::Args),
    /// Install plugins listed in config.plugins.install via `claude plugins install`.
    Plugins(commands::plugins::Args),
    /// Consolidate pre-journal-layout data (per-repo shepherd journals, ephemeral diary temp files) into the journal root.
    Migrate(commands::migrate::Args),
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    match cli.command {
        Command::Sync(args) => commands::sync::run(args),
        Command::Config(args) => commands::config::run(args),
        Command::Archive(args) => commands::archive::run(args),
        Command::Doctor(args) => commands::doctor::run(args),
        Command::Plugins(args) => commands::plugins::run(args),
        Command::Migrate(args) => commands::migrate::run(args),
    }
}
