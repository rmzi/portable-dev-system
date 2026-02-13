---
description: Multi-agent team workflow with file-based coordination across worktrees
disable-model-invocation: true
---
# /swarm — Multi-Agent Team Workflow

Each agent runs in its own worktree with file-based coordination. See `/team` for agent roster and file protocol.

## Invocation

```
/swarm [task description]
```

## 6-Phase Workflow

### Phase 1: Plan
Run `/grill` to validate requirements before decomposition. Spawn researcher for context. Create decomposition plan and get human approval.

### Phase 2: Decompose
Create worktrees and write task files:

```bash
git worktree add .worktrees/task-1-auth -b task-1/auth
mkdir -p .worktrees/task-1-auth/.agent
cat > .worktrees/task-1-auth/.agent/task.md << 'EOF'
## Task: Implement auth module
### Acceptance Criteria
- [ ] JWT-based login endpoint
- [ ] Token validation middleware
EOF
```

Write decomposition plan to `.swarm/plan.md`.

### Phase 3: Dispatch
Spawn agents in their worktrees. Each reads `.agent/task.md` and works autonomously.

### Phase 4: Validate
Spawn validator to merge and test. If issues: dispatch workers to fix, re-validate until clean.

### Phase 5: Consolidate
Create PR with context from all phases. Spawn documenter if needed. Get human approval.

### Phase 6: Knowledge
Spawn scout for PDS meta-improvements. Capture lessons learned.

## Monitoring

```bash
for dir in .worktrees/*/.agent; do
  echo "=== $(dirname $dir) ==="; cat "$dir/status.md" 2>/dev/null || echo "no status"
done
```

## See Also

- `/grill` — Requirement interrogation before decomposition
- `/team` — Agent roster, file protocol, coordination model
- `/worktree` — Branch isolation for parallel work
