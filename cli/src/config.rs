//! pds.config.yaml schema + loader.
//!
//! Types mirror the final schema from the plan. Every optional field is
//! `Option<T>` or carries a `#[serde(default)]` — absence of any key means
//! "PDS default", matching the plan's degrade-gracefully constraint.

use std::path::Path;

use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};

pub const SCHEMA_VERSION: u32 = 1;

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub struct Config {
    #[serde(default = "default_version")]
    pub version: u32,
    #[serde(default)]
    pub permissions: Permissions,
    #[serde(default)]
    pub shepherd: Shepherd,
    #[serde(default)]
    pub capture: Capture,
    #[serde(default)]
    pub health: Health,
    #[serde(default)]
    pub hints: Hints,
    #[serde(default, rename = "claude_md")]
    pub claude_md: ClaudeMd,
    #[serde(default)]
    pub session: Session,
    #[serde(default)]
    pub worktree: Worktree,
    #[serde(default)]
    pub input: Input,
    #[serde(default)]
    pub plugins: Plugins,
    #[serde(default)]
    pub mcp: Mcp,
    #[serde(default)]
    pub gitignore: Gitignore,
}

fn default_version() -> u32 {
    SCHEMA_VERSION
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub struct Permissions {
    #[serde(default)]
    pub presets: Vec<String>,
    #[serde(default)]
    pub allow: Vec<String>,
    #[serde(default)]
    pub ask: Vec<String>,
    #[serde(default)]
    pub deny: Vec<String>,
    #[serde(default = "default_write_target")]
    pub write_target: WriteTarget,
}

fn default_write_target() -> WriteTarget {
    WriteTarget::UserPlusProjectSeed
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum WriteTarget {
    UserOnly,
    UserPlusProjectSeed,
}

impl Default for WriteTarget {
    fn default() -> Self {
        Self::UserPlusProjectSeed
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Shepherd {
    #[serde(default = "default_shepherd_tiers")]
    pub tiers: Vec<String>,
}

impl Default for Shepherd {
    fn default() -> Self {
        Self {
            tiers: default_shepherd_tiers(),
        }
    }
}

fn default_shepherd_tiers() -> Vec<String> {
    vec!["med".into(), "heavy".into()]
}

/// Knowledge capture config.
///
/// One toggle, one directory (`$XDG_DATA_HOME/pds/journal/`). Session
/// transcripts, telemetry events, and shepherd consultations are all entry
/// types in the same journal — not sibling streams that can diverge.
/// Granular sub-toggles (`journal.streams.telemetry: false`) can be added
/// later if a real need shows up; start simple.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Capture {
    /// Capture session transcripts, telemetry events, and shepherd
    /// consultations into the journal. Off means no capture at all.
    #[serde(default = "default_true")]
    pub journal: bool,
    #[serde(default)]
    pub retention: Retention,
    #[serde(default)]
    pub s3: S3,
}

impl Default for Capture {
    fn default() -> Self {
        Self {
            journal: true,
            retention: Retention::default(),
            s3: S3::default(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Retention {
    #[serde(default = "default_30")]
    pub local_hot_days: u32,
    #[serde(default = "default_30")]
    pub s3_standard_days: u32,
}

impl Default for Retention {
    fn default() -> Self {
        Self {
            local_hot_days: 30,
            s3_standard_days: 30,
        }
    }
}

fn default_30() -> u32 {
    30
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub struct S3 {
    #[serde(default)]
    pub enabled: bool,
    #[serde(default)]
    pub bucket: Option<String>,
    #[serde(default = "default_region")]
    pub region: String,
}

fn default_region() -> String {
    "us-east-1".into()
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Health {
    #[serde(default = "default_serious")]
    pub serious_min: u32,
    #[serde(default = "default_very_serious")]
    pub very_serious_min: u32,
    #[serde(default = "default_idle_reset")]
    pub idle_reset_min: u32,
    #[serde(default = "default_very_serious_action")]
    pub very_serious_action: VerySeriousAction,
    #[serde(default = "default_health_sources")]
    pub sources: Vec<HealthSource>,
}

impl Default for Health {
    fn default() -> Self {
        Self {
            serious_min: 90,
            very_serious_min: 180,
            idle_reset_min: 15,
            very_serious_action: VerySeriousAction::Ack,
            sources: default_health_sources(),
        }
    }
}

fn default_serious() -> u32 {
    90
}
fn default_very_serious() -> u32 {
    180
}
fn default_idle_reset() -> u32 {
    15
}
fn default_very_serious_action() -> VerySeriousAction {
    VerySeriousAction::Ack
}
fn default_health_sources() -> Vec<HealthSource> {
    vec![HealthSource::Session, HealthSource::Rolling]
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum VerySeriousAction {
    Ack,
    Reminder,
    Pause,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum HealthSource {
    Session,
    Rolling,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Hints {
    #[serde(default = "default_true")]
    pub enabled: bool,
    #[serde(default = "default_true")]
    pub hit_rate_decay: bool,
    #[serde(default = "default_decay_ignores")]
    pub decay_after_ignores: u32,
}

impl Default for Hints {
    fn default() -> Self {
        Self {
            enabled: true,
            hit_rate_decay: true,
            decay_after_ignores: 3,
        }
    }
}

fn default_decay_ignores() -> u32 {
    3
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ClaudeMd {
    #[serde(default = "default_true")]
    pub manage_section: bool,
}

impl Default for ClaudeMd {
    fn default() -> Self {
        Self {
            manage_section: true,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Session {
    #[serde(default = "default_sticky_skills")]
    pub sticky_skills: Vec<String>,
}

impl Default for Session {
    fn default() -> Self {
        Self {
            sticky_skills: default_sticky_skills(),
        }
    }
}

fn default_sticky_skills() -> Vec<String> {
    vec!["ethos".into(), "voice".into(), "lexicon".into()]
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub struct Worktree {
    #[serde(default)]
    pub protected_branches: Vec<String>,
    #[serde(default)]
    pub cleanup: WorktreeCleanup,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct WorktreeCleanup {
    #[serde(default = "default_true")]
    pub enabled: bool,
    #[serde(default = "default_30")]
    pub age_days: u32,
    #[serde(default = "default_cleanup_mode")]
    pub mode: CleanupMode,
}

impl Default for WorktreeCleanup {
    fn default() -> Self {
        Self {
            enabled: true,
            age_days: 30,
            mode: default_cleanup_mode(),
        }
    }
}

fn default_cleanup_mode() -> CleanupMode {
    CleanupMode::Prompt
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum CleanupMode {
    Prompt,
    AutoAfterEphemeraAttached,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Input {
    #[serde(default = "default_modality")]
    pub modality: Modality,
}

impl Default for Input {
    fn default() -> Self {
        Self {
            modality: default_modality(),
        }
    }
}

fn default_modality() -> Modality {
    Modality::NumpadFriendly
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "kebab-case")]
pub enum Modality {
    NumpadFriendly,
    Voice,
    Rich,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub struct Plugins {
    #[serde(default)]
    pub install: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Mcp {
    #[serde(default = "default_mcp_core")]
    pub core: Vec<String>,
}

impl Default for Mcp {
    fn default() -> Self {
        Self {
            core: default_mcp_core(),
        }
    }
}

fn default_mcp_core() -> Vec<String> {
    vec![
        "pds-advisor".into(),
        "claude-mem-search".into(),
        "zaku".into(),
        "haro".into(),
    ]
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Gitignore {
    #[serde(default = "default_true")]
    pub apply_global: bool,
    #[serde(default = "default_gitignore_paths")]
    pub paths: Vec<String>,
}

impl Default for Gitignore {
    fn default() -> Self {
        Self {
            apply_global: true,
            paths: default_gitignore_paths(),
        }
    }
}

fn default_gitignore_paths() -> Vec<String> {
    vec![
        ".claude/swarm/".into(),
        ".claude/plans/".into(),
        "journal/".into(),
    ]
}

fn default_true() -> bool {
    true
}

impl Config {
    /// Load pds.config.yaml. Missing file returns a config with all schema
    /// defaults filled in — routed through a YAML round-trip so serde's
    /// field-level `default = "..."` attributes fire.
    pub fn load(path: &Path) -> Result<Self> {
        if !path.exists() {
            return Ok(Self::defaults());
        }
        let text = std::fs::read_to_string(path)
            .with_context(|| format!("reading {}", path.display()))?;
        let cfg: Config = serde_yaml::from_str(&text)
            .with_context(|| format!("parsing {}", path.display()))?;
        if cfg.version != SCHEMA_VERSION {
            anyhow::bail!(
                "{}: unsupported schema version {} (expected {})",
                path.display(),
                cfg.version,
                SCHEMA_VERSION
            );
        }
        Ok(cfg)
    }

    /// Config populated with every schema default. Equivalent to parsing an
    /// empty YAML document — honors `#[serde(default = "...")]` attributes
    /// that the `#[derive(Default)]` derivation does not.
    pub fn defaults() -> Self {
        serde_yaml::from_str("{}").expect("empty YAML is always valid")
    }
}
