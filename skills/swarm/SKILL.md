---
description: Launching multi-agent parallel work with the Agentic SDLC. Use when a task benefits from decomposition into parallel subtasks.
---
# /swarm — Agentic SDLC

Six-phase workflow for decomposing, dispatching, and validating parallel work across agent teams. Each phase shows the concrete tool calls needed to execute it.

## Phase State Machine

The orchestrator tracks the current phase in `.claude/swarm/phase`. Transitions are **forward-only**:

```
plan → decompose → dispatch → validate → consolidate → knowledge
```

Initialize at swarm start:
```bash
mkdir -p .claude/swarm && echo "plan" > .claude/swarm/phase
```

Advance by writing the next phase name (`echo "X" > .claude/swarm/phase`) as the first step of each phase. The PR gate and teardown gate enforce phase state (defense-in-depth alongside artifact checks). If the phase file is absent, gates fall through to artifact-only checks.

## Phase 1: Plan

1. Run `/pds:grill` on the requirements to surface gaps and ambiguities
2. Spawn a researcher for codebase context:
   ```
   Task(researcher, prompt="Analyze the codebase for X. Query .claude/instincts.md for relevant prior patterns.")
   ```
   The researcher sends findings back via `SendMessage`. If it calls `ExitPlanMode`, respond with `plan_approval_response` to approve or reject its plan.
3. Synthesize findings into **mechanically verifiable acceptance criteria** — each criterion must be checkable by running a command or reading output (no subjective criteria)
4. Present plan + criteria to the human. **Do not proceed without approval.**

## Phase 2: Decompose

1. Split along architecture boundaries. If CLAUDE.md defines **Agent Zones** (a table mapping zones to paths and merge order), use them to guide decomposition — one task per zone, foundation-first merge order.
2. Use TaskCreate for each work unit. Put acceptance criteria in the `description` field — this is what workers and the validator check against:
   ```
   TaskCreate(
     subject: "Implement auth module",
     description: "JWT login endpoint at POST /auth/login. Token validation middleware on protected routes. Tests for both.",
     activeForm: "Implementing auth module"
   )
   ```
3. Use TaskUpdate to set dependencies between tasks (`addBlockedBy`, `addBlocks`). Workers respect blocked status and prefer tasks in ID order.
4. When zones cross a boundary (e.g., backend <-> frontend), write a **contract** to `.claude/swarm/contracts.md` defining the interface before dispatching.
5. Write decomposition plan to `.claude/swarm/plan.md`.

## Phase 3: Dispatch

1. Create the team:
   ```
   TeamCreate(team_name="project-name", description="Working on feature X")
   ```
2. Spawn workers via `Task(worker)` — use the typed syntax to enforce agent type restrictions. Workers declare `isolation: worktree` in their frontmatter; Claude Code provisions the worktree automatically:
   ```
   Task(worker, team_name="project-name", name="worker-auth",
        prompt="Implement auth module per task description. Run /pds:verify before reporting done.")
   ```
   Use `Task(validator)` for validation tasks, `Task(researcher)` for research, etc. The typed syntax restricts which agent definitions can fulfill the spawn.
3. Assign initial tasks to workers:
   ```
   TaskUpdate(taskId="1", owner="worker-auth", status="in_progress")
   ```
4. Workers implement autonomously using a **pull model**:
   - Read task via `TaskGet` for requirements and acceptance criteria
   - Implement, commit frequently
   - Use `SendMessage` for cross-agent coordination or to report blockers
   - Run `/pds:verify` before declaring done
   - Mark task completed: `TaskUpdate(taskId="1", status="completed")`
   - Check `TaskList` and **self-claim** next unblocked task (prefer lowest ID)
   - Create new tasks via `TaskCreate` if they discover additional work
5. Monitor progress via `TaskList`. Agents go idle between turns — this is normal. Send a message to wake an idle agent.

**Hook note:** PDS hooks log `WorktreeCreate` and `WorktreeRemove` events as workers start and finish. These appear in the audit log for lifecycle traceability.

## Phase 4: Validate

1. Workers run `/pds:verify` (self-check) before reporting task complete
2. Spawn a validator:
   ```
   Task(validator, team_name="project-name", name="validator",
        prompt="Check TaskList for all task branches. Merge them, run full test suite, produce structured pass/fail report. Write report to .claude/swarm/validation-report.md.")
   ```
