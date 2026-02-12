---
description: Agent team roster showing roles, capabilities, and constraints
---
# /team — Agent Team Reference

Agent roster, permissions, and coordination model for PDS multi-agent orchestration.

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
| **delegate** | orchestrator | Coordination only — cannot implement directly, must delegate to agents |
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

**File-based coordination:**

- Orchestrator writes `.agent/task.md` to each worktree before spawning
- Agents read their task, update `.agent/status.md`, write results to `.agent/output.md`
- Orchestrator monitors by reading `.agent/status.md` and `.agent/output.md` files

## File Protocol

```
agent-worktree/.agent/
  task.md      # Orchestrator writes before spawning agent
  status.md    # Agent writes: pending | in_progress | done | blocked
  output.md    # Agent writes: results, reports, findings
```

## 6-Phase Agentic SDLC

```
Plan → Decompose → Dispatch → Validate → Consolidate → Knowledge
 │         │          │           │            │            │
 │    researcher   workers    validator      docs        scout
 │    + human      + tasks    + reviewer    + PR
 human gate                                human gate
```

1. **Plan** — Refine requirements into acceptance criteria (human gate)
2. **Decompose** — Split into tasks, create worktrees, write `.agent/task.md`
3. **Dispatch** — Spawn agents in their worktrees
4. **Validate** — Merge, test, review, fix
5. **Consolidate** — PR + docs (human gate)
6. **Knowledge** — Meta-improvements, lessons

## Core Principles

- **Progress in files, not context.** Commits and task updates are durable. Context windows are not.
- **Human gate.** Get human approval at phase boundaries (planning, before PR).
- **Worktree isolation.** Each worker gets their own worktree. No shared state.
- **Fail fast.** Fix specific issues rather than retrying blindly.

## See Also

- `/swarm` — Launch and run an agent team
- `/worktree` — Branch isolation for parallel work
- `/review` — Code review checklist
