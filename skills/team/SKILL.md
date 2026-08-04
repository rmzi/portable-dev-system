---
description: Referencing the agent roster, roles, coordination model, and dispatch modes. Use when spawning agents or checking permissions.
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
| **auditor** | Codebase analysis -> GitHub issues | sonnet | plan | 30 | project | Periodic tech debt scans |
| **shepherd** | Substantive advisor — whitepaper/philosophy enforcement by citation, advisory only | opus | acceptEdits (scoped) | 80 | project | Med + heavy tiers only, spawned after Phase 1 grill |

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
| shepherd | _(skip)_ | opus | opus |

- **Lite**: 2 modules, existing patterns. 1-2 workers, no reviewer/documenter/auditor/shepherd. Orchestrator self-researches and self-reviews. Workers self-consult by reading the whitepaper/philosophy/ethos docs directly if a substantive consult is needed.
- **Med**: 2-3 boundaries, some design decisions. 2-3 workers, full specialist roster as needed, **shepherd spawned** after Phase 1 grill. Current defaults.
- **Heavy**: 3+ boundaries, new interfaces, or core refactors. 3-4 workers, all specialists including auditor, **shepherd spawned** after Phase 1 grill. Opus for reasoning.

User override: `/pds:swarm lite|med|heavy`. Without argument, auto-selected via `/pds:grill` step 10.

## Graph-vs-Substance Routing

Two kinds of questions arise during swarm execution. Route by kind:

| Kind | Examples | Route to |
|------|----------|----------|
| **Graph** | "Which task comes next?" "Who is blocked on what?" "Has Phase 4 started?" "Who owns task #7?" "When do I run `/pds:verify`?" | **orchestrator** (via SendMessage) |
| **Substance** | "Should this module own retry logic?" "Is squashing these commits before PR the right call?" "Which layering convention applies here?" "Does the whitepaper mandate X?" "What trade-off does choosing Y over Z make?" | **shepherd** (via SendMessage) |

The orchestrator handles coordination. The shepherd handles principles. When a teammate receives a question off-lane, reply with a one-line redirect ("Graph question — ask the orchestrator" / "Substance question — ask the shepherd") rather than answering out of scope. If no shepherd is active (lite tier), substance questions route to the orchestrator which either answers itself or self-consults by reading the whitepaper/philosophy/ethos docs directly.

## Permission Modes

| Mode | Agents | Behavior |
|------|--------|----------|
| **default** | orchestrator | Standard permission flow — coordinates and delegates to agents |
| **acceptEdits** | worker, validator, documenter | Auto-accept file edits, full implementation access |
| **plan** | researcher, reviewer, auditor | Read-only exploration, no file modifications |
| **acceptEdits** (scoped) | scout | Write limited to `.claude/swarm/scout-report.md`, `.claude/instincts.md`, `.claude/eval-results.md`, and `.claude/shepherd-journal.md` |
| **acceptEdits** (scoped) | shepherd | Write limited to `.claude/shepherd-journal.md` |
| **auto** | all (when user enables) | Sonnet classifier evaluates each tool call — overrides agent-declared modes |

**Note**: In auto mode, agent-declared `permissionMode` values (`plan`, `acceptEdits`, `default`) are overridden by the classifier. Behavioral constraints in agent `.md` files and the classifier's context awareness provide enforcement. Static deny rules and the sandbox are unaffected.

## Dispatch Modes

Three dispatch modes for spawning agents. Choose based on task characteristics.

### Mode Selection

| Question | Team Teammate | Fork Subagent | Headless |
|----------|--------------|---------------|----------|
| Needs its own worktree? | Yes | No | No |
| Needs task tracking? | Yes | No | No |
| Needs role specialization? | Yes | No | Optional |
| Needs parent's full context? | No (reads context.md) | Yes | No |
| Long-running (>3 turns)? | Yes | No | Varies |
| Interactive session required? | Yes | Yes | No |
| Visible in team? | Yes | No | No |

### Team Teammate

Default for all swarm work units. Long-running, tracked, role-specialized.

```
worker = Task(pds:worker, team_name="project",
     prompt="Implement auth module per task description.")
```

