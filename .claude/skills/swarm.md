---
description: Multi-agent team workflow with file-based coordination across worktrees
---
# /swarm — Multi-Agent Team Workflow

Each agent runs in its own worktree with file-based coordination. See `/team` for agent roster and file protocol.

## Invocation

```
/swarm [task description]
```

## 6-Phase Workflow

### Phase 1: Plan
Gather requirements, spawn researcher for context, create decomposition plan, get human approval.

### Phase 2: Decompose
Create worktrees and write task files:

```bash
git worktree add ../project-task-1-auth -b task-1/auth
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
claude -p "$(cat .claude/agents/worker.md) Read .agent/task.md and complete the task." \
  --directory ../project-task-1-auth
```

### Phase 4: Validate
Spawn validator to merge and test. If issues: dispatch workers to fix, re-validate until clean.

### Phase 5: Consolidate
Create PR with context from all phases. Spawn documenter if docs need updating. Get human approval.

### Phase 6: Knowledge
Spawn scout for PDS meta-improvements. Capture lessons learned.

## Monitoring

```bash
# Check all agents at once
for dir in ../*/.agent; do
  echo "=== $(dirname $dir) ==="
  cat "$dir/status.md" 2>/dev/null || echo "no status"
done
```

## See Also

- `/team` — Agent roster, file protocol, coordination model
- `/worktree` — Branch isolation for parallel work