3. Validator uses `TaskList` to find all tasks, `TaskGet` to read acceptance criteria, merges branches, runs tests, writes structured report to `.claude/swarm/validation-report.md` **(required — PR gate checks for this file)**
4. If issues found:
   - Update tasks: `TaskUpdate(taskId="1", status="in_progress", description="Fix: ...")`
   - Dispatch targeted workers to fix specific failures
   - Re-validate
5. **Escalate to human after 2 failed validation cycles** — don't loop indefinitely

## Phase 5: Consolidate

1. Run `/pds:finish` on each task branch (rebase, clean history, post-rebase tests)
2. Spawn a reviewer for pre-human code review:
   ```
   Task(reviewer, team_name="project-name", name="reviewer",
        prompt="Review the diff against acceptance criteria from Phase 1. Send your review report via SendMessage when done.")
   ```
3. Write reviewer report to `.claude/swarm/review-report.md` after receiving it via SendMessage **(required — PR gate checks for this file)**
4. Spawn a documenter if user-facing docs are affected:
   ```
   Task(documenter, team_name="project-name", name="documenter",
        prompt="Update docs for the changes in this PR. Send summary via SendMessage when done.")
   ```
5. Create PR with full context:
   ```bash
   gh pr create --title "feat: ..." --body "## Summary\n...\n## Acceptance Criteria\n...\n## Validation\n...\n## Issues\n..."
   ```
   **Note:** The PR gate blocks `gh pr create` unless phase is `consolidate`+ AND both `validation-report.md` and `review-report.md` exist.
6. **Get human approval before merge.**

## Phase 6: Knowledge

1. Spawn scout for PDS meta-improvements:
   ```
   Task(scout, team_name="project-name", name="scout",
        prompt="Read .claude/instincts.md. Update counts for re-observed patterns. Propose new instincts. Flag high-confidence patterns for skill promotion. Run /pds:eval on skills exercised in this swarm. Write report to .claude/swarm/scout-report.md. Send summary via SendMessage when done.")
   ```
2. Scout writes report to `.claude/swarm/scout-report.md` **(required — TeamDelete gate checks for this file)**
3. Scout updates observation counts, proposes new patterns, flags promotions (human-gated — new skill = new file = PR review). Scout also runs skill evals per `/pds:eval`.
4. **Shutdown all agents** before cleanup:
   ```
   SendMessage(type="shutdown_request", recipient="worker-auth", content="Work complete, shutting down.")
   SendMessage(type="shutdown_request", recipient="validator", content="Work complete, shutting down.")
   # ... for each active agent
   ```
   Wait for `shutdown_response` from each agent before proceeding.
5. Clean up: `TeamDelete`
   **Note:** The teardown gate blocks `TeamDelete` unless phase is `knowledge` AND all 3 reports exist. TeamDelete also **fails if agents are still active** — always shut down first.

## Phase Gates

Mechanical enforcement of phase transitions via PreToolUse hooks on the orchestrator:

| Gate | Hook Script | Trigger | Blocks Unless |
|------|-------------|---------|---------------|
| PR gate | `orchestrator-pr-gate.sh` | `gh pr create` in Bash | Phase ≥ `consolidate` + `validation-report.md` + `review-report.md` exist |
| Teardown gate | `orchestrator-teardown-gate.sh` | `TeamDelete` | Phase = `knowledge` + all 3 reports exist |
| Validator stop | Prompt hook in validator.md | Validator Stop | Structured report written to `.claude/swarm/validation-report.md` |

All gates are no-ops when `.claude/swarm/` doesn't exist (non-swarm tasks pass through). Phase checks are defense-in-depth — if the phase file is absent, gates fall through to artifact-only checks.

### Swarm Artifacts

All phase artifacts are written to `.claude/swarm/`:

| File | Phase | Producer | Required By |
|------|-------|----------|-------------|
| `phase` | all | orchestrator | PR gate, teardown gate |
| `plan.md` | 2 | orchestrator | — |
| `contracts.md` | 2 | orchestrator | — |
| `validation-report.md` | 4 | validator | PR gate, teardown gate |
| `review-report.md` | 5 | orchestrator (from reviewer) | PR gate, teardown gate |
| `scout-report.md` | 6 | scout | Teardown gate |

## See Also

- `/pds:grill` — Requirement interrogation (Phase 1)
- `/pds:verify` — Completion self-check (Phase 4 worker exit)
- `/pds:finish` — Branch completion protocol (Phase 5)
- `/pds:merge` — Merging subtask worktrees
- `/pds:team` — Agent roster, coordination tools, and protocols
- `/pds:instinct` — Pattern capture and lifecycle (Phase 6)
