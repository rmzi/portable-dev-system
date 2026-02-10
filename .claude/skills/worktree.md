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
| `wt` | Fuzzy pick worktree → tmux layout (Claude + terminal + yazi + lazygit) |
| `wt branch` | Open tmux layout for existing branch |
| `wt -b branch` | Create new branch + open tmux layout |
| `wtr` | Remove current worktree + kill its session |
| `wts` | Global session picker — jump to any tmux session |
| `wtc` | Clean up stale worktrees + orphaned tmux sessions |

### Raw git commands

```bash
git worktree list                                    # List worktrees
git worktree add .worktrees/dir branch               # Create from existing branch
git worktree add .worktrees/dir -b new-branch        # Create with new branch
git worktree remove .worktrees/dir                   # Remove worktree
git worktree move ../old-sibling .worktrees/new-dir  # Migrate old format
git worktree prune                                   # Clean stale references
```

---

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

---

## Workflow

```bash
# Start feature work
wt -b feature/user-profiles
# Now in myproject/.worktrees/feature-user-profiles/

# Open Claude Code
claude

# ... working on feature ...

# Urgent bug comes in - new terminal:
cd ~/dev/myproject
wt -b hotfix/critical-fix

# Fix bug, PR, merge, clean up
wtr  # Remove current worktree

# End of day - clean all repos
wtc --all
```

---

## Patterns

### Review a PR without losing context
```bash
git fetch origin pull/123/head:pr-123
wt pr-123
# Review, test, done
wtr  # Remove from inside the worktree
```

### Explore without fear
```bash
wt -b spike/crazy-idea
# Break things freely
# If good: merge
# If bad: wtr && git branch -D spike/crazy-idea
```

### Parallel feature development
```bash
wt -b feature/api
wt -b feature/ui
# Work on API in one terminal, UI in another
```

---

## Rules

1. **One branch per worktree** — A branch can only be checked out in one worktree
2. **Shared git history** — All worktrees share .git
3. **Independent state** — Each has its own index, HEAD, uncommitted changes
4. **Clean up after merge** — Remove worktrees when PRs are merged
