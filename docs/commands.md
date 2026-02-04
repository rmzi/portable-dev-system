# Command Reference

## Worktree Management

| Command | What it does |
|---------|--------------|
| `wt` | Fuzzy pick a worktree → cd there |
| `wty` | Fuzzy pick a worktree → open tmux layout |
| `wta feature/x` | Create worktree from existing branch |
| `wta -b feature/x` | Create worktree + new branch |
| `wtl` | List all worktrees |
| `wtr` | Fuzzy pick a worktree to remove |

### Terminal Layout

`wty` creates this tmux layout:

```
┌──────────────────────────┬──────────────────┐
│                          │    terminal      │
│      Claude Code         ├──────────────────┤
│                          │      yazi        │
└──────────────────────────┴──────────────────┘
```

---

## Tmux Sessions

| Command | What it does |
|---------|--------------|
| `ts` | List tmux sessions |
| `ts <name>` | Attach to session (or create if doesn't exist) |
| `ts -n <name>` | Create new session |
| `tsk` | Fuzzy pick a session to kill |
| `twt` | Create/attach session named after current directory |
| `tl` | List sessions (alias) |
| `td` | Detach from current session |

**Tmux prefix:** `Ctrl-a` (not `Ctrl-b`)

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
