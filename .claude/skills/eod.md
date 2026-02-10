---
description: End-of-day cleanup across all repos
---
# /eod — End-of-Day Cleanup

Clean up worktrees across all repos. Surface outstanding work, force resolution, and remove merged worktrees.

## Commands

| Command | What it does |
|---------|--------------|
| `wtc --all` | End-of-day cleanup across all discovered repos |
| `wtc` | Clean current repo only |

## How It Works

### Phase 1: Scan and Summarize

Discovers repos by scanning:
1. All active tmux session pane paths
2. Directories listed in `~/.pds/eod.conf` (default: `~/dev/`)

For each worktree, checks:
- Uncommitted changes (staged + unstaged)
- Unpushed commits
- No upstream branch
- Open pull requests (via `gh`)
- Merge conflicts

Displays a summary:
```
=== PDS End of Day ===

Scanning repos...
  3 repos found (11 worktrees)

REPO: myapp (~/dev/myapp)
  .worktrees/feature-auth       CLEAN (merged) — ready to remove
  .worktrees/feature-dashboard  unpushed commits, open PR
  .worktrees/hotfix-login       uncommitted changes

Summary:
  1 ready to remove | 2 need resolution
```

### Phase 2: Resolution

Interactive menu for each worktree with outstanding work:

```
RESOLVE: myapp / .worktrees/hotfix-login (branch: hotfix/login)
  Uncommitted files:
    M  src/auth/login.ts
    M  src/auth/session.ts
    A  src/auth/token.ts

  [c] Commit and push    [s] Stash changes
  [o] Open in tmux       [d] Discard (destructive)
  [k] Skip (keep)        [q] Quit
```

- **[c]** Commit and push — `git add -A && git commit -m "wip: end-of-day save" && git push`
- **[s]** Stash — `git stash push -m "eod: YYYY-MM-DD"`
- **[o]** Open in tmux — pauses cleanup, re-scans on return
- **[d]** Discard — destructive, requires typing "yes"
- **[k]** Skip — explicitly keep, listed at end as reminder
- **[q]** Quit — abort cleanup entirely

### Phase 3: Batch Cleanup

Removes all clean/merged worktrees and kills associated tmux sessions.

Also detects and offers to migrate old sibling-format worktrees into `.worktrees/`.

---

## Configuration

Optional: `~/.pds/eod.conf`
```bash
SCAN_DIRS="$HOME/dev $HOME/work"
```

Default scan directory is `~/dev/`.

---

## Migration

Old sibling-format worktrees (`../project-branch/`) are detected during both `wtc` and `wtc --all`. You'll be prompted to migrate them into `.worktrees/` inside the repo using `git worktree move`.

Active tmux sessions are updated to point to the new paths.

---

## Rules

1. **Never lose work** — resolution menu forces explicit choice before any cleanup
2. **Skip is valid** — `[k]` acknowledges but keeps; listed at end as reminder
3. **Batch removes only clean/merged** — dirty worktrees are never auto-removed
4. **Open in tmux pauses** — cleanup waits for you to resolve manually
