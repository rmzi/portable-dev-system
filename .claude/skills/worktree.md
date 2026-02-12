---
description: Git worktrees for isolated parallel development
---
# /worktree — Isolated Parallel Development

Each stream of work gets its own directory. No stashing, no branch switching, no lost context.

## Commands

### Shell helpers (PDS)

| Command | What it does |
|---------|--------------|
| `wt` | Fuzzy pick worktree → tmux layout (Claude + terminal + yazi + lazygit) |
| `wt branch` | Open tmux layout for existing branch |
| `wt -b branch` | Create new branch + open tmux layout |
| `wtr` | Remove current worktree + kill its session |
| `wts` | Global session picker — jump to any tmux session |
| `wtc` | Clean up stale worktrees + orphaned tmux sessions |

### Raw git commands

```bash
git worktree list                           # List worktrees
git worktree add ../dir branch              # Create from existing branch
git worktree add ../dir -b new-branch       # Create with new branch
git worktree remove ../dir                  # Remove worktree
git worktree prune                          # Clean stale references
```

## Naming Convention

```
project/                    # main worktree (main/master)
project-feature-auth/       # feature work
project-hotfix-login/       # urgent fix
project-pr-123/             # reviewing a PR
```

Pattern: `{project}-{branch-with-slashes-as-dashes}`

## Workflow

```bash
# Start feature work
wt -b feature/user-profiles
# Now in ../myproject-feature-user-profiles

claude  # Open Claude Code

# Urgent bug comes in - new terminal:
cd ~/dev/myproject
wt -b hotfix/critical-fix

# Fix bug, PR, merge, clean up
wtr  # Select hotfix worktree to remove
```

## Patterns

### Review a PR without losing context
```bash
git fetch origin pull/123/head:pr-123
git worktree add ../project-pr-123 pr-123
# Review, test, done
git worktree remove ../project-pr-123
```

### Explore without fear
```bash
wt -b spike/crazy-idea
# If good: merge. If bad: wtr && git branch -D spike/crazy-idea
```

### Parallel feature development
```bash
wt -b feature/api
wt -b feature/ui
# Work on API in one terminal, UI in another
```

## Rules

1. **One branch per worktree** — A branch can only be checked out in one worktree
2. **Shared git history** — All worktrees share .git
3. **Independent state** — Each has its own index, HEAD, uncommitted changes
4. **Clean up after merge** — Remove worktrees when PRs are merged

## Cleanup & Reset

**Gentle cleanup (preferred):**
```bash
wtc  # Prunes stale worktrees + kills orphaned tmux sessions
```

**Full reset (kills ALL tmux sessions):**
```bash
tmux kill-server
# Then recreate sessions: cd ~/dev/project && wt main
```

Use full reset only when testing tmux.conf or shell-helpers.sh changes. Unsaved work in tmux panes will be lost.
