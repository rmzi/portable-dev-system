---
description: Agent team roster showing roles, capabilities, and constraints
---
# /team — Agent Team Reference

Agent roster, permissions, and coordination model for PDS multi-agent orchestration.

## Agent Roster

| Agent | Role | Model | Tools | Skills |
|-------|------|-------|-------|--------|
| **orchestrator** | Team lead — plans, decomposes, dispatches | opus | Read, Glob, Grep, Bash, Write, Edit, Task | team, worktree, commit, review |
| **researcher** | Deep codebase exploration | sonnet | Read, Glob, Grep, Bash | debug, quickref |
| **worker** | Implementation in isolated worktrees | sonnet | Read, Glob, Grep, Bash, Write, Edit | commit, test, debug |
| **validator** | Merge branches, run tests, report | sonnet | Read, Glob, Grep, Bash, Write, Edit | test, review |
| **reviewer** | Code review — quality, security | sonnet | Read, Glob, Grep, Bash | review, test |
| **documenter** | Documentation updates | sonnet | Read, Glob, Grep, Bash, Write, Edit | commit |
| **scout** | PDS meta-improvements | haiku | Read, Glob, Grep | ethos, design |
| **auditor** | Codebase analysis → GitHub issues | sonnet | Read, Glob, Grep, Bash | review, test |

## Permission Tiers

| Tier | Agents | Can Do | Cannot Do |
|------|--------|--------|-----------|
| **Full** | orchestrator | Read, write, edit, spawn agents | — |
| **Write** | worker, validator, documenter | Read, write, edit files | Spawn agents |
| **Read + Bash** | researcher, reviewer, auditor | Read files, run commands | Write or edit files |
| **Read-only** | scout | Read and search files | Bash, write, edit |

## Communication Model

```
                    ┌─────────────┐
                    │ orchestrator │
                    └──────┬──────┘
           ┌───────┬───────┼───────┬───────┬───────┐
           │       │       │       │       │       │
      researcher worker validator reviewer documenter scout/auditor
```

**Hub-by-default with peer messaging available:**

- Orchestrator is the coordination point — gets all status updates
- Agents primarily report to the orchestrator
- Direct agent-to-agent messaging is available when useful
- Shared task list provides visibility to all agents

## 6-Phase Agentic SDLC

```
Plan → Decompose → Dispatch → Validate → Consolidate → Knowledge
 │         │          │           │            │            │
 │    researcher   workers    validator      docs        scout
 │    + human      + tasks    + reviewer    + PR
 human gate                                human gate
```

1. **Plan** — Refine requirements into acceptance criteria (human gate)
2. **Decompose** — Split into tasks, create worktrees
3. **Dispatch** — Spawn researchers + workers
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
