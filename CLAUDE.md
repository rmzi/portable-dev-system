<!-- PDS:START -->
# Portable Development System

AI-assisted development methodology. Skills for consistency. Agents for scale.

## Skills System (MANDATORY)

**CRITICAL: Skills in `.claude/skills/` contain workflow patterns and requirements. Skipping relevant skills leads to inconsistent implementations and rework.**

### Workflow

1. **At session start**:
   - Check `.claude/.pds-version` against https://raw.githubusercontent.com/rmzi/portable-dev-system/main/VERSION
   - If outdated: update and commit:
     ```bash
     curl -sfL https://raw.githubusercontent.com/rmzi/portable-dev-system/main/install.sh | bash
     ```
   - Scan `.claude/skills/` to understand available capabilities
2. **Before any task**: Check if the task matches a skill (commit, review, debug, test, design, etc.)
3. **During work**: Read and follow the skill documentation before performing the action
4. **When stuck**: Read `/ethos` for principles, `/debug` for systematic troubleshooting

### Rule

**Before performing ANY action, check if a skill exists for it. If a relevant skill exists, read it FIRST.**

### Available Skills

| Skill | When to Use |
|-------|-------------|
| `/ethos` | Starting work, when stuck, need principles |
| `/commit` | Before any git commit |
| `/review` | Before submitting or reviewing PRs |
| `/debug` | When troubleshooting issues |
| `/test` | Writing or running tests |
| `/design` | Architecture decisions, new features |
| `/merge` | Merging subtask branches back to coordinator |
| `/bump` | Version bump and changelog update |
| `/permission-router` | Permission hook policy, subagent routing |
| `/team` | Agent roster, roles, capabilities |
| `/swarm` | Launch agent team for parallel work |
| `/quickref` | PDS skills, agents, and conventions reference |
| `/instinct` | Record, review, and promote engineering patterns |
| `/grill` | Requirement interrogation before implementation |
| `/contribute` | Contributing to PDS itself — whitepaper alignment |
| `/audit-config` | Verify PDS setup is correct and secure |
| `/bugfix` | Test-first bug fix loop |
| `/trim` | Context efficiency maintenance |
| `/verify` | Completion self-check before declaring done |
| `/finish` | Branch completion protocol for merge readiness |
| `/merge-main` | Merge approved PRs into main |

See `/team` for the 8-agent roster (orchestrator, researcher, worker, validator, reviewer, documenter, scout, auditor).

---

## Project Structure

```
.claude/skills/    — workflow skills (invoked via /skill-name)
.claude/agents/    — 8 agent definitions (orchestrator, researcher, worker, etc.)
.claude/settings.json — Permissions and security guardrails
docs/              — Philosophy, whitepaper, team setup, agent tooling
install.sh         — Installer for project-level or user-level PDS
VERSION            — Current version (semver)
CHANGELOG.md       — Release history
```

---

## Rules

**Use git worktrees for isolation.** Worktrees are managed natively by Claude Code. Never clone the repository — worktrees share git history and stay in sync.

**Read `/contribute` before modifying PDS.** Skills, agents, SDLC phases, or coordination patterns require the whitepaper-alignment checklist.

**Create or update a PR after pushing.** Don't wait to be asked.
<!-- PDS:END -->
