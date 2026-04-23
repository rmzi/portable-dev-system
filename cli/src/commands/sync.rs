//! `pds sync` — the heart of the CLI.
//!
//! Reads pds.config.yaml, expands presets, computes desired content for each
//! target sink, prints diffs, and writes unless --dry-run. Enforces the TOFU
//! trust model: if the config *shape* changed since last apply, re-prompts
//! for confirmation before writing.

use std::io::{self, BufRead, Write};
use std::path::PathBuf;

use anyhow::{Context, Result};
use clap::Args as ClapArgs;
use indexmap::IndexMap;
use serde_json::Value as JsonValue;
use sha2::{Digest, Sha256};

use crate::config::{Config, WriteTarget};
use crate::diff::{atomic_write, diff_and_write};
use crate::managed_state::{self, ManagedPermissions};
use crate::paths;
use crate::presets::{load_preset, ExpandedPermissions, PresetFile, Verb};

#[derive(ClapArgs, Debug)]
pub struct Args {
    /// Preview changes without writing.
    #[arg(long)]
    pub dry_run: bool,
    /// Skip the TOFU confirmation prompt (re-apply even if shape changed).
    #[arg(long)]
    pub yes: bool,
    /// Override the config file path.
    #[arg(long, value_name = "FILE")]
    pub config: Option<PathBuf>,
    /// Skip specific phases by name (permissions, plugins, gitignore, claude_md).
    #[arg(long, value_delimiter = ',')]
    pub skip: Vec<String>,
    /// Opt in to project-scope writes for the current directory. Without this
    /// flag, pds sync only touches user-scope files — it will NOT modify
    /// tracked `.claude/settings.json` files in whatever repo you happen to
    /// be standing in, even if config.write_target is user_plus_project_seed.
    #[arg(long)]
    pub project: bool,
}

pub fn run(args: Args) -> Result<()> {
    let config_path = match args.config {
        Some(p) => p,
        None => paths::config_file()?,
    };
    let cfg = Config::load(&config_path)?;

    if !config_path.exists() {
        println!(
            "no config at {} — nothing to sync (PDS will use defaults)",
            config_path.display()
        );
        return Ok(());
    }

    let shape_fp = shape_fingerprint(&cfg);
    let stored = read_stored_fingerprint()?;
    let fingerprint_changed = stored.as_deref() != Some(shape_fp.as_str());

    if fingerprint_changed && !args.dry_run && !args.yes {
        require_confirmation(&config_path, &shape_fp, stored.as_deref())?;
    }

    let skip: std::collections::HashSet<String> =
        args.skip.iter().map(|s| s.to_lowercase()).collect();

    let mut any_changes = false;

    if !skip.contains("permissions") {
        any_changes |= sync_permissions(&cfg, args.dry_run, args.project)?;
    }
    if !skip.contains("plugins") {
        any_changes |= crate::commands::plugins::apply(&cfg, args.dry_run)?;
    }
    if !skip.contains("gitignore") {
        any_changes |= sync_gitignore(&cfg, args.dry_run)?;
    }
    if !skip.contains("claude_md") && cfg.claude_md.manage_section {
        any_changes |= sync_claude_md_section(&cfg, args.dry_run)?;
    }

    if !args.dry_run && !any_changes {
        println!("pds sync: already in sync");
    }

    if !args.dry_run {
        write_fingerprint(&shape_fp)?;
    }

    Ok(())
}

fn require_confirmation(
    config_path: &std::path::Path,
    new_fp: &str,
    stored: Option<&str>,
) -> Result<()> {
    match stored {
        Some(_) => {
            eprintln!(
                "config shape changed since last sync — review the diff above and confirm."
            );
            eprintln!("  config:       {}", config_path.display());
            eprintln!("  old shape:    {}", stored.unwrap());
            eprintln!("  new shape:    {}", new_fp);
        }
        None => {
            eprintln!("first sync on this machine — review the diff above and confirm.");
            eprintln!("  config:       {}", config_path.display());
        }
    }
    eprint!("apply? [y/N] ");
    io::stderr().flush().ok();

    let stdin = io::stdin();
    let mut line = String::new();
    stdin.lock().read_line(&mut line)?;
    if !matches!(line.trim().to_lowercase().as_str(), "y" | "yes") {
        anyhow::bail!("aborted — re-run with --yes to skip this prompt");
    }
    Ok(())
}

