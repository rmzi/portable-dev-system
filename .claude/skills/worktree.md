---
description: Git worktrees for isolated parallel development
---
# /worktree — Isolated Parallel Development

Worktrees provide true isolation. No stashing. No branch switching. No lost context.

## Why Worktrees?

Context switching is expensive:
- Mental model of current work is lost
- Uncommitted changes create risk
- `git stash` is where changes go to die
- Branch switching in large repos is slow

Worktrees solve this by giving each stream of work its own directory.

---

## Commands

### Shell helpers (PDS)

| Command | What it does |
|---------|--------------|
| `wt` | Fuzzy pick worktree → cd there |
| `wty` | Fuzzy pick worktree → tmux layout (Claude + terminal + yazi) |
| `wta <branch>` | Create worktree from existing branch |
| `wta -b <branch>` | Create worktree with new branch (falls back if exists) |
| `wtl` | List all worktrees |
| `wtr` | Fuzzy pick worktree to remove |

### Raw git commands

```bash
git worktree list                           # List worktrees
git worktree add ../dir branch              # Create from existing branch
git worktree add ../dir -b new-branch       # Create with new branch
git worktree remove ../dir                  # Remove worktree
git worktree prune                          # Clean stale references
```

---

## Naming Convention

```
project/                    # main worktree (main/master)
project-feature-auth/       # feature work
project-hotfix-login/       # urgent fix
project-pr-123/             # reviewing a PR
```

Pattern: `{project}-{branch-with-slashes-as-dashes}`

---

## Workflow

```bash
# Start feature work
wta -b feature/user-profiles
# Now in ../myproject-feature-user-profiles

# Open Claude Code
claude

# ... working on feature ...

# Urgent bug comes in - new terminal:
cd ~/dev/myproject
wta -b hotfix/critical-fix

# Fix bug, PR, merge, clean up
wtr  # Select hotfix worktree to remove
```

---

## Patterns

### Review a PR without losing context
```bash
git fetch origin pull/123/head:pr-123
git worktree add ../project-pr-123 pr-123
cd ../project-pr-123
# Review, test, done
git worktree remove ../project-pr-123
```

### Explore without fear
```bash
wta -b spike/crazy-idea
# Break things freely
# If good: merge
# If bad: wtr && git branch -D spike/crazy-idea
```

### Parallel feature development
```bash
wta -b feature/api
wta -b feature/ui
# Work on API in one terminal, UI in another
```

---

## Rules

1. **One branch per worktree** — A branch can only be checked out in one worktree
2. **Shared git history** — All worktrees share .git
3. **Independent state** — Each has its own index, HEAD, uncommitted changes
4. **Clean up after merge** — Remove worktrees when PRs are merged
