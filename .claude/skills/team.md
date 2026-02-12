---
description: Agent team roster showing roles, capabilities, and constraints
---
# /team — Agent Team Reference

Agent roster, permissions, and coordination model. See `/swarm` for the 6-phase workflow.

## Agent Roster

| Agent | Role | Model | Mode | MaxTurns | Memory |
|-------|------|-------|------|----------|--------|
| **orchestrator** | Team lead — plans, decomposes, dispatches | opus | delegate | 100 | — |
| **researcher** | Deep codebase exploration | sonnet | plan | 30 | project |
| **worker** | Implementation in isolated worktrees | sonnet | acceptEdits | 50 | — |
| **validator** | Merge branches, run tests, report | sonnet | acceptEdits | 40 | — |
| **reviewer** | Code review — quality, security | sonnet | plan | 25 | project |
| **documenter** | Documentation updates | sonnet | acceptEdits | 30 | — |
| **scout** | PDS meta-improvements | haiku | plan | 15 | project |
| **auditor** | Codebase analysis → GitHub issues | sonnet | plan | 30 | project |

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
