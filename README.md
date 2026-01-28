# Portable Development System

[![Shell](https://img.shields.io/badge/shell-zsh%20%7C%20bash-blue)](https://www.zsh.org/)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-compatible-blueviolet)](https://claude.ai/claude-code)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)
[![Terminal First](https://img.shields.io/badge/terminal-first-black?logo=gnometerminal)](https://en.wikipedia.org/wiki/Command-line_interface)

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
brew install yazi zoxide fzf ripgrep fd bat
```

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

```
┌────────────────────────────────────────────────┐
│ iTerm2 / Ghostty / Kitty                       │
│ ┌──────────────────────────────┬─────────────┐ │
│ │                              │             │ │
│ │   Shell / Claude Code        │    yazi     │ │
│ │                              │  (files)    │ │
│ │                              │             │ │
│ └──────────────────────────────┴─────────────┘ │
└────────────────────────────────────────────────┘

Split: Cmd+D (iTerm) or Ctrl-b | (tmux)
```

---

## Commands

### Worktree Management

| Command | What it does |
|---------|--------------|
| `wt` | Fuzzy pick a worktree → cd there |
| `wty` | Fuzzy pick a worktree → open in yazi |
| `wta feature/x` | Create worktree from existing branch |
| `wta -b feature/x` | Create worktree + new branch |
| `wtl` | List all worktrees |
| `wtr` | Fuzzy pick a worktree to remove |

### Navigation

| Command | What it does |
|---------|--------------|
| `y` | Open yazi file manager |
| `z <partial>` | Smart cd (learns your habits) |

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
