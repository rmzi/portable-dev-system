# Skills Catalog

Skills encode team knowledge and workflows. Claude reads and follows them automatically.

## Core Skills

| Skill | Purpose | When to Use |
|-------|---------|-------------|
| `/ethos` | Development principles, MECE | Starting work, when stuck, design decisions |
| `/commit` | Semantic commit format | Before any git commit |
| `/review` | Code review checklist | Before submitting or reviewing PRs |
| `/debug` | Systematic debugging process | Troubleshooting issues |
| `/test` | Test strategy and patterns | Writing or running tests |
| `/design` | Architecture decision records | New features, significant changes |
| `/worktree` | Git worktree workflow | Branch isolation, parallel work |
| `/quickref` | Command cheatsheet | Quick reference |
| `/swarm` | Tmux-native agent team workflow | Launching multi-agent parallel work |
| `/team` | Agent roster and coordination | Agent roles, permissions, file protocol |
| `/trim` | Context efficiency maintenance | Reducing skill/agent token footprint |
| `/bump` | Version and changelog updates | Releasing new versions |

---

## Skill Descriptions

### /ethos
Core principles: understand before acting, small reversible steps, tests as specification, explicit over implicit, MECE (Mutually Exclusive, Collectively Exhaustive). Read when starting significant work or when stuck.

### /commit
Semantic commit format with type prefixes (`feat:`, `fix:`, `docs:`, etc.). Ensures consistent, readable git history. Read before every commit.

### /review
Code review checklist covering correctness, design, tests, security, and documentation. Use before submitting PRs or when reviewing others' code.

### /debug
Systematic debugging: reproduce, isolate, hypothesize, test, fix, verify. Prevents thrashing. Read when troubleshooting any issue.

### /test
Test strategy: what to test, test types, naming conventions, coverage guidance. Read when writing new tests or improving existing ones.

### /design
Architecture Decision Records (ADRs) format. Documents the "why" behind significant decisions. Use for new features or architectural changes.

### /worktree
Git worktrees for isolated parallel development. Commands, naming conventions, workflow patterns. Use when working on multiple branches simultaneously.

### /quickref
Quick reference for common commands: git, tmux, shell helpers. Handy cheatsheet.

### /swarm
Tmux-native agent team workflow. Agents run as `claude -p` in their own tmux panes with file-based coordination (`.agent/task.md`, `status.md`, `output.md`). Use when a task benefits from parallel work by multiple agents.

### /team
Agent roster reference: 8 agents (orchestrator, researcher, worker, validator, reviewer, documenter, scout, auditor) with permission tiers and the 6-phase Agentic SDLC model.

### /trim
Context efficiency maintenance. Measures and reduces the token footprint of skills and agent definitions. Use when context is bloated.

### /bump
Version bump and changelog update workflow. Follows semantic versioning and Keep a Changelog format.

---

## Creating Custom Skills

Add team-specific skills to `.claude/skills/`:

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

Examples:
- `/deploy` — Your deployment process
- `/oncall` — Incident response runbook
- `/api` — API design guidelines
- `/pr` — PR conventions
