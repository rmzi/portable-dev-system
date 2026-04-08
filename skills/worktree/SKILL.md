---
description: Managing git worktrees for isolated parallel development. Use when creating branches, setting up agent worktrees, or cleaning up after merges.
---
# /worktree — Isolated Parallel Development

Each stream of work gets its own directory. No stashing, no branch switching, no lost context.

## Commands

```bash
REPO_ROOT="$(git rev-parse --path-format=absolute --git-common-dir | sed 's|/.git$||')"

git worktree list                                                  # List worktrees
git worktree add "$REPO_ROOT/.worktrees/dir" branch                # Create from existing branch
git worktree add "$REPO_ROOT/.worktrees/dir" -b new-branch         # Create with new branch
git worktree remove "$REPO_ROOT/.worktrees/dir"                    # Remove worktree
git worktree prune                                                 # Clean stale references
```

## Naming Convention

Worktrees live inside the repo at `.worktrees/`:

```
project/                              # main worktree (main/master)
project/.worktrees/feature-auth/      # feature work
project/.worktrees/hotfix-login/      # urgent fix
project/.worktrees/pr-123/            # reviewing a PR
```

Pattern: `project/.worktrees/{branch-with-slashes-as-dashes}`

`.worktrees/` is auto-added to `.gitignore` on first use.

## Path Resolution

When running inside a worktree, relative `.worktrees/` paths create nested directories instead of sibling worktrees at the repo root. **Always resolve `REPO_ROOT` first:**

```bash
REPO_ROOT="$(git rev-parse --path-format=absolute --git-common-dir | sed 's|/.git$||')"
```

This uses git plumbing to find the shared `.git` directory (which always lives in the main repo), then strips the `/.git` suffix. It's idempotent — returns the same path from both the main repo and any worktree. Requires Git 2.13+.

Then use `"$REPO_ROOT/.worktrees/"` in all commands.

### Why this approach?

