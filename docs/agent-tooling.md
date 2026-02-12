# Agent Tooling: Subtask and Ralph Wiggum

---

## Overview

Two patterns are foundational for agentic development workflows:

- **Subtask** — Parallel execution across git worktrees with context isolation
- **Ralph Wiggum** — Persistent autonomous loops with progress in files, not context

These patterns are complementary. Together they address different aspects of the Agentic SDLC.

---

## The Patterns

### Subtask

[github.com/zippoxer/subtask](https://github.com/zippoxer/subtask)

Spawns subagents in isolated git worktrees. Each agent operates with minimal context — only what it needs for its specific task.

**Key characteristics:**
- Parallel execution across worktrees
- Context minimization through isolation
- Clean handoff via git commits
- Orchestrator synthesizes results

**Maps to:** Phase 3 (Parallel Execution) — multiple workers on decomposed tasks

```
┌─────────────────────────────────────────────────────────┐
│                    Orchestrator                          │
│                         │                                │
│          ┌──────────────┼──────────────┐                │
│          ↓              ↓              ↓                │
│    ┌──────────┐   ┌──────────┐   ┌──────────┐          │
│    │ Worker 1 │   │ Worker 2 │   │ Worker 3 │          │
│    │ worktree │   │ worktree │   │ worktree │          │
│    └──────────┘   └──────────┘   └──────────┘          │
│          │              │              │                │
│          └──────────────┼──────────────┘                │
│                         ↓                                │
│                    Validator                             │
└─────────────────────────────────────────────────────────┘
```

### Ralph Wiggum

[ghuntley.com/ralph](https://ghuntley.com/ralph/)

Named after the lovably persistent Simpsons character. The core insight: progress should live in files and git history, not in the LLM's context window.

**The pattern:**
```bash
while :; do cat PROMPT.md | claude-code ; done
```

When context fills up, the agent resets with fresh context but picks up where it left off — because progress is in the worktree, not the conversation.

**Key characteristics:**
- Infinite loop until task complete
- Progress persists in files, not context
- Fresh context on each iteration
- Hours-long autonomous sessions (14+ reported)

**Maps to:** Long-running tasks within any phase — autonomous iteration without human presence

---

## Why Both?

| Dimension | Subtask | Ralph Wiggum |
|-----------|---------|--------------|
| **Execution model** | Parallel workers | Sequential persistence |
| **Context strategy** | Minimize per agent | Reset and continue |
| **Duration** | Minutes per worker | Hours per loop |
| **Best for** | Decomposed independent tasks | Complex single-focus tasks |
| **Human involvement** | At orchestration boundaries | At loop boundaries |

**They compose naturally:**

```
┌─────────────────────────────────────────────────────────┐
│  Orchestrator dispatches via Subtask                    │
│                                                         │
│    Worker 1          Worker 2          Worker 3        │
│    ┌────────┐        ┌────────┐        ┌────────┐      │
│    │ Ralph  │        │ Ralph  │        │ Ralph  │      │
│    │ Loop   │        │ Loop   │        │ Loop   │      │
│    │   ↻    │        │   ↻    │        │   ↻    │      │
│    └────────┘        └────────┘        └────────┘      │
│                                                         │
│  Each worker runs autonomously until task complete      │
└─────────────────────────────────────────────────────────┘
```

---

## Integration with Agentic SDLC

### Phase 2: Task Decomposition

The orchestrator:
1. Creates worktrees for each decomposed task
2. Writes `.agent/task.md` files with task specifications
3. Dispatches workers to their respective worktrees

### Phase 3: Parallel Execution

Each worker runs autonomously:
```bash
#!/bin/bash
PROMPT_FILE="${1:-PROMPT.md}"
MAX_ITERATIONS="${2:-100}"
iteration=0

while [ $iteration -lt $MAX_ITERATIONS ]; do
    echo "[$(date)] Iteration $iteration starting..."
    claude --print < "$PROMPT_FILE"

    if [ -f ".task-complete" ]; then
        echo "[$(date)] Task marked complete"
        break
    fi

    iteration=$((iteration + 1))
    sleep 2
done
```

### Phase 4: Validation

Validator can also use Ralph for iterative test-fix cycles:
1. Run tests
2. If failures, analyze and suggest fixes
3. Loop until green or max iterations

---

## Observability

Since progress lives in git, tracking is straightforward:

```bash
# Watch commits across all worker worktrees
watch -n 5 'for wt in .worktrees/*/; do
  echo "=== $wt ==="
  git -C "$wt" log --oneline -3
done'
```

Each Ralph iteration can log:
- Iteration number, duration
- Files changed, tests run/passed
- Context tokens used

```bash
# .agent/iteration-log.jsonl (appended each iteration)
{"iteration": 1, "duration_s": 45, "files_changed": 3, "tests_passed": true}
{"iteration": 2, "duration_s": 62, "files_changed": 1, "tests_passed": true}
```

---

## Failure Handling

### Ralph Loop Failures
If an iteration fails (claude crashes, timeout): log the failure, wait briefly (exponential backoff), continue with fresh context. The next iteration sees the same files and can recover.

### Worker Failures
If a worker completely fails: orchestrator detects via health check, worker worktree preserved (progress in files), new worker can resume from last commit.

### Stuck Detection
If no progress after N iterations: log warning, notify orchestrator, human can inspect and intervene.

---

## Adoption Path

| Stage | Tools | Configuration |
|-------|-------|---------------|
| **Manual** | Neither | Human runs agents manually |
| **Subtask only** | Subtask | Parallel workers, human monitors |
| **Ralph only** | Ralph | Single long-running tasks |
| **Combined** | Both | Parallel workers with Ralph loops |
| **Full automation** | Both + orchestrator | Orchestrated overnight execution |

Start with Subtask for parallel decomposition. Add Ralph when workers need multi-hour autonomy.

---

## References

- [Subtask GitHub](https://github.com/zippoxer/subtask)
- [Ralph Wiggum origin](https://ghuntley.com/ralph/)
- [Vercel Ralph Loop Agent](https://github.com/vercel-labs/ralph-loop-agent)
