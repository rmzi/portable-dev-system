---
description: Quick reference for common commands and patterns
---
# /quickref — Quick Reference Card

## Git

```bash
# Worktrees — See /worktree
git worktree add ../dir -b branch   # Create worktree + branch
git worktree list                    # List worktrees
git worktree remove ../dir           # Remove worktree

# History
git log --oneline -20
git log -p -- path/to/file
git blame file.js

# Undo
git checkout -- file           # Discard unstaged changes
git reset HEAD file            # Unstage file
git reset --soft HEAD~1        # Undo commit, keep changes staged
git revert <commit>            # Create undo commit

# Stash (use worktrees instead when possible)
git stash push -m "description"
git stash list
git stash pop
```

## Search

```bash
# ripgrep (rg)
rg "pattern"                  # Search current dir
rg "pattern" -t js            # Search only JS files
rg "pattern" -g "*.tsx"       # Search with glob
rg "pattern" -A 3 -B 3        # With context

# fd (find alternative)
fd "pattern"                  # Find files by name
fd -e js                      # Find by extension
fd -t d                       # Find directories only
```