// ---------- Phase B: permissions ----------

fn sync_permissions(cfg: &Config, dry_run: bool, project_opt_in: bool) -> Result<bool> {
    if cfg.permissions.presets.is_empty()
        && cfg.permissions.allow.is_empty()
        && cfg.permissions.ask.is_empty()
        && cfg.permissions.deny.is_empty()
    {
        return Ok(false);
    }

    let presets_dir = paths::presets_dir()?;
    let mut expanded = ExpandedPermissions::default();

    for name in &cfg.permissions.presets {
        let preset: PresetFile = load_preset(&presets_dir, name).with_context(|| {
            format!("expanding preset '{}' (known presets live in {})", name, presets_dir.display())
        })?;
        for entry in &preset.entries {
            expanded.add(entry);
        }
    }

    for pat in &cfg.permissions.allow {
        expanded.add_raw(Verb::Allow, pat);
    }
    for pat in &cfg.permissions.ask {
        expanded.add_raw(Verb::Ask, pat);
    }
    for pat in &cfg.permissions.deny {
        expanded.add_raw(Verb::Deny, pat);
    }
    expanded.sort();

    // Load the snapshot of what PDS wrote last time, so we can *remove*
    // entries contributed by presets that have since been dropped without
    // touching user-authored entries PDS never owned.
    let prev = managed_state::load().unwrap_or_default();

    let mut changed = false;

    let user_settings = paths::home_claude_settings()?;
    let desired_user = reconcile_permissions_in_json(
        &user_settings,
        &expanded.user_allow,
        &expanded.user_ask,
        &expanded.user_deny,
        &prev.user_allow,
        &prev.user_ask,
        &prev.user_deny,
    )?;
    changed |= diff_and_write(&user_settings, &desired_user, dry_run)?;

    // Project-scope writes require BOTH a config declaration (write_target =
    // user_plus_project_seed) AND an explicit --project flag. Either alone is
    // insufficient: config is "I'm OK with this when asked", flag is "asked."
    // This prevents `pds sync` inside an arbitrary checkout from modifying the
    // repo's tracked .claude/settings.json.
    if cfg.permissions.write_target == WriteTarget::UserPlusProjectSeed && project_opt_in {
        if let Ok(pwd) = std::env::current_dir() {
            let project_settings = pwd.join(".claude").join("settings.json");
            let has_project_content = !expanded.project_allow.is_empty()
                || !expanded.project_ask.is_empty()
                || !expanded.project_deny.is_empty();
            if has_project_content
                && (project_settings.parent().map_or(false, |p| p.exists()) || dry_run)
            {
                let desired_project = reconcile_permissions_in_json(
                    &project_settings,
                    &expanded.project_allow,
                    &expanded.project_ask,
                    &expanded.project_deny,
                    &prev.project_allow,
                    &prev.project_ask,
                    &prev.project_deny,
                )?;
                changed |= diff_and_write(&project_settings, &desired_project, dry_run)?;
            }
        }
    } else if cfg.permissions.write_target == WriteTarget::UserPlusProjectSeed && !project_opt_in {
        // Loud notice the first time a user hits this: config *declared* intent,
        // but this invocation didn't *ask*, so we silently skipped. Tell them.
        eprintln!(
            "note: config declares write_target=user_plus_project_seed but --project was not passed; skipping project-scope writes for {}",
            std::env::current_dir().map(|p| p.display().to_string()).unwrap_or_else(|_| "<cwd>".into())
        );
    }

    // Persist what PDS just wrote so the next sync can compute removals
    // correctly. Don't save on dry-run (we didn't actually write anything).
    if !dry_run {
        let new_state = ManagedPermissions {
            user_allow: expanded.user_allow.clone(),
            user_ask: expanded.user_ask.clone(),
            user_deny: expanded.user_deny.clone(),
            project_allow: expanded.project_allow.clone(),
            project_ask: expanded.project_ask.clone(),
            project_deny: expanded.project_deny.clone(),
        };
        managed_state::save(&new_state)?;
    }

    Ok(changed)
}

