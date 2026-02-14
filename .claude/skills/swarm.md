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
Run `/grill` to validate requirements before decomposition. Spawn researcher for context — researcher queries `.claude/instincts.md` for relevant prior patterns. Create decomposition plan and get human approval.

### Phase 2: Decompose
Create worktrees and write task files:

```bash
REPO_ROOT="$(git rev-parse --path-format=absolute --git-common-dir | sed 's|/.git$||')"
git worktree add "$REPO_ROOT/.worktrees/task-1-auth" -b task-1/auth
mkdir -p "$REPO_ROOT/.worktrees/task-1-auth/.agent"
cat > "$REPO_ROOT/.worktrees/task-1-auth/.agent/task.md" << 'EOF'
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
Spawn scout for PDS meta-improvements. Scout reads `.claude/instincts.md`, updates counts for re-observed patterns, proposes new instincts, and flags high-confidence instincts for skill promotion. See `/instinct`.

## Monitoring

```bash
REPO_ROOT="$(git rev-parse --path-format=absolute --git-common-dir | sed 's|/.git$||')"
for dir in "$REPO_ROOT"/.worktrees/*/.agent; do
  echo "=== $(dirname $dir) ==="; cat "$dir/status.md" 2>/dev/null || echo "no status"
done
```

## See Also

- `/grill` — Requirement interrogation before decomposition
- `/instinct` — Pattern capture and lifecycle
- `/team` — Agent roster, file protocol, coordination model
- `/worktree` — Branch isolation for parallel work
