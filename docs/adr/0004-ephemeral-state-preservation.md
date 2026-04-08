# ADR 0004: Ephemeral State Preservation

## Status
Proposed

## Context

PDS creates ephemeral state during swarms — reports, plans, context files, agent conversations — that lives in `.claude/swarm/` within worktrees. When worktrees are cleaned up (via `/pds:finish`, `/pds:worktree gc`, or manual `git worktree remove`), this knowledge is destroyed. Git captures code outcomes but not the reasoning behind decisions, rejected alternatives, or surprising findings.

### Existing Persistence Layers

Three layers already exist, each with different characteristics:

| Layer | Location | Scope | Mechanism | Limit |
|-------|----------|-------|-----------|-------|
| **Auto-memory** | `~/.claude/projects/*/memory/` | Cross-session, human-curated | Write tool → MEMORY.md index | ~200 lines in MEMORY.md |
| **claude-mem** | `~/.claude-mem/` | Cross-session, auto-captured | SQLite + ChromaDB, semantic search | Storage-bound |
| **Git** | `docs/swarm-reports/` | Versioned, reviewable | `git add` + commit | Repo size |

### The Gap

No extraction step runs before worktree cleanup. The path from ephemeral state to persistence is:

```
.claude/swarm/*.md  →  (nothing)  →  destroyed on worktree removal
```

Knowledge dies silently through normal PDS workflows. A developer running `/pds:finish` or cleaning up stale worktrees loses:
- **Decisions and rationale** — why option A was chosen over B
- **Rejected alternatives** — what was tried and abandoned
- **Surprising findings** — codebase quirks discovered during implementation
- **Structured artifacts** — validation reports, review reports, scout reports

## Decision

Add an extraction step to PDS workflows that route ephemeral state to the appropriate persistence layer before destruction. The routing follows the principle: **each artifact goes to the sink that matches its lifecycle and audience.**

### Routing Table

| Source | Sink | Rationale |
|--------|------|-----------|
| `.claude/swarm/*.md` (reports, plans) | `docs/swarm-reports/<YYYY-MM-DD-HHmm>/` (git) | Structured artifacts are reviewable and version-worthy |
| Decisions, reasoning, rejected approaches | Auto-memory (project/feedback entries) | Cross-session knowledge that informs future work |
| Session observations | claude-mem (automatic) | Already captured — no action needed |
| Uncommitted diffs | `/pds:finish` (commit, push, PR) | Code belongs in git |

### Integration Points

Three PDS skills gain extraction responsibilities:

1. **`/pds:finish`** — Add Step 0 (Extract Knowledge) before verify. Archive swarm artifacts to git, distill 1-2 memory entries per swarm.

2. **`/pds:worktree gc`** — Add pre-removal triage. Dirty worktrees get offered `/pds:finish`. Stale worktrees with `.claude/swarm/` artifacts get offered extraction. Clean stale worktrees are removed directly.

3. **`/pds:swarm` Phase 6** — Scout distills key learnings into auto-memory entries before writing scout-report.md. Focuses on patterns, decisions, and constraints that future sessions need.

### Selectivity Principle

Auto-memory has a ~200-line index cap. Extraction must be selective:
- **1-2 entries per swarm**, not one per report
- Focus on *why* decisions were made, not *what* was built (git has the what)
- Skip anything derivable from code, git history, or existing docs
- Use project type for decisions/constraints, feedback type for workflow learnings

## Consequences

### Positive
- No knowledge silently destroyed through standard PDS workflows
- Swarm artifacts become reviewable in PRs via `docs/swarm-reports/`
- Future sessions inherit decision context without re-discovery
- "Leave cleaner than you came" — extraction is the cost of cleanup

### Negative
- Extraction adds ~30s to `/pds:finish` (archive + memory distillation)
- Auto-memory bloat risk if selectivity discipline isn't maintained
- `docs/swarm-reports/` grows over time — periodic pruning may be needed
- Worktree gc becomes interactive for dirty/artifact-bearing worktrees (was previously direct removal)

### Mitigations
- Selectivity is enforced by skill language ("1-2 entries per swarm")
- Swarm reports can be pruned with standard git tooling (`git rm` old reports)
- Gc remains direct for clean stale worktrees (the common case)
