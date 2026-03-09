---
description: Referencing the agent roster, roles, and coordination model. Use when spawning agents or checking permissions.
---
# /team — Agent Team Reference

Agent roster, permissions, and coordination model. See `/pds:swarm` for the 6-phase workflow.

## Agent Tiers

Research shows 3-4 subagents per swarm is optimal. Tier agents by spawning frequency:

### Core Tier (consider for every swarm)

| Agent | Role | Model | Mode | MaxTurns | Memory |
|-------|------|-------|------|----------|--------|
| **orchestrator** | Team lead — plans, decomposes, dispatches | opus | delegate | 100 | — |
| **worker** | Implementation in isolated worktrees | sonnet | acceptEdits | 50 | — |
| **validator** | Merge branches, run tests, report | sonnet | acceptEdits | 40 | — |
| **researcher** | Deep codebase exploration | sonnet | plan | 30 | project |

These map directly to the whitepaper's Agentic SDLC: orchestrator coordinates, workers execute (Phase 3), validator verifies (Phase 4), researcher gathers context (Phase 1).

### Specialist Tier (spawn when specifically needed)

| Agent | Role | Model | Mode | MaxTurns | Memory | When to Spawn |
|-------|------|-------|------|----------|--------|---------------|
| **reviewer** | Code review — quality, security | sonnet | plan | 25 | project | PRs, pre-human review |
| **documenter** | Documentation updates | sonnet | acceptEdits | 30 | — | User-facing docs changed |
| **scout** | PDS meta-improvements | haiku | acceptEdits | 15 | project | Post-swarm knowledge capture |
| **auditor** | Codebase analysis → GitHub issues | sonnet | plan | 30 | project | Periodic tech debt scans |

Specialists add value in specific situations but aren't needed every swarm. The orchestrator decides based on task requirements.

## Permission Modes

| Mode | Agents | Behavior |
|------|--------|----------|
| **delegate** | orchestrator | Coordination only — must delegate to agents |
| **acceptEdits** | worker, validator, documenter | Auto-accept file edits, full implementation access |
| **plan** | researcher, reviewer, auditor | Read-only exploration, no file modifications |
| **acceptEdits** (scoped) | scout | Write limited to `.claude/swarm/scout-report.md` and `.claude/instincts.md` |

## Coordination Model

```
                    ┌─────────────┐
                    │ orchestrator │  (your Claude session)
                    └──────┬──────┘
           ┌───────┬───────┼───────┬───────┬───────┐
           │       │       │       │       │       │
      researcher worker validator reviewer documenter scout/auditor
      (each spawned via Task tool with worktree isolation)
```

Agents coordinate via TaskCreate/TaskUpdate for status and SendMessage for communication. TeamCreate establishes the team and shared task list.

## New Agent Capabilities (Claude Code 2.1.50+)

| Feature | Description |
|---------|-------------|
| `isolation: worktree` | Declared in worker frontmatter — Claude Code provisions the worktree automatically. No manual `git worktree add` needed. |
| `Task(agent_type)` | Typed spawn syntax (e.g., `Task(worker)`, `Task(validator)`) — restricts which agent definitions can fulfill the spawn. Use this instead of `subagent_type=`. |
| `agent_id` / `agent_type` in hooks | Hook events expose these fields, enabling agent-aware routing in the PermissionRequest hook. |

## Core Principles

- **Progress in commits and task updates.** Commits and TaskUpdate are durable. Context is ephemeral.
- **Human gate.** Get approval at phase boundaries (planning, before PR).
- **Worktree isolation.** Each worker gets their own worktree. No shared state.
- **Fail fast.** Fix specific issues rather than retrying blindly.
