# ADR 0003: PDS Improvement Plan from Metrics

## Status
Proposed

## Context

Issue #32 asks how metrics can track PDS efficacy and drive improvements. Currently PDS collects some data (eval results, instinct observations) but lacks a systematic approach to measuring whether PDS actually makes agents more effective.

## Current Data Sources

| Source | Location | What it tracks |
|--------|----------|----------------|
| Eval results | `.claude/eval-results.md` | Skill pass rates with confidence intervals |
| Instincts | `.claude/instincts.md` | Pattern observations, confidence levels |
| Scout reports | `.claude/swarm/scout-report.md` | Per-swarm improvement suggestions |
| Validation reports | `.claude/swarm/validation-report.md` | Test pass/fail, acceptance criteria verdicts |
| Git history | `.git/` | Commit frequency, branch lifecycle |
| Hook logs | `.claude/swarm/*.log` | Worktree events, audit trail |

## Decision

### Proposed Metrics

**Tier 1 — Collect now (low overhead, high signal):**

| Metric | Source | What it measures |
|--------|--------|-----------------|
| Eval pass rate over time | eval-results.md | Are skills getting more effective? |
| Swarm completion rate | Validation reports | What % of swarms complete successfully without human intervention? |
| Fix cycle count | Validation reports | How many validate-fix cycles before passing? (Lower = better decomposition) |
| Task completion time | TaskUpdate timestamps | How long do tasks take? (Trend, not absolute) |

**Tier 2 — Collect when infrastructure exists:**

| Metric | Source | What it measures |
|--------|--------|-----------------|
| Instinct promotion rate | instincts.md history | Are patterns being captured and promoted to skills? |
| Hook rejection rate | Hook logs | How often do gates block actions? (High = agents not following protocols) |
| PR review finding density | Review reports | Findings per 100 lines changed (Lower = better worker quality) |
| Cost per task | Token usage | Are we getting more efficient? |

**Tier 3 — Aspirational:**

| Metric | Source | What it measures |
|--------|--------|-----------------|
| Human intervention rate | Session transcripts | How often does the human need to correct agent behavior? |
| Skill usage frequency | Agent traces | Which skills are actually used vs ignored? |
| First-pass acceptance rate | PR merge without revision | Quality of initial implementation |

### Collection Mechanism

**Recommended approach: append-only log file**

Create `.claude/metrics.jsonl` — one JSON line per event:

```jsonl
{"ts":"2026-03-27T10:00:00Z","type":"eval","skill":"grill","scenario":"vague-req","result":"pass","model":"sonnet"}
{"ts":"2026-03-27T10:05:00Z","type":"swarm_complete","team":"pds-issues","tasks":16,"completed":16,"fix_cycles":1}
{"ts":"2026-03-27T10:10:00Z","type":"task_complete","task_id":"1","duration_min":12,"agent":"worker-1"}
```

Why JSONL:
- Append-only (no read-modify-write races between agents)
- Easy to parse (`jq`, Python, etc.)
- Git-trackable (each line is independent)
- No schema migration needed — new event types can be added freely

### Collection Points

| Event | Where to collect | How |
|-------|-----------------|-----|
| Eval completion | `scripts/run-eval.sh` | Append result after each scenario |
| Swarm completion | Orchestrator Phase 5 | Append summary before PR creation |
| Task completion | TaskCompleted hook | Append task metadata |
| Validation cycle | Validator report | Append cycle count and results |

### Reporting

The scout agent (Phase 6) reads `.claude/metrics.jsonl` and produces trend analysis in the scout report:
- Eval pass rates: improving, stable, or regressing?
- Swarm efficiency: fewer fix cycles over time?
- Agent compliance: fewer hook rejections?

### What NOT to Track

- **Vanity metrics:** Lines of code, commit count, number of files changed.
- **Subjective quality:** "Code quality score" — not mechanically verifiable.
- **Token cost without context:** Raw cost is meaningless without task complexity normalization.
- **Individual agent performance:** Agents are non-deterministic; tracking "worker-1 vs worker-2" creates noise.

## Consequences

### Positive
- Data-driven PDS improvement instead of anecdotal observations
- Historical trends enable regression detection
- Low-overhead collection (JSONL append is cheap)
- Scout can identify patterns humans miss

### Negative
- Metrics file grows over time (needs periodic archival)
- Risk of optimizing for metrics rather than outcomes
- Collection points add small overhead to each event
- JSONL requires tooling to analyze (no built-in dashboard)

### Implementation Plan

1. **Phase 1:** Add `.claude/metrics.jsonl` to `.gitignore` (project-specific, not committed)
2. **Phase 2:** Add append calls to `scripts/run-eval.sh` and `task-completed-gate.sh`
3. **Phase 3:** Extend scout to read metrics and produce trend analysis
4. **Phase 4:** Build simple reporting script (`scripts/metrics-report.sh`)

### Open Questions
- Should metrics be committed to git or kept local? (Committed = shared team knowledge, local = no noise in PRs)
- Should the orchestrator produce a metrics summary in the PR body?
- What is the retention policy? (Keep last 90 days? Last 50 swarms?)
