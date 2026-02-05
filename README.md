# Portable Development System

[![Shell](https://img.shields.io/badge/shell-zsh%20%7C%20bash-blue)](https://www.zsh.org/)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-compatible-blueviolet)](https://claude.ai/claude-code)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

**Terminal-first, AI-assisted development.** Worktrees for isolation. Skills for consistency.

> "Simplicity is prerequisite for reliability." — Edsger Dijkstra

---

## The Problem

- IDEs are bloated
- Context switching kills flow
- `git stash` is where work goes to die
- Every project has different conventions

## The Fix

- **Terminal + Claude Code** as your primary interface
- **Worktrees** for true branch isolation
- **Skills** that encode your team's best practices
- **One setup** across all projects

---

## Quick Start

```bash
# 1. Install dependencies
brew install yazi zoxide fzf ripgrep fd bat starship tmux lazygit

# 2. Run installer
curl -fsSL https://raw.githubusercontent.com/rmzi/portable-dev-system/main/install.sh | bash

# 3. Add skills to your project
cd ~/your-project && pds-init
```

---

## Key Commands

| Command | What it does |
|---------|--------------|
| `wty` | Open worktree in tmux layout (Claude + terminal + yazi) |
| `wta -b feature/x` | Create new worktree + branch |
| `pds-init` | Install skills to current project |
| `pds-update` | Update skills to latest version |
| `pds-addon branch-tone install` | Optional audio feedback |
| `clauder` | Resume Claude session |

**Skills:** `/commit` `/review` `/debug` `/test` `/design` `/worktree`

---

## Docs

| Topic | Link |
|-------|------|
| Skills catalog | [docs/skills.md](docs/skills.md) |
| Command reference | [docs/commands.md](docs/commands.md) |
| Installation details | [docs/install.md](docs/install.md) |
| Team setup | [docs/teams.md](docs/teams.md) |
| Philosophy | [docs/philosophy.md](docs/philosophy.md) |

---

## For Teams

```bash
# Add to your repo
pds-init && git add .claude CLAUDE.md && git commit -m "Add PDS skills"
```

Every team member gets the same:
- Code review checklist (`/review`)
- Commit conventions (`/commit`)
- Debugging protocol (`/debug`)

**No more "how do we do X here?"** — it's in the skills.

[Full team setup →](docs/teams.md)

---

## Permissions Model

PDS includes a velocity-focused `.claude/settings.json` — like `--dangerously-skip-permissions` but with guardrails.

**Auto-allowed:** all tools, bash, MCP, web fetches

**Blocked:**
- Credential paths (`~/.aws`, `~/.ssh`, `~/.gnupg`)
- Git push to `main`/`master`/`dev`/`develop`
- Force push, `ssh`, `scp`
- Prod patterns (`PROD`, `prod.`, `--profile prod`)

[Full permissions docs →](docs/teams.md#permissions-model)

---

## Contributing

PRs welcome. Add skills, improve docs, share what works.

```bash
wta -b feature/my-improvement
# Make changes
# /commit for the format
```

---

MIT — use it, fork it, make it yours.
