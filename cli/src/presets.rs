//! Permission preset expansion.
//!
//! A preset is a YAML file under `config-presets/` shipped with PDS. Each
//! entry is annotated: `{pattern, verb, scope, reason}`. User config
//! references presets by name; pds-sync expands them into the flat
//! allow/ask/deny lists that Claude Code's settings.json understands.

use std::path::Path;

use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PresetFile {
    pub name: String,
    #[serde(default)]
    pub description: Option<String>,
    #[serde(default)]
    pub entries: Vec<PresetEntry>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PresetEntry {
    /// Match pattern (e.g. "Bash(git:*)", "Read(~/.claude/**)").
    pub pattern: String,
    /// Which list this entry lands in: allow, ask, or deny.
    pub verb: Verb,
    /// Where this rule should be written: user-scope, project-scope, or both.
    #[serde(default = "default_scope")]
    pub scope: Scope,
    /// Human-readable justification. Not emitted to settings.json — lives
    /// only in the preset source for auditability.
    pub reason: String,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum Verb {
    Allow,
    Ask,
    Deny,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum Scope {
    User,
    Project,
    Both,
}

fn default_scope() -> Scope {
    Scope::User
}

pub fn load_preset(dir: &Path, name: &str) -> Result<PresetFile> {
    let path = dir.join(format!("{}.yaml", name));
    let text = std::fs::read_to_string(&path)
        .with_context(|| format!("loading preset {}", path.display()))?;
    let preset: PresetFile = serde_yaml::from_str(&text)
        .with_context(|| format!("parsing preset {}", path.display()))?;
    Ok(preset)
}

/// Result of expanding a list of preset names + user overrides into flat
/// allow/ask/deny lists, split by scope.
#[derive(Debug, Default)]
pub struct ExpandedPermissions {
    pub user_allow: Vec<String>,
    pub user_ask: Vec<String>,
    pub user_deny: Vec<String>,
    pub project_allow: Vec<String>,
    pub project_ask: Vec<String>,
    pub project_deny: Vec<String>,
}

impl ExpandedPermissions {
    pub fn add(&mut self, entry: &PresetEntry) {
        let (user_list, project_list) = match entry.verb {
            Verb::Allow => (&mut self.user_allow, &mut self.project_allow),
            Verb::Ask => (&mut self.user_ask, &mut self.project_ask),
            Verb::Deny => (&mut self.user_deny, &mut self.project_deny),
        };
        match entry.scope {
            Scope::User => push_unique(user_list, &entry.pattern),
            Scope::Project => push_unique(project_list, &entry.pattern),
            Scope::Both => {
                push_unique(user_list, &entry.pattern);
                push_unique(project_list, &entry.pattern);
            }
        }
    }

    pub fn add_raw(&mut self, verb: Verb, pattern: &str) {
        let list = match verb {
            Verb::Allow => &mut self.user_allow,
            Verb::Ask => &mut self.user_ask,
            Verb::Deny => &mut self.user_deny,
        };
        push_unique(list, pattern);
    }

    pub fn sort(&mut self) {
        for list in [
            &mut self.user_allow,
            &mut self.user_ask,
            &mut self.user_deny,
            &mut self.project_allow,
            &mut self.project_ask,
            &mut self.project_deny,
        ] {
            list.sort();
            list.dedup();
        }
    }
}

fn push_unique(list: &mut Vec<String>, s: &str) {
    if !list.iter().any(|existing| existing == s) {
        list.push(s.to_string());
    }
}
