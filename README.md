# Portable Development System

[![Claude Code](https://img.shields.io/badge/Claude%20Code-plugin-blueviolet)](https://claude.ai/claude-code)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

**A Claude Code plugin.** Skills for consistency. Agents for scale. Install once, works across all projects.

> PDS is deployed as a Claude Code plugin — skills, agents, hooks, and security settings. Install it to `~/.claude/plugins/pds/`. Claude reads it, follows it, improves it.

---

## Quick Start

### Install via marketplace (recommended)

Inside Claude Code:
```
/plugin marketplace add rmzi/portable-dev-system
/plugin install pds@pds-marketplace
```

Restart Claude Code. PDS skills and agents are now available across all projects.

### Install via script

```bash
curl -sfL https://raw.githubusercontent.com/rmzi/portable-dev-system/main/install.sh | bash
```

Installs the plugin to `~/.claude/plugins/pds/` and security settings to `~/.claude/settings.json`.

### Upgrading from v3.x?

Clean up old project-level files:

```bash
cd ~/your-project
curl -sfL https://raw.githubusercontent.com/rmzi/portable-dev-system/main/install.sh | bash -s -- --cleanup
```

See [Migration Guide](docs/migration-v4.md) for details.

### Dev mode

```bash
git clone https://github.com/rmzi/portable-dev-system.git
cd portable-dev-system
make install    # symlinks this checkout as the plugin
```

---

## Skills (18)

| Skill | Purpose |
|-------|---------|
| `/pds:ethos` | Development principles, MECE |
| `/pds:swarm` | Multi-agent team workflow (6-phase Agentic SDLC) |
| `/pds:team` | Agent roster and coordination |
| `/pds:grill` | Requirement interrogation |
| `/pds:verify` | Completion self-check |
| `/pds:finish` | Branch completion protocol |
| `/pds:merge` | Merging subtask worktrees back |
| `/pds:worktree` | Git worktree workflow |
| `/pds:instinct` | Pattern capture and lifecycle |
| `/pds:sandbox` | OS-level sandbox configuration |
| `/pds:permission-router` | Permission hook policy |
| `/pds:audit-config` | Verify PDS config security |
| `/pds:trim` | Context efficiency maintenance |
| `/pds:contribute` | Contributing to PDS itself |
| `/pds:bugfix` | Test-first bug fix loop |
| `/pds:bump` | Version and changelog |
| `/pds:eval` | Skill evaluation and testing |
| `/pds:bcp` | Finalize work — bump, commit, push |

---

## Agents (8)

| Agent | Role | Model | Mode |
|-------|------|-------|------|
| orchestrator | Coordination — plans, decomposes, dispatches | opus | default |
| researcher | Deep codebase exploration | sonnet | plan |
| worker | Implementation in isolated worktrees | sonnet | acceptEdits |
| validator | Merge, test, verify acceptance criteria | sonnet | acceptEdits |
| reviewer | Code review — quality, security | sonnet | plan |
| documenter | Documentation updates | sonnet | acceptEdits |
| scout | PDS meta-improvements | haiku | acceptEdits |
| auditor | Codebase quality → GitHub issues | sonnet | plan |

[Full agent docs →](docs/teams.md)

---

## Plugin Structure

```
portable-dev-system/
├── .claude-plugin/plugin.json     # Plugin manifest
├── agents/                        # 8 agent definitions
├── skills/                        # 18 skills (dir/SKILL.md format)
│   ├── swarm/SKILL.md
│   ├── team/SKILL.md
│   └── ...
├── hooks/hooks.json               # SessionStart, Stop, TaskCompleted, TeammateIdle, WorktreeCreate, InstructionsLoaded hooks + PermissionRequest routing
├── .claude/settings.json          # Security settings (installed separately)
├── install.sh                     # Plugin installer
├── VERSION
└── CHANGELOG.md
```

---

## Permissions

Auto-allowed: all tools, bash (sandboxed — writes confined to CWD, network restricted to allowlist), MCP, web fetches

Blocked:
- Credential paths (`~/.aws`, `~/.ssh`, `~/.gnupg`, `~/.kube`, `~/.azure`, `~/.config/gh`, `~/.npmrc`, and more)
- Git push to `main`/`master`/`dev`/`develop`
- Force push, `ssh`, `scp`
- Prod patterns (`PROD`, `prod.`, `--profile prod`)
- Sensitive files (`.env`, `*.pem`, `*credential*`, `id_rsa*`, `*secret*key*`)

---

## What Lives Where

| Source | What | Example |
|--------|------|---------|
| **Plugin** (user-level) | Skills, agents, hooks | `/pds:swarm`, `orchestrator` agent |
| **Project** (optional) | Team overrides, project rules | `.claude/settings.json`, `CLAUDE.md` |
| **Project** (optional) | Learned patterns | `.claude/instincts.md` |

Most projects need **zero local PDS files**. The plugin provides everything. Add project-level files only when your team needs custom deny rules or project-specific `CLAUDE.md` rules.

---

## Documentation

| Doc | Purpose |
|-----|---------|
| [Migration Guide](docs/migration-v4.md) | Upgrading from v3.x |
| [Philosophy](docs/philosophy.md) | Principles and motivation |
| [Team Setup](docs/teams.md) | Agent roster, permissions, team onboarding |
| [Whitepaper](docs/whitepaper.md) | Full technical depth — phases, isolation, governance |

---

## Contributing

PRs welcome. Read `/pds:contribute` first. The knowledge phase of the agentic SDLC contributes improvements back to PDS automatically.

---

MIT — use it, fork it, make it yours.
