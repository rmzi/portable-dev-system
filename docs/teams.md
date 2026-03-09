# Team Setup

## Quick Start

```bash
# 1. Install the PDS plugin (once per machine)
claude mcp install-marketplace pds

# 2. (Optional) For team-shared project configuration:
cd ~/your-project
pds install --project
git add .claude CLAUDE.md .gitignore
git commit -m "feat: add PDS"
```

For individual use, the marketplace install is all you need — PDS skills and agents are available in every Claude session. For teams, `--project` commits shared configuration to the repo so `git pull` is the only onboarding step.

---

## What Gets Committed

Most projects need zero PDS files — the plugin provides all skills, agents, and conventions. Only commit project-specific overrides.

### Committed (shared with team, optional)

| Path | Purpose |
|------|---------|
| `CLAUDE.md` | Project rules — always loaded into context |
| `.claude/settings.json` | Permissions and environment — project overrides |

PDS core skills and agents are provided by the plugin and do not need to be committed. Only commit project-specific overrides.

### Not committed (user-local)

| Path | Purpose |
|------|---------|
| `~/.claude/settings.json` | User-level overrides (merged with project settings) |
| `~/.claude/CLAUDE.md` | Personal rules across all projects |
| `.worktrees/` | Git worktrees (auto-added to `.gitignore`) |

### How settings merge

Claude Code merges settings from multiple levels. Project `.claude/settings.json` provides the shared baseline. Each team member can add personal overrides in `~/.claude/settings.json` without affecting the repo. Deny rules are additive — a user can add stricter rules but cannot remove project-level denies.

---

## Clean Install for New Team Members

### Prerequisites

- [Claude Code](https://claude.ai/claude-code) installed and authenticated
- PDS plugin installed: `claude mcp install-marketplace pds`
- Git access to the repository

### Steps

```bash
# 1. Clone the repo
git clone <repo-url> && cd <repo>

# 2. Start Claude Code — PDS is active immediately
claude
```

The plugin provides all PDS skills and agents. Project-specific settings (if any) are in the repo. Claude reads them on session start.

### First session checklist

On first use, Claude will:
1. Read `CLAUDE.md` and load PDS plugin skills
2. Check Linux sandbox dependencies (SessionStart hook)
3. Follow PDS conventions for commits, reviews, debugging, etc.

### Adding PDS to an existing project

If the repo doesn't have PDS configuration yet:

```bash
# Install the plugin (if not already installed)
claude mcp install-marketplace pds

# (Optional) Commit project-specific settings
cd ~/your-project
pds install --project
git add .claude CLAUDE.md .gitignore
git commit -m "feat: add PDS configuration"
```

### Customizing for your team

Add team-specific skills without modifying PDS core:

```bash
# Create team-specific skills in .claude/skills/ (project-level)
mkdir -p .claude/skills
cat > .claude/skills/deploy.md << 'EOF'
---
description: Team deploy process
---
# /deploy — Deploy Workflow
Your deploy steps here...
EOF

# Add team-specific deny rules
# Edit .claude/settings.json permissions.deny array
```

PDS plugin skills and project-level skills coexist. Plugin skills use the `pds:` namespace (e.g., `/pds:swarm`). Project skills use their own names (e.g., `/deploy`).

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
| scout | PDS meta-improvements | haiku | acceptEdits |
| auditor | Codebase analysis → GitHub issues | sonnet | plan |

### Permission Modes

| Mode | Agents | Behavior |
|------|--------|----------|
| **delegate** | orchestrator | Coordination only — cannot implement, must delegate |
| **acceptEdits** | worker, validator, documenter, scout | Auto-accept file edits, full implementation access |
| **plan** | researcher, reviewer, auditor | Read-only exploration, no file modifications |

### Coordination

Agents coordinate via native Claude Code tools:
- **TaskCreate/TaskUpdate** — Task definition, status tracking, and dependencies
- **SendMessage** — Direct and broadcast communication between agents
- **TeamCreate** — Team setup with shared task list

### 6-Phase Agentic SDLC

```
Plan → Decompose → Dispatch → Validate → Consolidate → Knowledge
 │         │          │           │            │            │
 │    researcher   workers    validator      docs        scout
 │    + human    (worktrees)  + reviewer    + PR
 human gate                                human gate
```

See `/pds:swarm` and `/pds:team` skills for full workflow details.

---

## Customizing Skills

Add your own project-level skills to `.claude/skills/`:

```
.claude/skills/
├── deploy.md      # Your deploy process
├── oncall.md      # Incident response
├── pr.md          # PR conventions
├── api.md         # API design guidelines
└── ...
```

These coexist with PDS plugin skills (`/pds:*`). Project skills are invoked without a namespace prefix.

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
- All bash commands — sandboxed (writes confined to CWD, network restricted to allowlist)
- All MCP tools (via `mcp__*` wildcard — see note below)
- Web fetches and searches

### What's Blocked

**Credential paths** (never touched):
- `~/.aws`, `~/.ssh`, `~/.gnupg`, `~/.kube`, `~/.azure`
- `~/.config/gcloud`, `~/.config/gh`, `~/.config/hub`
- `~/.databrickscfg`, `~/.netrc`, `~/.npmrc`, `~/.pypirc`
- `~/.docker/config.json`, `~/.gem/credentials`, `~/.cargo/credentials`

**Git guardrails**:
- Push to `main`, `master`, `dev`, `develop`
- Force push (`-f`, `--force`)
- Branch deletion via push

**Prod patterns**:
- Commands with `PROD`, `prod.`, `--profile prod`
- `ssh` and `scp` to remote hosts

**Sensitive files**:
- `.env`, `.env.*`, `secrets/`, `*.pem`, `*credential*`
- `.git-credentials`, `id_rsa*`, `id_ed25519*`, `*secret*key*`, `*token*.json`

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

### Sandbox

PDS enables Claude Code's native OS-level sandbox for all Bash commands. The sandbox (Seatbelt on macOS, bubblewrap on Linux) confines filesystem writes to the current working directory and restricts network access to an allowlist of domains.

**Key behaviors:**
- Sandboxed Bash commands auto-approve without permission prompts (`autoAllowBashIfSandboxed: true`)
- `git` and `docker` are excluded from the sandbox — they go through normal deny rules and the PermissionRequest hook
- Workers are OS-confined to their worktree directory for writes
- Cross-worktree reads work via Bash on absolute paths (sandbox allows broad reads)

**`mcp__*` wildcard risk:** The default `mcp__*` permission auto-approves all MCP tools from any configured server. For security-sensitive environments, replace with explicit allowlists per MCP server (e.g., `mcp__github__create_pull_request`).

See `/pds:sandbox` skill for full configuration reference and customization guide.

---

## Keeping Skills Updated

When you update skills in your repo:
1. Team members pull changes
2. Skills are automatically available

For PDS core updates, re-run the install script:
```bash
curl -sfL https://raw.githubusercontent.com/rmzi/portable-dev-system/main/install.sh | bash
```
