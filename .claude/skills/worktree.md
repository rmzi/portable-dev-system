# /worktree — Isolated Parallel Development

Worktrees provide true isolation. No stashing. No branch switching. No lost context.

## Why Isolation Matters

Context switching is expensive:
- Mental model of current work is lost
- Uncommitted changes create risk
- `git stash` is where changes go to die
- Branch switching in large repos is slow

Worktrees solve this by giving each stream of work its own directory.

## Core Commands

```bash
# List existing worktrees
git worktree list

# Create worktree for existing branch
git worktree add ../project-feature feature/name

# Create worktree with new branch
git worktree add ../project-hotfix -b hotfix/issue-123

# Create worktree from specific commit/tag
git worktree add ../project-v2 v2.0.0

# Remove worktree (after merging)
git worktree remove ../project-feature

# Prune stale worktree references
git worktree prune
```

## Naming Convention

```
project/              # main worktree (usually main/master)
project-feature-x/    # feature work
project-hotfix-123/   # urgent fix
project-review-pr-45/ # reviewing someone's PR
project-experiment/   # throwaway exploration
```

## Workflow with Claude Code

Each worktree gets its own Claude session:

```bash
# Terminal 1: Feature work
cd ~/dev/project-feature-auth
claude

# Terminal 2: Hotfix (completely isolated)
cd ~/dev/project-hotfix-login
claude

# Terminal 3: Main branch stays clean for reference
cd ~/dev/project
```

## Integration with tmux

```bash
# Create named session per worktree
tmux new-session -s feature-auth -c ~/dev/project-feature-auth
tmux new-session -s hotfix -c ~/dev/project-hotfix

# Switch between contexts
tmux switch-client -t feature-auth
```

## Rules of Worktrees

1. **One branch per worktree** — A branch can only be checked out in one worktree
2. **Share git history** — All worktrees share .git (usually in main worktree)
3. **Independent working state** — Each has its own index, HEAD, uncommitted changes
4. **Clean up after merge** — Remove worktrees when work is merged

## Common Patterns

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
git worktree add ../project-spike -b spike/crazy-idea
# Break things freely
# If good: merge
# If bad: git worktree remove ../project-spike && git branch -D spike/crazy-idea
```

### Parallel feature development
```bash
git worktree add ../project-api -b feature/api
git worktree add ../project-ui -b feature/ui
# Work on API in one terminal, UI in another
# Both can be tested independently
```
