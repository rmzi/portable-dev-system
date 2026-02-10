# Reset Tmux Sessions

**WARNING: This kills ALL tmux sessions. Only use when testing config changes.**

## When to Use

- After updating tmux.conf and wanting fresh sessions with new settings
- After updating shell-helpers.sh session naming conventions
- Testing new layouts or configurations

## Commands

```bash
# Kill all tmux sessions
tmux kill-server

# Or kill sessions one by one (safer)
tmux list-sessions -F "#{session_name}" | xargs -I {} tmux kill-session -t {}
```

## After Reset

Recreate your worktree sessions:

```bash
# Navigate to your worktree and open fresh session
cd ~/dev/project
wt main
```

## Gentle Cleanup (preferred)

Use `wtc` to clean up without nuking everything:

```bash
wtc  # Prunes stale worktrees + kills orphaned tmux sessions
```

## Caution

- Unsaved work in tmux panes will be lost
- Running processes (builds, servers) will be terminated
- Claude Code sessions in tmux will disconnect