Note the `pds:` prefix — PDS agents ship in a plugin and register as `pds:<name>`; a bare `Task(worker)` matches nothing and empties the whole roster (#181). No `name=` — the orchestrator spawning this is itself a named teammate and cannot spawn further named teammates ("the team roster is flat," confirmed via #171). Capture `worker.agent_id` for direct addressing; prefer task-mediated coordination (contract in the task description, self-claim via `TaskList`) for routine coordination.

**When to use:** Implementation tasks, validation, review, documentation — anything that produces artifacts, needs a worktree, or should appear in TaskList.

**Context bridging:** Workers start fresh. Write `.claude/swarm/context.md` before dispatch so workers can read the orchestrator's plan, research, and decisions on init.

### Fork Subagent

Quick, invisible, context-inheriting. The child gets the parent's full conversation history.

**When to use:** Inline research ("does this function exist?"), quick analysis ("summarize this file"), one-off queries that need the parent's accumulated context. Under 2-3 turns. No worktree needed. No task tracking needed.

**Limitation:** No role specialization. The fork inherits the parent's system prompt, not a specialized agent definition. Cannot be combined with `Task(agent_type)`.

### Headless

Background or scheduled execution without an interactive session.

- **CronCreate** — Schedule recurring agent execution (weekly audits, daily checks)
- **run_in_background** — Launch long-running commands that continue after the parent returns
- **SessionStart/Stop Hooks** — Automatic execution at session boundaries

### Decision Flowchart

```
Is the task >3 turns with artifact output?
  YES -> Team teammate (Task(pds:worker))
  NO -> Does the task need the parent's full context?
    YES -> Fork subagent
    NO -> Does the task need an interactive session?
      YES -> Fork subagent (lightweight) or teammate (tracked)
      NO -> Headless (CronCreate, run_in_background, or hook)
```

## Coordination Model

```
                    +---------------+
                    | orchestrator  |  (your Claude session)
                    +-------+-------+
           +-------+-------+-------+-------+-------+-------+
           |       |       |       |       |       |       |
      researcher worker validator reviewer documenter scout/auditor shepherd
      (each spawned via Task tool with worktree isolation)
```

Agents coordinate via Claude Code's native team tools — TaskCreate/TaskUpdate/TaskList/TaskGet, SendMessage, TaskStop. Teams are implicit per-session: a team forms on the first teammate spawn and tears down automatically when the session ends — there is no `TeamCreate`/`TeamDelete` call (both were removed at CC v2.1.178). See each agent's frontmatter `tools:` field for which tools it has access to. Claude Code's built-in tool documentation covers usage, protocols (shutdown, plan approval, idle state, messaging).

## PDS Coordination Patterns

These patterns are PDS-specific — they layer on top of native Claude Code team behavior:

- **Pull model**: Orchestrator assigns initial tasks. Workers self-claim subsequent unblocked tasks via `TaskList` + `TaskUpdate` (prefer lowest ID).
- **Results delivery**: Agents send reports via `SendMessage`. Orchestrator writes to `.claude/swarm/` artifacts (required by phase gates).
- **Task discovery**: Workers create new tasks via `TaskCreate` when they discover additional work during implementation.
- **Blocker escalation**: Agents commit progress, update task status, `SendMessage` to orchestrator with details.
- **Substantive consultation**: For design, trade-offs, or principle-checks, agents consult the shepherd via `SendMessage` (med/heavy) or self-consult by reading the whitepaper/philosophy/ethos docs directly (lite or degraded). See `agents/shared-rules.md` for the protocol.

## Native Behaviors Worth Knowing

These are Claude Code native behaviors, but agents that haven't seen them before will get stuck:

- **Shutdown before ending the swarm**: `SendMessage(type="shutdown_request")` to each active agent -> wait for `shutdown_response` -> then let the orchestrator's turn end. There is no `TeamDelete` call anymore (removed in Claude Code v2.1.178, team cleanup is automatic on session end) — which means there's also no tool call left to **mechanically fail** if a shutdown was skipped. The shutdown protocol above is now the only safeguard; treat it as enforcement, not courtesy. Leaving an agent running keeps the implicit team alive, so always drain shutdowns before letting the turn end. The failure mode changed shape rather than disappearing: instead of a `TeamDelete` call erroring on active agents, the orchestrator's `Stop` hook (`orchestrator-teardown-gate.sh`) blocks the stop itself while phase = `knowledge` and required artifacts are missing. This isn't a hang — a blocking `Stop` hook (exit code 2) continues the orchestrator's own turn with the block reason as feedback, so it can act on the reason (write the missing report, remove a leftover worktree) and try to stop again. A swarm that can never satisfy the gate's conditions will loop on stop attempts the same way a `TeamDelete` call used to keep failing — recoverable by fixing the underlying gap, not a platform bug.
- **Plan approval**: Agents in `plan` mode send `plan_approval_request` when they call `ExitPlanMode`. Orchestrator must respond with `SendMessage(type="plan_approval_response", approve=true)` — or `approve=false` with feedback. Without this response, the agent hangs.
- **Plain text is invisible to teammates** — always use `SendMessage`. DM (`type="message"`) for targeted communication; broadcast (`type="broadcast"`) only for critical team-wide issues.

## Core Principles

- **Progress in commits and task updates.** Commits and TaskUpdate are durable. Context is ephemeral.
- **Human gate.** Get approval at phase boundaries (planning, before PR).
- **Worktree isolation.** Each worker gets their own worktree. No shared state.
- **Fail fast.** Fix specific issues rather than retrying blindly.
- **Route by kind.** Graph questions go to the orchestrator; substance questions go to the shepherd.
