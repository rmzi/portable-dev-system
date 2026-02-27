<!-- PDS:START -->
# Portable Development System

AI-assisted development methodology. Skills for consistency. Agents for scale.

## Plugin Architecture

PDS is a Claude Code plugin. Skills and agents are distributed via the plugin system. Security settings are installed to `~/.claude/settings.json`.

### Workflow

1. **At session start**: The SessionStart hook checks for PDS updates automatically
2. **Before any task**: Check if a PDS skill exists for it — if so, read it first
3. **During work**: Follow skill documentation before performing actions
4. **When stuck**: Read `/pds:ethos` for principles, `/pds:grill` for structured thinking

### Rule

**Before performing ANY action, check if a skill exists for it. If a relevant skill exists, read it FIRST.**

### Available Skills (16)

| Skill | When to Use |
|-------|-------------|
| `/pds:ethos` | Starting work, when stuck, need principles |
| `/pds:swarm` | Launch agent team for parallel work |
| `/pds:team` | Agent roster, roles, capabilities |
| `/pds:grill` | Requirement interrogation before implementation |
| `/pds:verify` | Completion self-check before declaring done |
| `/pds:finish` | Branch completion protocol for merge readiness |
| `/pds:merge` | Merging subtask worktrees back to coordinator |
| `/pds:worktree` | Branch isolation, parallel work |
| `/pds:instinct` | Record, review, and promote engineering patterns |
| `/pds:sandbox` | OS-level sandbox config, network allowlist |
| `/pds:permission-router` | Permission hook policy, subagent routing |
| `/pds:audit-config` | Verify PDS setup is correct and secure |
| `/pds:trim` | Context efficiency maintenance |
| `/pds:contribute` | Contributing to PDS itself — whitepaper alignment |
| `/pds:bugfix` | Test-first bug fix loop |
| `/pds:bump` | Version bump and changelog update |

See `/pds:team` for the 8-agent roster (orchestrator, researcher, worker, validator, reviewer, documenter, scout, auditor).

---

## Project Structure

```
.claude-plugin/    — Plugin manifest (plugin.json)
agents/            — 8 agent definitions
skills/            — 16 workflow skills (dir/SKILL.md format)
hooks/             — SessionStart + PermissionRequest hooks
.claude/           — Security settings (deny rules, sandbox config)
docs/              — Philosophy, whitepaper, team setup
install.sh         — Plugin installer + security settings
VERSION            — Current version (semver)
CHANGELOG.md       — Release history
```

---

## Rules

### Worktree Hygiene

Use `git worktree add` for branch isolation — never `git clone` (clones disconnect history).

- Always inside repo: `.worktrees/feature-branch/`
- Never `/tmp/`, never `../` siblings
- Always resolve REPO_ROOT first (relative paths nest incorrectly inside worktrees):
  ```bash
  REPO_ROOT="$(git rev-parse --path-format=absolute --git-common-dir | sed 's|/.git$||')"
  git worktree add "$REPO_ROOT/.worktrees/name" -b branch
  ```
- Never use `git rev-parse --show-toplevel` (returns worktree root, not repo root)

### Workflow

**Read `/pds:contribute` before modifying PDS.** Skills, agents, SDLC phases, or coordination patterns require the whitepaper-alignment checklist.

**Create or update a PR after pushing.** Don't wait to be asked.
<!-- PDS:END -->
