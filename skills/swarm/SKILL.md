---
description: Launching multi-agent parallel work with the Agentic SDLC. Use when a task benefits from decomposition into parallel subtasks.
---
# /swarm — Agentic SDLC

Six-phase workflow for decomposing, dispatching, and validating parallel work across agents. Each phase shows the concrete tool calls needed to execute it.

## Phase 1: Plan

1. Run `/pds:grill` on the requirements to surface gaps and ambiguities
2. Spawn a researcher for codebase context:
   ```
   Task(subagent_type="researcher", prompt="Analyze the codebase for X. Query .claude/instincts.md for relevant prior patterns.")
   ```
3. Synthesize findings into **mechanically verifiable acceptance criteria** — each criterion must be checkable by running a command or reading output (no subjective criteria)
4. Present plan + criteria to the human. **Do not proceed without approval.**

## Phase 2: Decompose

Initialize the swarm artifact directory:
```bash
mkdir -p .claude/swarm
```

Split along architecture boundaries. If CLAUDE.md defines **Agent Zones** (a table mapping zones to paths and merge order), use them to guide decomposition — one task per zone, foundation-first merge order.

Use TaskCreate for each work unit. Put acceptance criteria in the `description` field — this is what workers and the validator check against:

```
TaskCreate(
  subject: "Implement auth module",
  description: "JWT login endpoint at POST /auth/login. Token validation middleware on protected routes. Tests for both.",
  activeForm: "Implementing auth module"
)
```

Use TaskUpdate to set dependencies between tasks (`addBlockedBy`, `addBlocks`). When zones cross a boundary (e.g., backend <-> frontend), write a **contract** to `.claude/swarm/contracts.md` defining the interface before dispatching. Write decomposition plan to `.claude/swarm/plan.md`.

## Phase 3: Dispatch

1. Create the team:
   ```
   TeamCreate(team_name="project-name", description="Working on feature X")
   ```
2. Spawn workers via Task tool — each agent receives its own worktree automatically:
   ```
   Task(subagent_type="worker", team_name="project-name", name="worker-auth",
        prompt="Implement auth module per task description. Run /pds:verify before reporting done.")
   ```
3. Assign tasks to workers:
   ```
   TaskUpdate(taskId="1", owner="worker-auth", status="in_progress")
   ```
4. Workers implement autonomously:
   - Read task description for requirements
   - Use `SendMessage` for cross-agent coordination when needed
   - Run `/pds:verify` before declaring done
   - Mark task completed: `TaskUpdate(taskId="1", status="completed")`
5. Monitor progress via `TaskList`

## Phase 4: Validate

1. Workers run `/pds:verify` (self-check) before reporting task complete
2. Spawn a validator in its own worktree:
   ```
   Task(subagent_type="validator", team_name="project-name", name="validator",
        prompt="Merge all task branches, run full test suite, produce structured pass/fail report. Write report to .claude/swarm/validation-report.md.")
   ```
3. Validator merges branches, runs tests, writes structured report to `.claude/swarm/validation-report.md` **(required — PR gate checks for this file)**
4. If issues found:
   - Update tasks: `TaskUpdate(taskId="1", status="in_progress", description="Fix: ...")`
   - Dispatch targeted workers to fix specific failures
   - Re-validate
5. **Escalate to human after 2 failed validation cycles** — don't loop indefinitely

## Phase 5: Consolidate

1. Run `/pds:finish` on each task branch (rebase, clean history, post-rebase tests)
2. Spawn a reviewer for pre-human code review:
   ```
   Task(subagent_type="reviewer", prompt="Review the diff against acceptance criteria from Phase 1.")
   ```
3. Write reviewer report to `.claude/swarm/review-report.md` after receiving it via SendMessage **(required — PR gate checks for this file)**
4. Spawn a documenter if user-facing docs are affected:
   ```
   Task(subagent_type="documenter", prompt="Update docs for the changes in this PR.")
   ```
5. Create PR with full context:
   ```bash
   gh pr create --title "feat: ..." --body "## Summary\n...\n## Acceptance Criteria\n...\n## Validation\n...\n## Issues\n..."
   ```
   **Note:** The PR gate (`orchestrator-pr-gate.sh`) blocks `gh pr create` unless both `validation-report.md` and `review-report.md` exist in `.claude/swarm/`.
6. **Get human approval before merge.**

## Phase 6: Knowledge

1. Spawn scout for PDS meta-improvements:
   ```
   Task(subagent_type="scout", prompt="Read .claude/instincts.md. Update counts for re-observed patterns. Propose new instincts. Flag high-confidence patterns for skill promotion. Write report to .claude/swarm/scout-report.md.")
   ```
2. Scout writes report to `.claude/swarm/scout-report.md` **(required — TeamDelete gate checks for this file)**
3. Scout updates observation counts, proposes new patterns, flags promotions (human-gated — new skill = new file = PR review)
4. Clean up: `TeamDelete`
   **Note:** The teardown gate (`orchestrator-teardown-gate.sh`) blocks `TeamDelete` unless all 3 phase reports exist in `.claude/swarm/` (validation, review, scout).

## Phase Gates

Mechanical enforcement of phase transitions via PreToolUse hooks on the orchestrator:

| Gate | Hook Script | Trigger | Blocks Unless |
|------|-------------|---------|---------------|
| PR gate | `orchestrator-pr-gate.sh` | `gh pr create` in Bash | `validation-report.md` + `review-report.md` exist |
| Teardown gate | `orchestrator-teardown-gate.sh` | `TeamDelete` | All 3 reports exist (validation + review + scout) |
| Validator stop | Prompt hook in validator.md | Validator Stop | Structured report written to `.claude/swarm/validation-report.md` |

All gates are no-ops when `.claude/swarm/` doesn't exist (non-swarm tasks pass through).

### Swarm Artifacts

All phase artifacts are written to `.claude/swarm/`:

| File | Phase | Producer | Required By |
|------|-------|----------|-------------|
| `plan.md` | 2 | orchestrator | — |
| `contracts.md` | 2 | orchestrator | — |
| `validation-report.md` | 4 | validator | PR gate, teardown gate |
| `review-report.md` | 5 | orchestrator (from reviewer) | PR gate, teardown gate |
| `scout-report.md` | 6 | scout | Teardown gate |

## Monitoring

Check task progress via TaskList. For detailed status on individual tasks, use TaskGet.

## See Also

- `/pds:grill` — Requirement interrogation (Phase 1)
- `/pds:verify` — Completion self-check (Phase 4 worker exit)
- `/pds:finish` — Branch completion protocol (Phase 5)
- `/pds:merge` — Merging subtask worktrees
- `/pds:team` — Agent roster and capabilities
- `/pds:instinct` — Pattern capture and lifecycle (Phase 6)
