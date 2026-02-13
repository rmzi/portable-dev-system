# Team Setup

## Quick Start

```bash
# 1. Install PDS into your project
cd ~/your-project
pds-init

# 2. Commit the configuration
git add .claude CLAUDE.md
git commit -m "feat: add PDS"
```

Now every team member gets the same skills, agents, and conventions.

---

## Agent Teams

PDS includes 8 specialized agents for multi-agent orchestration. Each agent has a defined role, permission mode, and coordination protocol.

### Agent Roster

| Agent | Role | Model | Mode |
|-------|------|-------|------|
| orchestrator | Team lead — plans, decomposes, dispatches | opus | delegate |
| researcher | Deep codebase exploration | sonnet | plan |
| worker | Implementation in isolated worktrees | sonnet | acceptEdits |
| validator | Merge branches, run tests, report | sonnet | acceptEdits |
| reviewer | Code review — quality, security | sonnet | plan |
| documenter | Documentation updates | sonnet | acceptEdits |
| scout | PDS meta-improvements | haiku | plan |
| auditor | Codebase analysis → GitHub issues | sonnet | plan |

### Permission Modes

| Mode | Agents | Behavior |
|------|--------|----------|
| **delegate** | orchestrator | Coordination only — cannot implement, must delegate |
| **acceptEdits** | worker, validator, documenter | Auto-accept file edits, full implementation access |
| **plan** | researcher, reviewer, scout, auditor | Read-only exploration, no file modifications |

### File Protocol

Agents coordinate through files, not messages:

```
agent-worktree/.agent/
  task.md      # Orchestrator writes before spawning
  status.md    # Agent writes: pending | in_progress | done | blocked
  output.md    # Agent writes: results, reports, findings
```

### 6-Phase Agentic SDLC

```
Plan → Decompose → Dispatch → Validate → Consolidate → Knowledge
 │         │          │           │            │            │
 │    researcher   workers    validator      docs        scout
 │    + human      + tasks    + reviewer    + PR
 human gate                                human gate
```

See `/swarm` and `/team` skills for full workflow details.

---

## Customizing Skills

Add your own skills to `.claude/skills/`:

```
.claude/skills/
├── deploy.md      # Your deploy process
├── oncall.md      # Incident response
├── pr.md          # PR conventions
├── api.md         # API design guidelines
└── ...
```

### Skill Template

```markdown
---
description: One-line description for skill discovery
---
# /skill-name — Title

## When to Use
- Trigger conditions

## Process
1. Step one
2. Step two

## Checklist
- [ ] Item one
- [ ] Item two
```

---

## Permissions Model

PDS includes a velocity-focused `.claude/settings.json` that balances speed with safety.

### What's Auto-Allowed
- All read operations
- All file writes/edits within the repo
- All bash commands (with exceptions below)
- All MCP tools
- Web fetches and searches

### What's Blocked

**Credential paths** (never touched):
- `~/.aws`, `~/.ssh`, `~/.gnupg`
- `~/.config/gcloud`, `~/.databrickscfg`, `~/.netrc`

**Git guardrails**:
- Push to `main`, `master`, `dev`, `develop`
- Force push (`-f`, `--force`)
- Branch deletion via push

**Prod patterns**:
- Commands with `PROD`, `prod.`, `--profile prod`
- `ssh` and `scp` to remote hosts

**Sensitive files**:
- `.env`, `.env.*`, `secrets/`, `*.pem`, `*credential*`

### Customizing

Add to your repo's `.claude/settings.json`:

```json
{
  "permissions": {
    "deny": [
      "mcp__your_prod_tool__*",
      "Bash(*your-prod-db*)"
    ]
  }
}
```

---

## Addons

Addons extend Claude Code through independently maintained packages — skills, hooks, agents, and scripts that follow PDS conventions but have no PDS dependency.

See [Addons](addons.md) for the full specification and how to create one.

**Available addons:**
- [branch-tone](https://github.com/rmzi/branch-tone) — Audio cues for Claude Code events (task completion, permission requests)

---

## Keeping Skills Updated

When you update skills in your repo:
1. Team members pull changes
2. Skills are automatically available

For PDS core updates:
```bash
pds-update
```
