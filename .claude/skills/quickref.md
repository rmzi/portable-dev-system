---
description: Quick reference for common commands and patterns
---
# /quickref — Quick Reference Card

Fast lookup for common commands and patterns.

## Git

```bash
# Worktrees
git worktree add ../proj-feature feature/x
git worktree list
git worktree remove ../proj-feature

# History investigation
git log --oneline -20
git log -p -- path/to/file
git blame file.js
git bisect start && git bisect bad && git bisect good v1.0

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

## HTTP

```bash
# curl
curl -X GET url
curl -X POST url -H "Content-Type: application/json" -d '{"key":"value"}'
curl -I url                   # Headers only
curl -o file url              # Download

# httpie (friendlier)
http GET url
http POST url key=value
http PUT url < file.json
```

## JSON

```bash
# jq
cat file.json | jq .
cat file.json | jq '.key'
cat file.json | jq '.array[0]'
cat file.json | jq '.[] | select(.type == "foo")'
```

## Process

```bash
# Find and kill
lsof -i :3000                 # What's on port 3000
kill -9 $(lsof -t -i:3000)    # Kill it

# Background
command &                      # Run in background
Ctrl-z                        # Suspend
bg                            # Resume in background
fg                            # Bring to foreground
jobs                          # List background jobs
```

## Disk

```bash
du -sh */                     # Size of subdirectories
df -h                         # Disk free space
ncdu                          # Interactive disk usage
```

## Network

```bash
ping host
traceroute host
dig domain
nslookup domain
netstat -tuln                 # Listening ports
ss -tuln                      # Modern netstat
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