/// Reconcile PDS-managed entries against the on-disk permissions arrays.
///
/// For each of allow/ask/deny:
///   - Remove entries that were in `prev_managed` but are no longer in `desired`.
///     These were contributed by a preset or config entry PDS wrote last time
///     and that's since been dropped.
///   - Add entries that are in `desired` but not currently in the file.
///
/// Entries outside both `prev_managed` and `desired` are PDS-unowned — left
/// alone. That's the property that keeps team edits, manual tweaks, and
/// entries from other tools safe across a `pds sync`.
#[allow(clippy::too_many_arguments)]
fn reconcile_permissions_in_json(
    path: &std::path::Path,
    desired_allow: &[String],
    desired_ask: &[String],
    desired_deny: &[String],
    prev_allow: &[String],
    prev_ask: &[String],
    prev_deny: &[String],
) -> Result<String> {
    let mut root: IndexMap<String, JsonValue> = if path.exists() {
        let text = std::fs::read_to_string(path)
            .with_context(|| format!("reading {}", path.display()))?;
        serde_json::from_str(&text)
            .with_context(|| format!("parsing {}", path.display()))?
    } else {
        IndexMap::new()
    };

    let permissions = root
        .entry("permissions".to_string())
        .or_insert_with(|| JsonValue::Object(serde_json::Map::new()));
    if let JsonValue::Object(perms) = permissions {
        reconcile_list(perms, "allow", desired_allow, prev_allow);
        reconcile_list(perms, "ask", desired_ask, prev_ask);
        reconcile_list(perms, "deny", desired_deny, prev_deny);
    }

    let mut pretty = serde_json::to_string_pretty(&root)?;
    pretty.push('\n');
    Ok(pretty)
}

fn reconcile_list(
    obj: &mut serde_json::Map<String, JsonValue>,
    key: &str,
    desired: &[String],
    prev_managed: &[String],
) {
    use std::collections::HashSet;
    let desired_set: HashSet<&str> = desired.iter().map(|s| s.as_str()).collect();
    let prev_set: HashSet<&str> = prev_managed.iter().map(|s| s.as_str()).collect();

    let entry = obj.entry(key).or_insert_with(|| JsonValue::Array(vec![]));
    if let JsonValue::Array(arr) = entry {
        // Drop entries we previously wrote that aren't wanted anymore.
        arr.retain(|v| {
            let Some(s) = v.as_str() else { return true };
            !(prev_set.contains(s) && !desired_set.contains(s))
        });
        // Add entries that are wanted but absent.
        let present: HashSet<String> = arr
            .iter()
            .filter_map(|v| v.as_str().map(|s| s.to_string()))
            .collect();
        for a in desired {
            if !present.contains(a) {
                arr.push(JsonValue::String(a.clone()));
            }
        }
        arr.sort_by(|a, b| a.as_str().unwrap_or("").cmp(b.as_str().unwrap_or("")));
    }
}

// ---------- Phase F: CLAUDE.md managed section ----------

const CLAUDE_MD_START: &str = "<!-- pds:start -->";
const CLAUDE_MD_END: &str = "<!-- pds:end -->";

fn sync_claude_md_section(cfg: &Config, dry_run: bool) -> Result<bool> {
    let Ok(pwd) = std::env::current_dir() else {
        return Ok(false);
    };
    let path = pwd.join("CLAUDE.md");
    if !path.exists() {
        return Ok(false);
    }
    let text = std::fs::read_to_string(&path)?;
    let Some((start_idx, end_idx)) = find_markers(&text) else {
        return Ok(false); // opt-in per project; no markers = skip
    };

    let managed = render_claude_md_section(cfg);
    let mut desired = String::new();
    desired.push_str(&text[..start_idx + CLAUDE_MD_START.len()]);
    desired.push('\n');
    desired.push_str(&managed);
    desired.push_str(&text[end_idx..]);

    diff_and_write(&path, &desired, dry_run)
}

fn find_markers(text: &str) -> Option<(usize, usize)> {
    let start = text.find(CLAUDE_MD_START)?;
    let end = text.find(CLAUDE_MD_END)?;
    if end <= start {
        return None;
    }
    Some((start, end))
}

