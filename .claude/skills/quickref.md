---
description: Quick reference for common commands and patterns
---
# /quickref — Quick Reference Card

Fast lookup for common commands and patterns.

## Git

```bash
# Worktrees — See /worktree

# History
git log --oneline -20
git log -p -- path/to/file
git blame file.js
# Bisect — See /debug

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

## Terminal Navigation

```bash
# zoxide (smart cd)
z project          # Jump to frequently used dir
zi                 # Interactive selection

# yazi
y                  # Open file manager
# In yazi:
# j/k or arrows    # Navigate
# Enter            # Open in $EDITOR
# Tab              # Select
# y                # Copy path
# q                # Quit
```

## tmux

```bash
# Sessions
tmux new -s name              # New named session
tmux attach -t name           # Attach to session
tmux switch -t name           # Switch session
tmux ls                       # List sessions
Ctrl-a d                      # Detach

# Panes (with C-a prefix)
|                             # Split vertical
-                             # Split horizontal
arrow keys                    # Navigate panes
z                             # Toggle zoom
x                             # Kill pane

# Windows
c                             # New window
n/p                           # Next/previous window
[0-9]                         # Jump to window
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

# fzf
Ctrl-r                        # Search history
Ctrl-t                        # Find file
Alt-c                         # cd to directory
vim $(fzf)                    # Open selected file
```

## Keyboard Shortcuts (Terminal)

```
Ctrl-a        # Beginning of line
Ctrl-e        # End of line
Ctrl-w        # Delete word backward
Ctrl-u        # Delete to beginning
Ctrl-k        # Delete to end
Ctrl-r        # Search history
Ctrl-l        # Clear screen
Ctrl-c        # Cancel command
Ctrl-d        # Exit shell
```
