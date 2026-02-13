# Portable Development System

[![Claude Code](https://img.shields.io/badge/Claude%20Code-compatible-blueviolet)](https://claude.ai/claude-code)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

**Software for Claude.** Skills encode best practices. Agents provide structure. Configuration enables velocity.

> Install PDS into any project. Claude reads it, follows it, improves it.

---

## What PDS Is

PDS is a Claude Code configuration package — skills, agents, settings, and hooks that make Claude effective at software development.

- **Skills** — Encoded workflows: commit conventions, code review checklists, debugging protocols, test strategies
- **Agents** — 8 specialized roles: orchestrator, researcher, worker, validator, reviewer, documenter, scout, auditor
- **Settings** — Velocity-focused permissions with security guardrails
- **Hooks** — Automated quality gates on tool usage

PDS is **editor-agnostic**. It works with any tool that runs Claude Code — terminal, Cursor, VS Code, or [Zaku](https://github.com/rmzi/zaku).

---

## Quick Start

```bash
# Install PDS skills into your project
cd ~/your-project
pds-init
```

Or manually:

```bash
# Copy .claude/ directory from this repo into your project
cp -r .claude/ ~/your-project/.claude/
cp CLAUDE.md ~/your-project/CLAUDE.md
```

---

## Skills

| Skill | Purpose |
|-------|---------|
| `/ethos` | Development principles, MECE |
| `/commit` | Semantic commit format |
| `/review` | Code review checklist |
| `/debug` | Systematic troubleshooting |
| `/test` | Test strategy and patterns |
| `/design` | Architecture decision records |
| `/worktree` | Git worktree workflow |
| `/merge` | Merging subtask worktrees back |
| `/eod` | End-of-day cleanup across repos |
| `/swarm` | Multi-agent team workflow |
| `/team` | Agent roster and coordination |
| `/trim` | Context efficiency maintenance |
| `/bump` | Version and changelog |
| `/permission-router` | Permission hook policy |
| `/quickref` | Command cheatsheet |

[Full skills catalog →](docs/skills.md)

---

## Agents

| Agent | Role | Model | Mode |
|-------|------|-------|------|
| orchestrator | Coordination — plans, decomposes, dispatches | opus | delegate |
| researcher | Deep codebase exploration | sonnet | plan |
| worker | Implementation in isolated worktrees | sonnet | acceptEdits |
| validator | Merge, test, verify acceptance criteria | sonnet | acceptEdits |
| reviewer | Code review — quality, security | sonnet | plan |
| documenter | Documentation updates | sonnet | acceptEdits |
| scout | PDS meta-improvements | haiku | plan |
| auditor | Codebase quality → GitHub issues | sonnet | plan |

[Full agent docs →](docs/teams.md)

---

## Worktrees

PDS uses git worktrees for branch isolation — no stashing, no context switching. Worktrees live inside the repo at `.worktrees/`:

```
project/                              # main worktree (main/master)
project/.worktrees/feature-auth/      # feature work
project/.worktrees/hotfix-login/      # urgent fix
project/.worktrees/task-1-api/        # agent worktree
```

`.worktrees/` is auto-added to `.gitignore`. Never use `/tmp` or sibling directories (`../`) for worktrees.

---

## Permissions

Auto-allowed: all tools, bash, MCP, web fetches

Blocked:
- Credential paths (`~/.aws`, `~/.ssh`, `~/.gnupg`)
- Git push to `main`/`master`/`dev`/`develop`
- Force push, `ssh`, `scp`
- Prod patterns (`PROD`, `prod.`, `--profile prod`)

---

## For Teams

```bash
pds-init && git add .claude CLAUDE.md && git commit -m "feat: add PDS"
```

Every team member gets the same skills, agents, and conventions.

---

## Documentation

| Doc | Purpose |
|-----|---------|
| [Philosophy](docs/philosophy.md) | Principles and motivation |
| [Skills Catalog](docs/skills.md) | Full skill descriptions |
| [Team Setup](docs/teams.md) | Agent roster, permissions, team onboarding |
| [Proposal](docs/proposal.md) | Shareable overview of the agentic SDLC |
| [Whitepaper](docs/whitepaper.md) | Full technical depth — phases, isolation, governance |
| [Agent Tooling](docs/agent-tooling.md) | Subtask + Ralph Wiggum execution patterns |

---

## Contributing

PRs welcome. The knowledge phase of the agentic SDLC contributes improvements back to PDS automatically.

---

MIT — use it, fork it, make it yours.
