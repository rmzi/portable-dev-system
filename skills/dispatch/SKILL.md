---
description: Agent dispatch mode selection — team teammate vs fork subagent vs headless. Use when deciding how to spawn an agent for a task.
---
# /dispatch — Agent Dispatch Modes

Three dispatch modes for spawning agents. Choose based on task characteristics.

## Mode Selection

| Question | Team Teammate | Fork Subagent | Headless |
|----------|--------------|---------------|----------|
| Needs its own worktree? | Yes | No | No |
| Needs task tracking? | Yes | No | No |
| Needs role specialization? | Yes | No | Optional |
| Needs parent's full context? | No (reads context.md) | Yes | No |
| Long-running (>3 turns)? | Yes | No | Varies |
| Interactive session required? | Yes | Yes | No |
| Visible in team? | Yes | No | No |

## Team Teammate

Default for all swarm work units. Long-running, tracked, role-specialized.

```
Task(worker, team_name="project", name="worker-auth",
     prompt="Implement auth module per task description.")
```

**When to use:** Implementation tasks, validation, review, documentation — anything that produces artifacts, needs a worktree, or should appear in TaskList.

**Context bridging:** Workers start fresh. Write `.claude/swarm/context.md` before dispatch so workers can read the orchestrator's plan, research, and decisions on init.

## Fork Subagent

Quick, invisible, context-inheriting. The child gets the parent's full conversation history.

**When to use:** Inline research ("does this function exist?"), quick analysis ("summarize this file"), one-off queries that need the parent's accumulated context. Under 2-3 turns. No worktree needed. No task tracking needed.

**Limitation:** No role specialization. The fork inherits the parent's system prompt, not a specialized agent definition. Cannot be combined with `Task(agent_type)`.

## Headless

Background or scheduled execution without an interactive session.

### CronCreate

Schedule recurring agent execution:
```
CronCreate(schedule="0 9 * * 1", prompt="Run /pds:preflight and report results.")
```

**Use cases:**
- Weekly codebase audits
- Daily dependency update checks
- Scheduled telemetry analysis

### run_in_background

Launch a long-running command that continues after the parent returns:
```bash
# Background: efficiency analysis after swarm
run_in_background: scripts/efficiency-chart.sh
```

**Use cases:**
- Post-swarm telemetry analysis
- Large test suite runs
- Background compilation

### SessionStart/Stop Hooks

Automatic execution at session boundaries:

```json
{
  "hooks": {
    "SessionStart": [{
      "type": "command",
      "command": "scripts/preflight.sh"
    }]
  }
}
```

**Use cases:**
- Preflight environment validation
- Context injection at session start
- Cleanup and artifact archival at session end
- Instinct capture from completed work

## Decision Flowchart

```
Is the task >3 turns with artifact output?
  YES → Team teammate (Task(worker))
  NO → Does the task need the parent's full context?
    YES → Fork subagent
    NO → Does the task need an interactive session?
      YES → Fork subagent (lightweight) or teammate (tracked)
      NO → Headless (CronCreate, run_in_background, or hook)
```

## See Also

- `/pds:swarm` — Full 6-phase workflow using team teammates
- `/pds:team` — Agent roster and coordination model
