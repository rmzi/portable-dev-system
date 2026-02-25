---
description: Launching multi-agent parallel work with native coordination. Use when a task benefits from decomposition into parallel subtasks across worktrees.
disable-model-invocation: true
---
# /swarm — Multi-Agent Team Workflow

Each agent runs in its own worktree with native tool coordination. See `/team` for agent roster.

## Invocation

```
/swarm [task description]
```

## 6-Phase Workflow

### Phase 1: Plan
Run `/grill` to validate requirements before decomposition. Spawn researcher for context — researcher queries `.claude/instincts.md` for relevant prior patterns. Create decomposition plan and get human approval.

### Phase 2: Decompose
Split along architecture boundaries. If CLAUDE.md defines **Agent Zones** (a table mapping zones to paths and merge order), use them to guide decomposition — one task per zone, foundation-first merge order.

When zones cross a boundary (e.g., backend ↔ frontend), write a **contract** to `.swarm/contracts.md` defining the interface (command names, input/output types, error variants) before dispatching agents. Both sides develop against the contract.

Use TaskCreate for each work unit. Put acceptance criteria in the `description` field — this is what workers and the validator check against:

```
TaskCreate(
  subject: "Implement auth module",
  description: "JWT login endpoint at POST /auth/login. Token validation middleware on protected routes. Tests for both.",
  activeForm: "Implementing auth module"
)
```

Use TaskUpdate to set dependencies between tasks (`addBlockedBy`, `addBlocks`). Write decomposition plan to `.swarm/plan.md`.

### Phase 3: Dispatch
Spawn workers via Task tool with `isolation: "worktree"`. Each agent receives its own worktree and branch automatically. The Task tool returns `{worktreeBranch}` — record these branch names for the validator in Phase 4.

### Phase 4: Validate
Monitor progress via TaskList. Spawn validator with the list of worker branch names — the validator merges these branches using `/merge` protocol (rebase-first, one at a time). If issues: dispatch workers to fix, re-validate until clean.

### Phase 5: Consolidate
Create PR with context from all phases. Spawn documenter if needed. Get human approval.

### Phase 6: Knowledge
Spawn scout for PDS meta-improvements. Scout reads `.claude/instincts.md`, updates counts for re-observed patterns, proposes new instincts, and flags high-confidence instincts for skill promotion. See `/instinct`.

## Monitoring

Check task progress via TaskList. For detailed status on individual tasks, use TaskGet.

## See Also

- `/grill` — Requirement interrogation before decomposition
- `/instinct` — Pattern capture and lifecycle
- `/team` — Agent roster, coordination model
