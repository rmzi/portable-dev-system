---
description: Git worktrees for isolated parallel development
---
# /worktree — Isolated Parallel Development

Each stream of work gets its own directory. No stashing, no branch switching, no lost context.

## Commands

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

Worktrees go in the project's parent directory (`../`), never in `/tmp`.

## Workflow

```bash
# Start feature work
git worktree add ../myproject-feature-profiles -b feature/user-profiles
cd ../myproject-feature-profiles

# Urgent bug — new worktree, no context lost
git worktree add ../myproject-hotfix-critical -b hotfix/critical-fix
cd ../myproject-hotfix-critical

# Fix bug, PR, merge, clean up
git worktree remove ../myproject-hotfix-critical
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
git worktree add ../project-spike-idea -b spike/crazy-idea
# If good: merge. If bad: remove worktree + delete branch
```

### Parallel feature development
```bash
git worktree add ../project-feature-api -b feature/api
git worktree add ../project-feature-ui -b feature/ui
# Work on API in one terminal, UI in another
```

### Agent worktrees
```bash
# Create worktrees for multi-agent work
git worktree add ../project-task-1-auth -b task-1/auth
git worktree add ../project-task-2-api -b task-2/api
# Each agent gets its own isolated environment
```

## Rules

1. **One branch per worktree** — A branch can only be checked out in one worktree
2. **Shared git history** — All worktrees share .git
3. **Independent state** — Each has its own index, HEAD, uncommitted changes
4. **Clean up after merge** — Remove worktrees when PRs are merged
5. **Never /tmp** — Worktrees go in `../`, not `/tmp`