fn render_claude_md_section(cfg: &Config) -> String {
    let mut s = String::new();
    s.push_str("<!-- PDS-managed block. Edit pds.config.yaml and run `pds sync` to update. -->\n\n");
    s.push_str("## PDS configuration\n\n");
    s.push_str(&format!(
        "- Shepherd tiers: {}\n",
        cfg.shepherd.tiers.join(", ")
    ));
    s.push_str(&format!(
        "- Health thresholds: serious={}min, very_serious={}min (action: {:?})\n",
        cfg.health.serious_min, cfg.health.very_serious_min, cfg.health.very_serious_action
    ));
    s.push_str(&format!("- Input modality: {:?}\n", cfg.input.modality));
    if !cfg.worktree.protected_branches.is_empty() {
        s.push_str(&format!(
            "- Protected branches: {}\n",
            cfg.worktree.protected_branches.join(", ")
        ));
    }
    if !cfg.session.sticky_skills.is_empty() {
        s.push_str(&format!(
            "- Sticky skills: {}\n",
            cfg.session.sticky_skills.join(", ")
        ));
    }
    s.push('\n');
    s
}

// ---------- gitignore ----------

fn sync_gitignore(cfg: &Config, dry_run: bool) -> Result<bool> {
    if !cfg.gitignore.apply_global {
        return Ok(false);
    }
    let path = paths::global_gitignore()?;
    let current = if path.exists() {
        std::fs::read_to_string(&path)?
    } else {
        String::new()
    };

    const BEGIN: &str = "# >>> pds managed >>>";
    const END: &str = "# <<< pds managed <<<";

    let mut managed = String::new();
    managed.push_str(BEGIN);
    managed.push('\n');
    for p in &cfg.gitignore.paths {
        managed.push_str(p);
        managed.push('\n');
    }
    managed.push_str(END);

    let desired = replace_between(&current, BEGIN, END, &managed);
    diff_and_write(&path, &desired, dry_run)
}

fn replace_between(text: &str, begin: &str, end: &str, replacement: &str) -> String {
    let trimmed = text.trim_end();
    if let (Some(b), Some(e)) = (trimmed.find(begin), trimmed.find(end)) {
        let after_end = e + end.len();
        let mut out = String::new();
        out.push_str(&trimmed[..b]);
        out.push_str(replacement);
        out.push_str(&trimmed[after_end..]);
        if !out.ends_with('\n') {
            out.push('\n');
        }
        out
    } else {
        let mut out = trimmed.to_string();
        if !out.is_empty() && !out.ends_with('\n') {
            out.push('\n');
        }
        if !out.is_empty() {
            out.push('\n');
        }
        out.push_str(replacement);
        out.push('\n');
        out
    }
}

// ---------- TOFU fingerprint ----------

fn shape_fingerprint(cfg: &Config) -> String {
    let mut shape = serde_json::Map::new();
    shape.insert(
        "presets".into(),
        JsonValue::Array(
            cfg.permissions
                .presets
                .iter()
                .map(|s| JsonValue::String(s.clone()))
                .collect(),
        ),
    );
    shape.insert(
        "plugins".into(),
        JsonValue::Array(
            cfg.plugins
                .install
                .iter()
                .map(|s| JsonValue::String(s.clone()))
                .collect(),
        ),
    );
    shape.insert(
        "mcp_core".into(),
        JsonValue::Array(
            cfg.mcp
                .core
                .iter()
                .map(|s| JsonValue::String(s.clone()))
                .collect(),
        ),
    );
    shape.insert(
        "gitignore_paths_len".into(),
        JsonValue::from(cfg.gitignore.paths.len()),
    );
    shape.insert(
        "claude_md_managed".into(),
        JsonValue::Bool(cfg.claude_md.manage_section),
    );
    shape.insert(
        "write_target".into(),
        JsonValue::String(format!("{:?}", cfg.permissions.write_target)),
    );

    let canonical = serde_json::to_string(&JsonValue::Object(shape)).unwrap_or_default();
    let mut hasher = Sha256::new();
    hasher.update(canonical.as_bytes());
    format!("{:x}", hasher.finalize())
}

