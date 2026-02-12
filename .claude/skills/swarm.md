---
description: Multi-agent team workflow with file-based coordination across worktrees
---
# /swarm — Multi-Agent Team Workflow

Workflow for launching and coordinating a multi-agent team. Each agent runs in its own worktree with file-based coordination.

## Invocation

```
/swarm [task description]
```

## Prerequisites

- Agent definitions in `.claude/agents/`
- Git worktrees for isolation (`git worktree add`)

## 6-Phase Workflow

### Phase 1: Plan

Gather requirements, spawn researcher for context, create decomposition plan, get human approval.

### Phase 2: Decompose

Create worktrees and write task files:

```bash
# Create worktrees
git worktree add ../project-task-1-auth -b task-1/auth
git worktree add ../project-task-2-api -b task-2/api

# Write task files
mkdir -p ../project-task-1-auth/.agent
cat > ../project-task-1-auth/.agent/task.md << 'EOF'
## Task: Implement auth module
### Acceptance Criteria
- [ ] JWT-based login endpoint
- [ ] Token validation middleware
### Context
See src/auth/ for existing patterns.
EOF
```

Write the decomposition plan to `.swarm/plan.md`.

### Phase 3: Dispatch

Spawn agents in their worktrees. Each agent reads `.agent/task.md` and works autonomously.

```bash
# Each agent runs as a non-interactive claude session
claude -p "$(cat .claude/agents/worker.md) Read .agent/task.md and complete the task." \
  --directory ../project-task-1-auth
```

### Phase 4: Validate

Spawn validator to merge branches, run tests, and report:

```bash
# Validator merges worker branches and runs test suite
claude -p "$(cat .claude/agents/validator.md) Read .agent/task.md and validate." \
  --directory ../project-validate-worktree
```

If issues: dispatch workers to fix, re-validate until clean.

### Phase 5: Consolidate

Create PR with context from all phases. Spawn documenter if docs need updating. Get human approval.

### Phase 6: Knowledge

Spawn scout for PDS meta-improvements. Capture lessons learned.

## File Coordination

```
main-worktree/.swarm/
  plan.md                 # Decomposition plan
  orchestrator.log        # Activity log
  tasks/
    task-1.md             # Task definitions

agent-worktree/.agent/
  task.md                 # Assigned task (orchestrator writes before spawning)
  status.md               # Agent writes: pending | in_progress | done | blocked
  output.md               # Agent writes: results/report
```

## Monitoring

```bash
# Check specific agent status
cat ../worktree/.agent/status.md

# Read agent results
cat ../worktree/.agent/output.md

# Check all agents at once
for dir in ../*/.agent; do
  echo "=== $(dirname $dir) ==="
  cat "$dir/status.md" 2>/dev/null || echo "no status"
done
```

## Core Principles

- **Progress in files, not context.** Commits and task updates are durable. Context windows are not.
- **Human gate.** Get human approval at phase boundaries (planning, before PR).
- **Worktree isolation.** Each worker gets their own worktree. No shared state.
- **No inter-agent communication.** If workers need to talk, decompose differently.
- **Fail fast.** Fix specific issues rather than retrying blindly.

## See Also

- `/team` — Agent roster, roles, and capabilities
- `/worktree` — Branch isolation for parallel work
- `/commit` — Commit conventions
- `/review` — Code review checklist
