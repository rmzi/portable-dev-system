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

### Upgrading from v4.x?

No file-layout changes — a normal plugin update is enough unless you've forked `agents/orchestrator.md` or the swarm/team skills. See [v5.0.0 Migration Guide](docs/migration-v5.md) for details.

### Upgrading from v3.x?

Clean up old project-level files:

```bash
cd ~/your-project
curl -sfL https://raw.githubusercontent.com/rmzi/portable-dev-system/main/install.sh | bash -s -- --cleanup
```

See [v4.0.0 Migration Guide](docs/migration-v4.md) for details.

### Requirements

- **Claude Code** (CLI, desktop, or IDE extension)
- **jq** — used by hooks and pattern detection (`brew install jq` / `apt install jq`)
- **python3** — used by install script and hook scripts for JSON processing (`brew install python3` / `apt install python3`)

### Dev mode

```bash
git clone https://github.com/rmzi/portable-dev-system.git
cd portable-dev-system
make install    # symlinks this checkout as the plugin
```

---

## Skills (16)

| Skill | Purpose |
|-------|---------|
| `/pds:swarm` | Multi-agent team workflow (6-phase SDLC, lite/med/heavy tiers, branch merging) |
| `/pds:team` | Agent roster, coordination, and dispatch modes |
| `/pds:grill` | Requirement interrogation |
| `/pds:verify` | Completion self-check |
| `/pds:finish` | Branch completion protocol (includes quick ship) |
| `/pds:worktree` | Git worktree workflow |
| `/pds:contribute` | Contributing to PDS itself |
| `/pds:bugfix` | Test-first bug fix loop |
| `/pds:bump` | Version and changelog |
| `/pds:eval` | Skill evaluation and testing |
| `/pds:rebase` | Focused branch rebase |
| `/pds:pr-review` | Address PR review comments |
| `/pds:pause` | Save session state, WIP commit, resume later |
| `/pds:resume` | Reconstruct swarm state after pause, crash, or cross-machine/person handoff |
| `/pds:triage` | Triage insights into GitHub issues across repos |
| `/pds:explore` | Structural codebase queries via codebase-memory-mcp index (falls back to Grep) |

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
| auditor | Codebase quality -> GitHub issues | sonnet | plan |

[Full agent docs ->](docs/teams.md)

---

## Plugin Structure

```
portable-dev-system/
├── .claude-plugin/plugin.json     # Plugin manifest
├── agents/                        # 9 agent definitions + shared-rules.md
├── skills/                        # 15 skills (dir/SKILL.md format)
│   ├── swarm/SKILL.md
│   ├── team/SKILL.md
│   └── ...
├── hooks/hooks.json               # Hook event handlers (see below)
├── hooks/scripts/                 # Hook implementation scripts
├── scripts/                       # Utility scripts (detect-patterns, efficiency-chart)
├── docs/                          # Philosophy, whitepaper, team setup, source analysis
├── .claude/settings.json          # Security settings (installed separately)
├── install.sh                     # Plugin installer
├── Makefile                       # make install
├── VERSION
└── CHANGELOG.md
```

### Hook Events

PDS registers handlers for the following Claude Code hook events:

| Event | Handler | Purpose |
|-------|---------|---------|
| `SessionStart` | `session-start.sh` | Inject PDS version, key skills, worktree context |
| `Stop` | Prompt evaluator | Verify completion for implementation sessions |
| `TaskCompleted` | `task-completed-gate.sh` | Run tests on completed tasks |
| `TeammateIdle` | `teammate-idle-gate.sh` | Backpressure — detect idle workers, trigger remediation |
| `PreToolUse` | `secret-scrub.sh`, `secret-guard.sh` | Scrub secrets from command output, block credential leaks |
| `PostToolUse` | `mcp-secret-scrub.sh`, `telemetry-log.sh`, `file-telemetry-log.sh` | MCP output scrubbing, skill/file telemetry |
| `SubagentStart` | `roster-check.sh` | Enforce agent roster — warn on unknown agent types |
| `PreCompact` | `pre-compact-snapshot.sh` | Snapshot context before compaction |
| `PostCompact` | `post-compact-inject.sh` | Re-inject critical context after compaction |
| `UserPromptSubmit` | `skill-hint.sh`, `health-check.sh` | Suggest relevant skills, session health monitoring |
| `WorktreeCreate` | `worktree-telemetry.sh`, `sync-worktree-permissions.sh` | Telemetry, permission sync |
| `InstructionsLoaded` | `instructions-telemetry.sh` | Telemetry for rule file loading |

The orchestrator agent additionally uses `PreToolUse` hooks for SDLC phase gates.

---

## Permissions

Auto-allowed: all tools, bash (sandboxed — writes confined to CWD, network restricted to allowlist), MCP, web fetches

Blocked:
- Credential paths (`~/.aws`, `~/.ssh`, `~/.gnupg`, `~/.kube`, `~/.azure`, `~/.config/gh`, `~/.npmrc`, and more)
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
| [Migration Guide (v5)](docs/migration-v5.md) | Upgrading from v4.x |
| [Migration Guide (v4)](docs/migration-v4.md) | Upgrading from v3.x |
| [Philosophy](docs/philosophy.md) | Principles and motivation |
| [Core Principles](docs/ethos.md) | The seven development principles |
| [Team Setup](docs/teams.md) | Agent roster, permissions, team onboarding |
| [Whitepaper](docs/whitepaper.md) | Full technical depth — phases, isolation, governance |
| [Competitive Analysis](docs/competitive-analysis.md) | Landscape scan and PDS positioning |
| [Claude Code Source Analysis](docs/claude-code-source-analysis.md) | Architecture reverse-engineering (March 2026 snapshot) |
| [Extension Point Catalog](docs/claude-code-extension-catalog.md) | Hook events, settings hierarchy, plugin capabilities reference |

---

## Contributing

PRs welcome. Read `/pds:contribute` first. The knowledge phase of the agentic SDLC contributes improvements back to PDS automatically.

---

MIT — use it, fork it, make it yours.