fn read_stored_fingerprint() -> Result<Option<String>> {
    let path = paths::fingerprint_file()?;
    if !path.exists() {
        return Ok(None);
    }
    let s = std::fs::read_to_string(&path)?.trim().to_string();
    if s.is_empty() {
        Ok(None)
    } else {
        Ok(Some(s))
    }
}

fn write_fingerprint(fp: &str) -> Result<()> {
    let path = paths::fingerprint_file()?;
    atomic_write(&path, &format!("{}\n", fp))?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn fingerprint_changes_on_shape() {
        let mut a = Config::default();
        a.permissions.presets = vec!["pds-default".into()];
        let mut b = a.clone();
        b.permissions.presets.push("dev-tools".into());
        assert_ne!(shape_fingerprint(&a), shape_fingerprint(&b));
    }

    #[test]
    fn fingerprint_stable_on_value_tweaks() {
        let mut a = Config::default();
        a.health.serious_min = 90;
        let mut b = a.clone();
        b.health.serious_min = 120;
        assert_eq!(shape_fingerprint(&a), shape_fingerprint(&b));
    }

    #[test]
    fn reconcile_drops_dropped_preset_entries() {
        // Simulated state: file currently has A, B, C, D.
        // Previously PDS wrote B, C (both came from a preset).
        // User's new desired: just B (preset that contributed C was removed).
        // Expected: C is removed (PDS owned it, no longer desired). A and D
        // stay (PDS never touched them). B stays.
        let mut perms = serde_json::Map::new();
        perms.insert(
            "allow".into(),
            JsonValue::Array(vec![
                JsonValue::String("A".into()),
                JsonValue::String("B".into()),
                JsonValue::String("C".into()),
                JsonValue::String("D".into()),
            ]),
        );
        let desired = vec!["B".to_string()];
        let prev = vec!["B".to_string(), "C".to_string()];
        reconcile_list(&mut perms, "allow", &desired, &prev);
        let arr = perms.get("allow").unwrap().as_array().unwrap();
        let values: Vec<&str> = arr.iter().filter_map(|v| v.as_str()).collect();
        assert_eq!(values, vec!["A", "B", "D"]);
    }

    #[test]
    fn reconcile_adds_new_entries_without_duplicates() {
        let mut perms = serde_json::Map::new();
        perms.insert(
            "allow".into(),
            JsonValue::Array(vec![JsonValue::String("X".into())]),
        );
        let desired = vec!["X".to_string(), "Y".to_string()];
        let prev: Vec<String> = vec![];
        reconcile_list(&mut perms, "allow", &desired, &prev);
        let arr = perms.get("allow").unwrap().as_array().unwrap();
        let values: Vec<&str> = arr.iter().filter_map(|v| v.as_str()).collect();
        assert_eq!(values, vec!["X", "Y"]);
    }

    #[test]
    fn reconcile_leaves_user_untouched_entries_alone() {
        // A user's manually-edited entry (not in prev, not in desired) must
        // survive every sync.
        let mut perms = serde_json::Map::new();
        perms.insert(
            "allow".into(),
            JsonValue::Array(vec![JsonValue::String("UserAddedThis".into())]),
        );
        let desired: Vec<String> = vec![];
        let prev: Vec<String> = vec![];
        reconcile_list(&mut perms, "allow", &desired, &prev);
        let arr = perms.get("allow").unwrap().as_array().unwrap();
        let values: Vec<&str> = arr.iter().filter_map(|v| v.as_str()).collect();
        assert_eq!(values, vec!["UserAddedThis"]);
    }

    #[test]
    fn replace_between_idempotent() {
        let before = "a\n# >>> pds managed >>>\nx\n# <<< pds managed <<<\nb\n";
        let new = "# >>> pds managed >>>\ny\n# <<< pds managed <<<";
        let out = replace_between(before, "# >>> pds managed >>>", "# <<< pds managed <<<", new);
        assert!(out.contains("y\n"));
        assert!(!out.contains("x\n"));
        assert!(out.contains("a\n"));
        assert!(out.contains("b\n"));
    }
}
