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
| **orchestrator** | Team lead — plans, decomposes, dispatches | opus | default | 100 | — |
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

## Swarm Tiers

Model overrides applied at spawn time via the `model` parameter. Agent definitions stay unchanged. Tier stored in `.claude/swarm/tier`, set during Phase 1 grill.

| Agent | Lite | Med (default) | Heavy |
|-------|------|---------------|-------|
| orchestrator | sonnet | opus | opus |
| researcher | _(skip)_ | sonnet | opus |
| worker | haiku | sonnet | sonnet |
| validator | haiku | sonnet | sonnet |
| reviewer | _(skip)_ | sonnet | opus |
| documenter | _(skip)_ | sonnet | sonnet |
| scout | haiku | haiku | sonnet |
| auditor | _(skip)_ | _(skip)_ | sonnet |

- **Lite**: 2 modules, existing patterns. 1-2 workers, no reviewer/documenter/auditor. Orchestrator self-researches and self-reviews.
- **Med**: 2-3 boundaries, some design decisions. 2-3 workers, full specialist roster as needed. Current defaults.
- **Heavy**: 3+ boundaries, new interfaces, or core refactors. 3-4 workers, all specialists including auditor. Opus for reasoning.

User override: `/pds:swarm lite|med|heavy`. Without argument, auto-selected via `/pds:grill` step 10.

## Permission Modes

| Mode | Agents | Behavior |
|------|--------|----------|
| **default** | orchestrator | Standard permission flow — coordinates and delegates to agents |
| **acceptEdits** | worker, validator, documenter | Auto-accept file edits, full implementation access |
| **plan** | researcher, reviewer, auditor | Read-only exploration, no file modifications |
| **acceptEdits** (scoped) | scout | Write limited to `.claude/swarm/scout-report.md`, `.claude/instincts.md`, and `.claude/eval-results.md` |

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

Agents coordinate via Claude Code's native team tools — TeamCreate, TaskCreate/TaskUpdate/TaskList/TaskGet, SendMessage, TaskStop. See each agent's frontmatter `tools:` field for which tools it has access to. Claude Code's built-in tool documentation covers usage, protocols (shutdown, plan approval, idle state, messaging).

## PDS Coordination Patterns

These patterns are PDS-specific — they layer on top of native Claude Code team behavior:

- **Pull model**: Orchestrator assigns initial tasks. Workers self-claim subsequent unblocked tasks via `TaskList` + `TaskUpdate` (prefer lowest ID).
- **Results delivery**: Agents send reports via `SendMessage`. Orchestrator writes to `.claude/swarm/` artifacts (required by phase gates).
- **Task discovery**: Workers create new tasks via `TaskCreate` when they discover additional work during implementation.
- **Blocker escalation**: Agents commit progress, update task status, `SendMessage` to orchestrator with details.

## Native Behaviors Worth Knowing

These are Claude Code native behaviors, but agents that haven't seen them before will get stuck:

- **Shutdown before TeamDelete**: `SendMessage(type="shutdown_request")` to each active agent → wait for `shutdown_response` → then `TeamDelete`. TeamDelete **fails if agents are still active**.
- **Plan approval**: Agents in `plan` mode send `plan_approval_request` when they call `ExitPlanMode`. Orchestrator must respond with `SendMessage(type="plan_approval_response", approve=true)` — or `approve=false` with feedback. Without this response, the agent hangs.
- **Plain text is invisible to teammates** — always use `SendMessage`. DM (`type="message"`) for targeted communication; broadcast (`type="broadcast"`) only for critical team-wide issues.

## Core Principles

- **Progress in commits and task updates.** Commits and TaskUpdate are durable. Context is ephemeral.
- **Human gate.** Get approval at phase boundaries (planning, before PR).
- **Worktree isolation.** Each worker gets their own worktree. No shared state.
- **Fail fast.** Fix specific issues rather than retrying blindly.
