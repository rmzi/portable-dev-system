---
description: Agent team roster showing roles, capabilities, and constraints
---
# /team — Agent Team Reference

Agent roster, permissions, and coordination model. See `/swarm` for the 6-phase workflow.

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
| **scout** | PDS meta-improvements | haiku | plan | 15 | project | Post-swarm knowledge capture |
| **auditor** | Codebase analysis → GitHub issues | sonnet | plan | 30 | project | Periodic tech debt scans |

Specialists add value in specific situations but aren't needed every swarm. The orchestrator decides based on task requirements.

## Permission Modes

| Mode | Agents | Behavior |
|------|--------|----------|
| **delegate** | orchestrator | Coordination only — must delegate to agents |
| **acceptEdits** | worker, validator, documenter | Auto-accept file edits, full implementation access |
| **plan** | researcher, reviewer, scout, auditor | Read-only exploration, no file modifications |

## Coordination Model

```
                    ┌─────────────┐
                    │ orchestrator │  (your Claude session)
                    └──────┬──────┘
           ┌───────┬───────┼───────┬───────┬───────┐
           │       │       │       │       │       │
      researcher worker validator reviewer documenter scout/auditor
      (each in own worktree, running claude -p)
```

Orchestrator writes `.agent/task.md` before spawning. Agents update `.agent/status.md` and write results to `.agent/output.md`.

## File Protocol

```
agent-worktree/.agent/
  task.md      # Orchestrator writes before spawning
  status.md    # Agent writes: pending | in_progress | done | blocked
  output.md    # Agent writes: results, reports, findings
```

## Core Principles

- **Progress in files, not context.** Commits and task updates are durable.
- **Human gate.** Get approval at phase boundaries (planning, before PR).
- **Worktree isolation.** Each worker gets their own worktree. No shared state.
- **Fail fast.** Fix specific issues rather than retrying blindly.
