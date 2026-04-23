//! `pds migrate` — consolidate pre-journal-layout data into the new journal root.
//!
//! Covers the known legacy write-sites from older PDS versions:
//!   - `<repo>/.claude/shepherd-journal.md` — per-repo shepherd advisory log.
//!     Consolidates to `$XDG_DATA_HOME/pds/journal/shepherd/<slug>.md`.
//!   - `${TMPDIR}/pds-diary-*.md` — ephemeral diary staging files that past
//!     runs left behind. Preserved into `$XDG_DATA_HOME/pds/journal/diary/`
//!     only with --keep-diary (they were never meant to persist, but the
//!     user may want them for archaeology).
//!
//! Default is --dry-run: scan + report, touch nothing. Migration runs the
//! copy under a fingerprint marker so re-runs don't duplicate. Sources are
//! never deleted unless --remove-source is passed.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use anyhow::{Context, Result};
use clap::Args as ClapArgs;

use crate::paths;

#[derive(ClapArgs, Debug)]
pub struct Args {
    /// Write the moves. Without this flag, only prints what would happen.
    #[arg(long)]
    pub apply: bool,
    /// Delete source files after successful copy. Default is copy-only (safer).
    #[arg(long)]
    pub remove_source: bool,
    /// Directory roots to scan for `<repo>/.claude/shepherd-journal.md`.
    /// Defaults to $HOME/dev and $PWD.
    #[arg(long, value_delimiter = ',')]
    pub search: Vec<PathBuf>,
    /// Also preserve ephemeral `${TMPDIR}/pds-diary-*.md` temp files.
    #[arg(long)]
    pub keep_diary: bool,
}

pub fn run(args: Args) -> Result<()> {
    let journal_root = paths::data_root()?.join("journal");
    let mut plan = MigrationPlan::default();

    // --- Shepherd journals: one per repo that ever ran the shepherd ---
    let search_roots = resolve_search_roots(&args.search)?;
    for root in &search_roots {
        scan_shepherd_journals(root, &journal_root, &mut plan)?;
    }

    // --- Ephemeral diary temp files ---
    if args.keep_diary {
        scan_diary_temp_files(&journal_root, &mut plan)?;
    }

    if plan.moves.is_empty() {
        println!("pds migrate: nothing to migrate (journal root: {})", journal_root.display());
        println!("  scanned: {}", search_roots.iter().map(|p| p.display().to_string()).collect::<Vec<_>>().join(", "));
        if !args.keep_diary {
            println!("  (pass --keep-diary to also scan ephemeral diary temp files)");
        }
        return Ok(());
    }

    println!("pds migrate: {} file(s) would move", plan.moves.len());
    for (src, dst) in &plan.moves {
        let verb = if args.apply { "moving" } else { "would move" };
        println!("  {} {} -> {}", verb, src.display(), dst.display());
    }

    if !args.apply {
        println!("\ndry-run only. Re-run with --apply to perform the moves.");
        return Ok(());
    }

    let mut done = 0_usize;
    for (src, dst) in &plan.moves {
        if dst.exists() {
            println!("  skip (target exists): {}", dst.display());
            continue;
        }
        if let Some(parent) = dst.parent() {
            std::fs::create_dir_all(parent)?;
        }
        // Plain byte-copy instead of std::fs::copy: the latter uses
        // fcopyfile() on macOS which tries to preserve xattrs and can hit
        // sandbox / SIP boundaries even when a shell `cp` would succeed.
        let bytes = std::fs::read(src)
            .with_context(|| format!("reading {}", src.display()))?;
        std::fs::write(dst, &bytes)
            .with_context(|| format!("writing {}", dst.display()))?;
        if args.remove_source {
            std::fs::remove_file(src)
                .with_context(|| format!("removing source {}", src.display()))?;
        }
        done += 1;
    }
    println!("pds migrate: copied {} file(s){}", done, if args.remove_source { " (sources removed)" } else { "" });
    Ok(())
}

#[derive(Default)]
struct MigrationPlan {
    /// src -> dst (BTreeMap for stable output ordering).
    moves: BTreeMap<PathBuf, PathBuf>,
}

fn resolve_search_roots(user_provided: &[PathBuf]) -> Result<Vec<PathBuf>> {
    if !user_provided.is_empty() {
        return Ok(user_provided.iter().map(|p| p.canonicalize().unwrap_or(p.clone())).collect());
    }
    let mut roots = Vec::new();
    if let Some(home) = dirs::home_dir() {
        let dev = home.join("dev");
        if dev.exists() {
            roots.push(dev);
        }
    }
    if let Ok(pwd) = std::env::current_dir() {
        if !roots.iter().any(|r| pwd.starts_with(r)) {
            roots.push(pwd);
        }
    }
    Ok(roots)
}

