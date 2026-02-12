---
description: Git worktrees for isolated parallel development
---
# /worktree — Isolated Parallel Development

Each stream of work gets its own directory. No stashing, no branch switching, no lost context.

## Commands

```bash
git worktree list                                    # List worktrees
git worktree add .worktrees/dir branch               # Create from existing branch
git worktree add .worktrees/dir -b new-branch        # Create with new branch
git worktree remove .worktrees/dir                   # Remove worktree
git worktree prune                                   # Clean stale references
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

## Workflow

```bash
# Start feature work
git worktree add .worktrees/feature-user-profiles -b feature/user-profiles

# Urgent bug — new worktree, no context lost
git worktree add .worktrees/hotfix-critical -b hotfix/critical-fix
cd .worktrees/hotfix-critical

# Fix bug, PR, merge, clean up
git worktree remove .worktrees/hotfix-critical
```

## Patterns

### Review a PR without losing context
```bash
git fetch origin pull/123/head:pr-123
git worktree add .worktrees/pr-123 pr-123
# Review, test, done
git worktree remove .worktrees/pr-123
git branch -d pr-123
```

### Explore without fear
```bash
git worktree add .worktrees/spike-idea -b spike/crazy-idea
# If good: merge. If bad: remove worktree + delete branch
git worktree remove .worktrees/spike-idea
git branch -D spike/crazy-idea
```

### Parallel feature development
```bash
git worktree add .worktrees/feature-api -b feature/api
git worktree add .worktrees/feature-ui -b feature/ui
# Work on API in one terminal, UI in another
```

### Agent worktrees
```bash
# Create worktrees for multi-agent work
git worktree add .worktrees/task-1-auth -b task-1/auth
git worktree add .worktrees/task-2-api -b task-2/api
# Each agent gets its own isolated environment
```

## Cleanup

```bash
# Identify stale worktrees
git worktree list

# Remove a specific worktree
git worktree remove .worktrees/done-feature

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
5. **Never /tmp** — Worktrees go in `.worktrees/`, not `/tmp`
