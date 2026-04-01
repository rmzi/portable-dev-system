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

### Requirements

- **Claude Code** (CLI, desktop, or IDE extension)
- **jq** — used by telemetry hooks and pattern detection (`brew install jq` / `apt install jq`)
- **python3** — used by install script and hook scripts for JSON processing (`brew install python3` / `apt install python3`)

### Dev mode

```bash
git clone https://github.com/rmzi/portable-dev-system.git
cd portable-dev-system
make install    # symlinks this checkout as the plugin
```

---

## Skills (23)

| Skill | Purpose |
|-------|---------|
| `/pds:ethos` | Development principles, MECE |
| `/pds:swarm` | Multi-agent team workflow (6-phase SDLC, lite/med/heavy tiers) |
| `/pds:team` | Agent roster and coordination |
| `/pds:grill` | Requirement interrogation |
| `/pds:verify` | Completion self-check |
| `/pds:finish` | Branch completion protocol |
| `/pds:merge` | Merging subtask worktrees back |
| `/pds:worktree` | Git worktree workflow |
| `/pds:instinct` | Pattern capture and lifecycle |
| `/pds:telemetry` | Usage telemetry — enable, disable, view reports, rotate |
| `/pds:inspect` | Real-time PDS state — swarm phase, tier, agents, telemetry |
| `/pds:sandbox` | OS-level sandbox configuration |
| `/pds:permission-router` | **Deprecated** — see /pds:sandbox |
| `/pds:audit-config` | Verify PDS config security |
| `/pds:trim` | Context efficiency maintenance |
| `/pds:contribute` | Contributing to PDS itself |
| `/pds:bugfix` | Test-first bug fix loop |
| `/pds:bump` | Version and changelog |
| `/pds:eval` | Skill evaluation and testing |
| `/pds:bcp` | Finalize work — bump, commit, push |
| `/pds:rebase` | Focused branch rebase |
| `/pds:pr-review` | Address PR review comments |
| `/pds:preflight` | Environment validation |

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
├── agents/                        # 8 agent definitions + shared-rules.md
├── skills/                        # 23 skills (dir/SKILL.md format)
│   ├── swarm/SKILL.md
│   ├── telemetry/SKILL.md         # Usage telemetry management
│   ├── inspect/SKILL.md           # Real-time PDS state viewer
│   └── ...
├── hooks/hooks.json               # 11 hook events: SessionStart, Stop, TaskCompleted, TeammateIdle, PostToolUse, SubagentStart, PreCompact, PostCompact, UserPromptSubmit, WorktreeCreate, InstructionsLoaded
├── hooks/scripts/                 # Hook implementation scripts
├── scripts/                       # Utility scripts (telemetry-summary, detect-patterns)
├── docs/                          # Philosophy, whitepaper, team setup, source analysis
├── .claude/settings.json          # Security settings (installed separately)
├── install.sh                     # Plugin installer
├── Makefile                       # make telemetry, make install
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
| [Claude Code Source Analysis](docs/claude-code-source-analysis.md) | Architecture reverse-engineering (March 2026 snapshot) |
| [Extension Point Catalog](docs/claude-code-extension-catalog.md) | Hook events, settings hierarchy, plugin capabilities reference |
| [Competitive Analysis](docs/competitive-analysis.md) | Market positioning vs. other AI dev tools |

---

## Contributing

PRs welcome. Read `/pds:contribute` first. The knowledge phase of the agentic SDLC contributes improvements back to PDS automatically.

---

MIT — use it, fork it, make it yours.
