---
description: Launch an agent team for parallel task execution using Claude Code agent teams
---
# /swarm — Launch Agent Team

Step-by-step workflow for launching and running a multi-agent team.

## Invocation

```
/swarm [task description]
```

## Prerequisites

- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` must be set to `"1"` in `.claude/settings.json`
- All agent definitions must exist in `.claude/agents/`
- Git worktrees available for isolation

## 8-Step Workflow

### Step 1: Plan

```
1. Gather requirements, spawn researcher for context
2. Create decomposition plan with acceptance criteria
3. Get human approval before proceeding
```

### Step 2: Set Up Worktrees

Create isolated worktrees for each task.

```bash
# For each task in the plan:
git worktree add ../project-task-{id}-{desc} -b task-{id}/{desc}
```

### Step 3: Create Team

Initialize the agent team infrastructure.

```
TeamCreate → creates team + shared task list
TaskCreate → one task per work unit, with:
  - Clear subject and description
  - Acceptance criteria
  - Assigned worktree path
```

### Step 4: Spawn Agents

```
For each task: spawn worker (+ researcher if needed)
Assign tasks via TaskUpdate(owner=...)
```

### Step 5: Monitor

```
- Watch task list for status updates
- Respond to blockers and questions
- Use peer messaging to connect agents when useful
```

### Step 6: Validate + Review

```
1. Spawn validator: merge branches, run tests, check criteria
2. Spawn reviewer: review changes, categorize by severity
3. If issues: dispatch workers to fix, re-validate until clean
```

### Step 7: Consolidate

```
1. Spawn documenter if docs need updating
2. Create PR (summary, research, validation, review)
3. Present to human for final approval
```

### Step 8: Clean Up

Shut down the team and clean up resources.

```
1. Send shutdown_request to all teammates
2. TeamDelete to remove team infrastructure
3. Remove worktrees:
   git worktree remove ../project-task-{id}-{desc}
   git worktree prune
4. Spawn @"scout (agent)" for PDS meta-improvement suggestions
```

## Quick Reference

| Phase | Agents Used | Output |
|-------|-------------|--------|
| Plan | orchestrator + researcher | Approved plan with acceptance criteria |
| Set up | orchestrator | Worktrees created |
| Create team | orchestrator | Team + task list |
| Spawn | workers (+ researchers) | Implementation in progress |
| Monitor | orchestrator | Blockers resolved |
| Validate | validator + reviewer | Validation + review reports |
| Consolidate | documenter + orchestrator | PR created |
| Clean up | scout + orchestrator | Resources removed, improvements noted |

## See Also

- `/team` — Agent roster, roles, and capabilities
- `/worktree` — Branch isolation for parallel work
- `/commit` — Commit conventions
- `/review` — Code review checklist
