# Portable Development System

[![Shell](https://img.shields.io/badge/shell-zsh%20%7C%20bash-blue)](https://www.zsh.org/)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-compatible-blueviolet)](https://claude.ai/claude-code)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)
[![Terminal First](https://img.shields.io/badge/terminal-first-black?logo=gnometerminal)](https://en.wikipedia.org/wiki/Command-line_interface)
[![macOS](https://img.shields.io/badge/macOS-supported-000000?logo=apple)](https://www.apple.com/macos/)
[![Linux](https://img.shields.io/badge/Linux-supported-FCC624?logo=linux&logoColor=black)](https://www.linux.org/)
[![Ghostty](https://img.shields.io/badge/Ghostty-ready-orange)](https://ghostty.org/)
[![tmux](https://img.shields.io/badge/tmux-supported-1BB91F)](https://github.com/tmux/tmux)

A terminal-first, AI-assisted development methodology designed for **isolation**, **clarity**, and **craft**.

> "Simplicity is prerequisite for reliability." — Edsger Dijkstra

---

## Why This Exists

Modern IDEs are bloated. Context switching between AI tools is exhausting. `git stash` is where work goes to die.

This system fixes that:
- **Terminal + Claude Code** as your primary interface
- **Worktrees** for true branch isolation (no more stashing)
- **Skills** that encode team best practices
- **One setup** that works across all your projects

---

## 30-Second Setup

### 1. Install tools

```bash
# macOS
brew install yazi zoxide fzf ripgrep fd bat starship tmux

# Ubuntu/Debian
sudo apt install fzf ripgrep fd-find bat tmux
# + install yazi, zoxide, starship from their repos (see links below)

# Arch
sudo pacman -S yazi zoxide fzf ripgrep fd bat starship tmux
```

> **Note:** [yazi](https://github.com/sxyazi/yazi), [zoxide](https://github.com/ajeetdsouza/zoxide), and [starship](https://starship.rs) have install instructions for all platforms.

### 2. Grab the shell helpers

```bash
curl -fsSL https://raw.githubusercontent.com/rmzi/portable-dev-system/main/install.sh | bash
```

Or manually copy the functions from [shell-helpers.sh](./shell-helpers.sh) to your `~/.zshrc`.

### 3. Copy skills to your project

```bash
cp -r .claude/ /path/to/your/project/
```

Done. You now have superpowers.

---

## What's Included

| File | Purpose |
|------|---------|
| `shell-helpers.sh` | Worktree, tmux, git, and navigation functions |
| `tmux.conf` | Tmux configuration (prefix, splits, navigation) |
| `ghostty.config` | Ghostty terminal config (splits, keybinds, quick terminal) |
| `starship.toml` | Cross-shell prompt with git info |
| `.claude/skills/` | Claude Code skills for your workflow |
| `.claude/hooks.json` | Pre-configured Claude hooks |
| `.claude/settings.json` | Claude Code settings |
| `install.sh` | Automated installer |

### Optional: Tmux + Starship

```bash
# Copy tmux config
cp tmux.conf ~/.tmux.conf

# Copy starship config
mkdir -p ~/.config && cp starship.toml ~/.config/starship.toml

# Add to ~/.zshrc
eval "$(starship init zsh)"
```

### Optional: Ghostty (recommended)

If you use [Ghostty](https://ghostty.org/), you can use native splits instead of tmux for local dev:

```bash
# Copy Ghostty config
mkdir -p ~/.config/ghostty && cp ghostty.config ~/.config/ghostty/config
```

**Ghostty keybindings included:**

| Action | macOS | Linux |
|--------|-------|-------|
| Split right | `Cmd+D` | `Ctrl+Shift+D` |
| Split down | `Cmd+Shift+D` | `Ctrl+Shift+S` |
| Navigate splits | `Alt+H/J/K/L` | `Alt+H/J/K/L` |
| Zoom split | `Cmd+Shift+Z` | `Ctrl+Shift+Z` |
| Quick terminal | `Cmd+`` ` | `Super+`` ` |

**When to use Ghostty vs tmux:**
- **Ghostty native splits**: Local dev, quick sessions, lighter weight
- **tmux**: Remote SSH, persistent sessions, detach/reattach

Both work great together — use Ghostty for the terminal, tmux when you need persistence.

---

## For Teams

### Shared Skills = Shared Standards

Drop `.claude/` into your repo root. Every team member gets:
- Same code review checklist (`/review`)
- Same commit conventions (`/commit`)
- Same debugging protocol (`/debug`)
- Same architecture decision format (`/design`)

**No more "how do we do X here?"** — it's encoded in the skills.

### Onboarding in 5 Minutes

New team member? They run the setup, clone the repo, and they have:
- All your team's conventions
- Worktree workflow ready
- Claude Code skills loaded

### Customize for Your Team

Fork this repo and add your own skills:

```
.claude/skills/
├── deploy.md      # Your deploy process
├── oncall.md      # Incident response
├── pr.md          # PR conventions
└── ...
```

---

## Terminal Layout

The `wty` command creates this tmux layout:

```
┌────────────────────────────────────────────────┐
│ iTerm2 / Ghostty / Kitty                       │
│ ┌──────────────────────────┬──────────────────┐│
│ │                          │    terminal      ││
│ │      Claude Code         ├──────────────────┤│
│ │                          │      yazi        ││
│ └──────────────────────────┴──────────────────┘│
└────────────────────────────────────────────────┘
```

Or manually split: `Cmd+D` (iTerm) or `Ctrl-b |` (tmux)

---

## Commands

### Worktree Management

| Command | What it does |
|---------|--------------|
| `wt` | Fuzzy pick a worktree → cd there |
| `wty` | Fuzzy pick a worktree → open tmux layout (Claude + terminal + yazi) |
| `wtyg` | Fuzzy pick a worktree → cd there (use Ghostty native splits) |
| `wta feature/x` | Create worktree from existing branch |
| `wta -b feature/x` | Create worktree + new branch |
| `wtl` | List all worktrees |
| `wtr` | Fuzzy pick a worktree to remove |

### Navigation

| Command | What it does |
|---------|--------------|
| `y` | Open yazi file manager |
| `z <partial>` | Smart cd (learns your habits) |

### Tmux Sessions

| Command | What it does |
|---------|--------------|
| `ts` | List tmux sessions |
| `ts <name>` | Attach to session (or create if doesn't exist) |
| `ts -n <name>` | Create new session |
| `tsk` | Fuzzy pick a session to kill |
| `twt` | Create/attach session named after current directory |
| `tl` | List sessions (alias) |
| `td` | Detach from current session |

### Git Shortcuts

| Command | What it does |
|---------|--------------|
| `gst` | `git status` |
| `gco <branch>` | `git checkout` |
| `gcb <branch>` | `git checkout -b` (new branch) |
| `gp` | `git push` |
| `gl` | `git pull` |
| `ga <files>` | `git add` |
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

### Claude Code Skills

| Skill | Purpose |
|-------|---------|
| `/ethos` | Core principles (read when stuck) |
| `/worktree` | Worktree workflow guide |
| `/wt` | Worktree commands reference |
| `/review` | Code review checklist |
| `/commit` | Semantic commit format |
| `/debug` | Systematic debugging |
| `/design` | Architecture decision records |
| `/test` | Test strategy guide |
| `/bootstrap` | New project setup |
| `/quickref` | Terminal cheatsheet |

---

## Worktree Workflow

**The problem:** You're mid-feature, urgent bug comes in. You `git stash`, fix it, come back, forget what you were doing.

**The fix:** Worktrees.

```bash
# Working on feature
cd ~/dev/myproject
wta -b feature/auth

# Urgent bug? New terminal:
cd ~/dev/myproject      # or just: wt → pick main
wta -b hotfix/critical

# Two completely isolated environments
# No stashing. No branch switching. No lost context.

# Done with hotfix?
wtr   # Pick and remove
```

Each worktree:
- ✅ Own working directory
- ✅ Own Claude Code session
- ✅ Shares git history
- ✅ True isolation

---

## Yazi Keybinds

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

## Philosophy

### The Seven Principles

1. **Understand before you act** — Read code before changing it
2. **Small, reversible steps** — Atomic commits, small PRs
3. **Tests as specification** — Tests document intent
4. **Explicit over implicit** — No magic, no hidden conventions
5. **Optimize for change** — Code is read 10x more than written
6. **Fail fast, recover gracefully** — Validate at boundaries
7. **Automation as documentation** — Scripts > READMEs

### The Giants

Built on wisdom from:
- **Thompson & Ritchie** — Unix philosophy
- **Kent Beck** — TDD, XP
- **Martin Fowler** — Refactoring, CI/CD
- **Sandi Metz** — Practical OO
- **Rich Hickey** — Simple vs easy

---

## Contributing

PRs welcome. Add skills, improve docs, share what works for your team.

```bash
# Fork, clone, branch
wta -b feature/my-improvement

# Make changes, commit
# /commit for the format

# PR it
```

---

## License

MIT — use it, fork it, make it yours.