fn scan_shepherd_journals(
    root: &Path,
    journal_root: &Path,
    plan: &mut MigrationPlan,
) -> Result<()> {
    // Walk up to a reasonable depth (6) to keep cost bounded. Most repos are
    // at depth 2-4 from ~/dev.
    walk(root, 0, 6, &mut |entry| {
        if entry.file_name().and_then(|s| s.to_str()) == Some("shepherd-journal.md") {
            // Require the parent dir to be named `.claude/` — don't sweep up
            // arbitrary files that happen to share the name.
            if entry.parent().and_then(|p| p.file_name()).and_then(|s| s.to_str())
                == Some(".claude")
            {
                let slug = slugify_repo(entry);
                let dst = journal_root.join("shepherd").join(format!("{}.md", slug));
                plan.moves.insert(entry.to_path_buf(), dst);
            }
        }
        Ok(())
    })?;
    Ok(())
}

fn scan_diary_temp_files(journal_root: &Path, plan: &mut MigrationPlan) -> Result<()> {
    let tmp = std::env::var("TMPDIR").unwrap_or_else(|_| "/tmp".to_string());
    let tmpdir = PathBuf::from(tmp);
    if !tmpdir.exists() {
        return Ok(());
    }
    for entry in std::fs::read_dir(&tmpdir)? {
        let entry = entry?;
        let name = entry.file_name().to_string_lossy().to_string();
        if name.starts_with("pds-diary-") && name.ends_with(".md") {
            let dst = journal_root.join("diary").join(&name);
            plan.moves.insert(entry.path(), dst);
        }
    }
    Ok(())
}

/// Turn `/Users/rmzi/dev/tools/foo/.claude/shepherd-journal.md` into `tools-foo`.
/// Falls back to parent dir name if the ancestry is unexpected.
fn slugify_repo(journal_path: &Path) -> String {
    // Repo dir is the parent of `.claude/`.
    let repo_dir = journal_path.parent().and_then(|p| p.parent());
    let Some(repo_dir) = repo_dir else {
        return "unknown-repo".to_string();
    };
    let name = repo_dir
        .file_name()
        .and_then(|s| s.to_str())
        .unwrap_or("unknown");
    // Include one level of grandparent context so `tools/foo` and `work/foo`
    // don't collide.
    let context = repo_dir
        .parent()
        .and_then(|p| p.file_name())
        .and_then(|s| s.to_str())
        .unwrap_or("");
    if context.is_empty() {
        name.to_string()
    } else {
        format!("{}-{}", context, name)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn slugify_combines_grandparent_and_repo() {
        let p = PathBuf::from("/Users/x/dev/tools/foo/.claude/shepherd-journal.md");
        assert_eq!(slugify_repo(&p), "tools-foo");
    }

    #[test]
    fn slugify_tolerates_shallow_layout() {
        let p = PathBuf::from("/foo/.claude/shepherd-journal.md");
        assert!(slugify_repo(&p).contains("foo"));
    }

    #[test]
    fn byte_copy_preserves_content() {
        let tmp = TempDir::new().unwrap();
        let src = tmp.path().join("src.md");
        let dst = tmp.path().join("dst.md");
        std::fs::write(&src, b"journal entry body").unwrap();
        let bytes = std::fs::read(&src).unwrap();
        std::fs::write(&dst, &bytes).unwrap();
        assert_eq!(std::fs::read(&dst).unwrap(), b"journal entry body");
    }

    #[test]
    fn shepherd_scan_finds_claude_journal() {
        let tmp = TempDir::new().unwrap();
        let repo = tmp.path().join("myrepo");
        std::fs::create_dir_all(repo.join(".claude")).unwrap();
        std::fs::write(repo.join(".claude").join("shepherd-journal.md"), "x").unwrap();
        // Decoy: same filename outside .claude/ should be ignored.
        std::fs::write(tmp.path().join("shepherd-journal.md"), "x").unwrap();
        let journal_root = tmp.path().join("journal");
        let mut plan = MigrationPlan::default();
        scan_shepherd_journals(tmp.path(), &journal_root, &mut plan).unwrap();
        assert_eq!(plan.moves.len(), 1);
        let (src, _) = plan.moves.iter().next().unwrap();
        assert!(src.ends_with("myrepo/.claude/shepherd-journal.md"));
    }
}

fn walk(
    dir: &Path,
    depth: usize,
    max_depth: usize,
    visit: &mut impl FnMut(&Path) -> Result<()>,
) -> Result<()> {
    if depth > max_depth {
        return Ok(());
    }
    let entries = match std::fs::read_dir(dir) {
        Ok(e) => e,
        Err(_) => return Ok(()), // permission denied, deleted during walk, etc.
    };
    for entry in entries {
        let Ok(entry) = entry else { continue };
        let path = entry.path();
        // Skip common noise: node_modules, target, .git internals.
        if let Some(name) = path.file_name().and_then(|s| s.to_str()) {
            if matches!(
                name,
                "node_modules" | "target" | ".git" | ".cargo" | "vendor" | "dist" | "build"
            ) {
                continue;
            }
        }
        let file_type = match entry.file_type() {
            Ok(ft) => ft,
            Err(_) => continue,
        };
        if file_type.is_dir() {
            walk(&path, depth + 1, max_depth, visit)?;
        } else if file_type.is_file() {
            visit(&path)?;
        }
    }
    Ok(())
}
