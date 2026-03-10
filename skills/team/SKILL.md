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

Agents coordinate via TaskCreate/TaskUpdate for status and SendMessage for communication. TeamCreate establishes the team and shared task list.

## Team Coordination Tools

Agents use Claude Code's team primitives for structured coordination instead of ad-hoc communication.

### Orchestrator tools (team lead)

| Tool | Purpose |
|------|---------|
| `TeamCreate` | Establish team with shared task list |
| `TeamDelete` | Clean up team after swarm completion |
| `TaskCreate` | Define work units with acceptance criteria |
| `TaskUpdate` | Assign tasks, update status, set dependencies |
| `TaskList` | Monitor all task progress |
| `TaskGet` | Check individual task details |
| `TaskStop` | Stop stuck agents |
| `SendMessage` | Direct communication with any agent |

### Agent tools (all non-orchestrator agents)

| Tool | Agents | Purpose |
|------|--------|---------|
| `TaskGet` | all | Read assigned task details and acceptance criteria |
| `TaskList` | worker, validator | Find available/unblocked tasks, discover branches |
| `TaskCreate` | worker | Create new tasks when discovering additional work |
| `TaskUpdate` | worker, validator | Mark tasks `in_progress` / `completed`, claim tasks |
| `SendMessage` | all | Report results to orchestrator, cross-agent coordination |

### Coordination patterns

- **Task assignment**: Orchestrator creates initial tasks (`TaskCreate`), assigns first tasks via `TaskUpdate(owner=)`. Workers self-claim subsequent unblocked tasks via `TaskList` + `TaskUpdate`.
- **Progress tracking**: Agents update status (`TaskUpdate(status=)`), orchestrator monitors (`TaskList`)
- **Results delivery**: Agents send reports via `SendMessage`, orchestrator writes to swarm artifacts
- **Blocker escalation**: Agents commit progress, update task status, `SendMessage` to orchestrator with details
- **Task discovery**: Workers create new tasks with `TaskCreate` when they discover additional work during implementation

## New Agent Capabilities (Claude Code 2.1.50+)

| Feature | Description |
|---------|-------------|
| `isolation: worktree` | Declared in worker frontmatter — Claude Code provisions the worktree automatically. No manual `git worktree add` needed. |
| `Task(agent_type)` | Typed spawn syntax (e.g., `Task(worker)`, `Task(validator)`) — restricts which agent definitions can fulfill the spawn. Use this instead of `subagent_type=`. |
| `agent_id` / `agent_type` in hooks | Hook events expose these fields, enabling agent-aware routing in the PermissionRequest hook. |

## Coordination Protocols

### Shutdown

TeamDelete **fails if agents are still active**. Before calling TeamDelete, the orchestrator must:

1. `SendMessage(type="shutdown_request", recipient="agent-name")` to each active agent
2. Wait for each agent's `shutdown_response` (approve or reject)
3. Only then call `TeamDelete`

### Plan Approval

Agents in `plan` mode (researcher, reviewer, auditor) send a `plan_approval_request` when they call `ExitPlanMode`. The orchestrator responds with:
```
SendMessage(type="plan_approval_response", request_id="...", recipient="agent-name", approve=true)
```
Reject with `approve=false` and `content="feedback"` to request revisions.

### Team Discovery

Agents discover teammates by reading `~/.claude/teams/{team-name}/config.json`. The `members` array has each agent's `name`, `agentId`, and `agentType`. **Always use `name` for messaging and task ownership** (not agentId).

### Idle State

Agents go idle after every turn — **this is normal**. Idle means waiting for input, not done or broken.

- Sending a message to an idle agent wakes it up
- Idle notifications are automatic — no need to react unless assigning new work
- Peer DM summaries appear in idle notifications for visibility

### Messaging

- **DM** (`type="message"`): Default for all communication. Targeted, efficient.
- **Broadcast** (`type="broadcast"`): Sends to ALL agents. Use only for critical team-wide issues (e.g., "stop all work, blocking bug found"). Costs scale linearly with team size.
- **Plain text output is NOT visible to teammates** — always use `SendMessage` to communicate.

## Core Principles

- **Progress in commits and task updates.** Commits and TaskUpdate are durable. Context is ephemeral.
- **Human gate.** Get approval at phase boundaries (planning, before PR).
- **Worktree isolation.** Each worker gets their own worktree. No shared state.
- **Fail fast.** Fix specific issues rather than retrying blindly.
