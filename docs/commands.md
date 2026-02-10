# Command Reference

## Worktree Management

| Command | What it does |
|---------|--------------|
| `wt` | Fuzzy pick a worktree → open tmux layout |
| `wt branch` | Open tmux layout for existing branch |
| `wt -b branch` | Create new branch + open tmux layout |
| `wtr` | Remove current worktree + kill its session |
| `wts` | Global session picker — jump to any tmux session |
| `wtc` | Clean up stale worktrees + orphaned tmux sessions |

### Terminal Layout

`wt` creates this tmux layout:

```
┌──────────────────────────┬──────────────────┐
│                          │    terminal      │
│      Claude Code         ├──────────────────┤
│                          │      yazi        │
├──────────────────────────┴──────────────────┤
│                  lazygit                     │
└──────────────────────────────────────────────┘
```

**Tmux prefix:** `Ctrl-a` (not `Ctrl-b`)

**Tip:** If a pane dies (e.g. accidentally closed), the pane stays visible. Navigate to it and press `Ctrl-a R` to respawn it.

---

## Navigation

| Command | What it does |
|---------|--------------|
| `y` | Open yazi file manager (cd on exit) |
| `z <partial>` | Smart cd via zoxide |

### Yazi Keybinds

| Key | Action |
|-----|--------|
| `j/k` | Navigate |
| `h/l` | Parent / Enter |
| `Enter` | Open in editor |
| `/` | Search |
| `Space` | Select |
| `y` | Copy |
| `p` | Paste |
| `.` | Toggle hidden |
| `q` | Quit |

---

## Git Shortcuts

| Command | Expands to |
|---------|------------|
| `gst` | `git status` |
| `gco` | `git checkout` |
| `gcb` | `git checkout -b` |
| `gp` | `git push` |
| `gl` | `git pull` |
| `ga` | `git add` |
| `gc` | `git commit` |
| `gd` | `git diff` |
| `gds` | `git diff --staged` |
| `glog` | `git log --oneline -20` |

### Fuzzy Git (fzf-powered)

| Command | What it does |
|---------|--------------|
| `gco-fzf` | Fuzzy checkout branch |
| `glog-fzf` | Browse commits with preview |
| `gstash-fzf` | Fuzzy apply stash |
| `gadd-fzf` | Fuzzy stage files |

---

## PDS Commands

| Command | What it does |
|---------|--------------|
| `pds-init` | Install PDS skills to current project |
| `pds-update` | Update project skills to latest version |
| `pds-update -s` | Update system shell helpers (~/.pds) |
| `pds-uninstall` | Remove PDS, restore backups |
| `clauder` | Resume most recent Claude session |

---

## Claude Code Skills

See [Skills Catalog](skills.md) for full descriptions.

| Skill | Purpose |
|-------|---------|
| `/ethos` | Principles, MECE |
| `/commit` | Commit format |
| `/review` | PR checklist |
| `/debug` | Troubleshooting |
| `/test` | Test strategy |
| `/design` | Architecture |
| `/worktree` | Branch isolation |
| `/bootstrap` | New project |
| `/quickref` | Cheatsheet |