| Alternative | Problem |
|---|---|
| `git rev-parse --show-toplevel` | Returns the *current* worktree root, not the main repo root — exactly the bug this fixes |
| `dirname $(git rev-parse --git-common-dir)` | Community pattern ([anthropics/claude-code#1052](https://github.com/anthropics/claude-code/issues/1052)) — same idea, but without `--path-format=absolute` it returns `.git` (relative) from the main repo, making `dirname` return `.` which is fragile |
| `git worktree list \| head -1 \| awk '{print $1}'` | Works but slower (lists all worktrees), relies on output formatting |
| Sibling directories (`../project-feature`) | Official Claude Code docs pattern — avoids the problem entirely but PDS uses `.worktrees/` for organization |

We use `--path-format=absolute` to guarantee an absolute path regardless of where the command runs, combined with `--git-common-dir` to always resolve to the main repo's `.git` directory.

## Workflow

```bash
REPO_ROOT="$(git rev-parse --path-format=absolute --git-common-dir | sed 's|/.git$||')"

# Start feature work
git worktree add "$REPO_ROOT/.worktrees/feature-user-profiles" -b feature/user-profiles
cd "$REPO_ROOT/.worktrees/feature-user-profiles"

# Urgent bug — new worktree, no context lost
git worktree add "$REPO_ROOT/.worktrees/hotfix-critical" -b hotfix/critical-fix
cd "$REPO_ROOT/.worktrees/hotfix-critical"

# Fix bug, PR, merge, clean up
git worktree remove "$REPO_ROOT/.worktrees/hotfix-critical"
git branch -d hotfix/critical-fix
```

## Patterns

### Review a PR without losing context
```bash
REPO_ROOT="$(git rev-parse --path-format=absolute --git-common-dir | sed 's|/.git$||')"
git fetch origin pull/123/head:pr-123
git worktree add "$REPO_ROOT/.worktrees/pr-123" pr-123
# Review, test, done
git worktree remove "$REPO_ROOT/.worktrees/pr-123"
git branch -d pr-123
```

### Explore without fear
```bash
REPO_ROOT="$(git rev-parse --path-format=absolute --git-common-dir | sed 's|/.git$||')"
git worktree add "$REPO_ROOT/.worktrees/spike-idea" -b spike/crazy-idea
# If good: merge. If bad: remove worktree + delete branch
git worktree remove "$REPO_ROOT/.worktrees/spike-idea"
git branch -D spike/crazy-idea
```

### Parallel feature development
```bash
REPO_ROOT="$(git rev-parse --path-format=absolute --git-common-dir | sed 's|/.git$||')"
git worktree add "$REPO_ROOT/.worktrees/feature-api" -b feature/api
git worktree add "$REPO_ROOT/.worktrees/feature-ui" -b feature/ui
# Work on API in one terminal, UI in another
# Each has its own index, HEAD, and uncommitted changes
```

### Agent worktrees
```bash
REPO_ROOT="$(git rev-parse --path-format=absolute --git-common-dir | sed 's|/.git$||')"
# Create worktrees for multi-agent work (see /swarm)
git worktree add "$REPO_ROOT/.worktrees/task-1-auth" -b task-1/auth
git worktree add "$REPO_ROOT/.worktrees/task-2-api" -b task-2/api
# Each agent gets its own isolated environment
# Use TaskCreate/Task tool for agent dispatch (see /pds:swarm)
```

## Garbage Collection

Invoke as `/pds:worktree gc` to detect and remove stale worktrees.

### What Counts as Stale

| Type | Detection | Removal |
|------|-----------|---------|
| **Orphan** | Directory in `.worktrees/` not in `git worktree list` (broken git metadata) | `rm -rf <path>` (git doesn't know about it) |
| **Merged branch** | Worktree whose branch is already merged to main | `git worktree remove <path>` + `git branch -d <branch>` |

### GC Protocol

1. Resolve repo root:
   ```bash
   REPO_ROOT="$(git rev-parse --path-format=absolute --git-common-dir | sed 's|/.git$||')"
   ```

2. Find orphans — dirs in `.worktrees/` not registered with git:
   ```bash
   # Get git-registered worktree paths
   git worktree list --porcelain | grep '^worktree ' | sed 's|^worktree ||'
   # Compare against .worktrees/*/ on disk
   ```

3. Find merged-branch worktrees:
   ```bash
   # Determine main branch
   git symbolic-ref refs/remotes/origin/HEAD | sed 's|refs/remotes/origin/||'
   # List merged branches
   git branch --merged main
   # Cross-reference with git worktree list
   ```

4. For each stale worktree, report:
   - Path
   - Why it's stale (orphan or merged branch)
   - Whether it has uncommitted changes (git-registered only; skip for orphans)

5. **Ask user for confirmation before removing.** List all candidates and wait for approval.

6. Remove confirmed worktrees:
   - Git-registered: `git worktree remove "$REPO_ROOT/.worktrees/<name>"` then `git branch -d <branch>`
   - Orphans: `rm -rf "$REPO_ROOT/.worktrees/<name>"`
   - Skip any with uncommitted changes (warn, don't remove)

7. Clean up: `git worktree prune` to clear stale git references.

8. Report summary: N removed, N skipped (dirty).

### SessionStart Detection

PDS detects stale worktrees at session start and warns in context:
```
STALE WORKTREES: 3 stale worktree(s) in .worktrees/. Run /pds:worktree gc to clean up.
```

## Manual Cleanup

```bash
REPO_ROOT="$(git rev-parse --path-format=absolute --git-common-dir | sed 's|/.git$||')"

# Remove a specific worktree and its branch
git worktree remove "$REPO_ROOT/.worktrees/done-feature"
git branch -d done-feature-branch

# Clean stale references (worktree dir already deleted)
git worktree prune

# Find branches already merged to main
git branch --merged main

# Delete merged branches
git branch -d merged-branch-name
```

## Rules

1. **One branch per worktree** — A branch can only be checked out in one worktree
2. **Shared git history** — All worktrees share .git
3. **Independent state** — Each has its own index, HEAD, uncommitted changes
4. **Clean up after merge** — Remove worktrees when PRs are merged
5. **Never /tmp or ../** — Worktrees go in `.worktrees/`, not `/tmp` or `../`
6. **Always resolve REPO_ROOT first** — Use `git rev-parse --path-format=absolute --git-common-dir | sed 's|/.git$||'` before any `.worktrees/` path to avoid nested directories when running from a worktree
