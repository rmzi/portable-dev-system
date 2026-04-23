//! Diff + atomic-write primitives shared across sync phases.

use std::path::Path;

use anyhow::{Context, Result};
use similar::{ChangeTag, TextDiff};

/// Compare `desired` against current file content, emit a unified diff to
/// stdout, then write (unless `dry_run`). Returns true if the file would
/// change (or was changed).
pub fn diff_and_write(path: &Path, desired: &str, dry_run: bool) -> Result<bool> {
    let current = if path.exists() {
        std::fs::read_to_string(path)
            .with_context(|| format!("reading {}", path.display()))?
    } else {
        String::new()
    };
    if current == desired {
        return Ok(false);
    }
    print_unified(&current, desired, &path.display().to_string());
    if !dry_run {
        atomic_write(path, desired)?;
    }
    Ok(true)
}

pub fn print_unified(current: &str, desired: &str, label: &str) {
    let diff = TextDiff::from_lines(current, desired);
    println!("--- a/{}", label);
    println!("+++ b/{}", label);
    for group in diff.grouped_ops(3) {
        // Hunk header: line ranges from old and new file. Without this, two
        // distinct change regions separated by a skip look contiguous and
        // it's easy to mistake leading-context of the next hunk for
        // trailing-context of the previous one.
        if let (Some(first), Some(last)) = (group.first(), group.last()) {
            let (old_start, old_len) = (first.old_range().start, last.old_range().end - first.old_range().start);
            let (new_start, new_len) = (first.new_range().start, last.new_range().end - first.new_range().start);
            // Line numbers in unified diff are 1-based.
            println!("@@ -{},{} +{},{} @@", old_start + 1, old_len, new_start + 1, new_len);
        }
        for op in group {
            for change in diff.iter_changes(&op) {
                let sign = match change.tag() {
                    ChangeTag::Delete => '-',
                    ChangeTag::Insert => '+',
                    ChangeTag::Equal => ' ',
                };
                print!("{}{}", sign, change);
            }
        }
    }
}

pub fn atomic_write(path: &Path, content: &str) -> Result<()> {
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)
            .with_context(|| format!("creating parent of {}", path.display()))?;
    }
    let tmp = path.with_extension(format!(
        "{}.tmp",
        path.extension().and_then(|s| s.to_str()).unwrap_or("new")
    ));
    std::fs::write(&tmp, content)
        .with_context(|| format!("writing {}", tmp.display()))?;
    std::fs::rename(&tmp, path)
        .with_context(|| format!("renaming to {}", path.display()))?;
    Ok(())
}
