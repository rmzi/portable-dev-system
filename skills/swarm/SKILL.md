---
description: Launching multi-agent parallel work with the Agentic SDLC. Use when a task benefits from decomposition into parallel subtasks.
---
# /swarm — Agentic SDLC

Six-phase workflow for decomposing, dispatching, and validating parallel work across agent teams. Each phase shows the concrete tool calls needed to execute it.

## Delegation

**If you are not the orchestrator**, spawn one to execute this workflow. Agents terminate when they return output, so **the parent must handle the human approval gate** — not the orchestrator.

**Two-phase delegation pattern:**

```
# Phase 1: Orchestrator runs grill, produces plan, returns it
plan = Agent(subagent_type="pds:orchestrator", name="orchestrator-plan",
      prompt="Run /pds:grill for: <task description>. Tier: <tier>.
             Produce a plan with acceptance criteria. Return the plan — do NOT
             proceed to decomposition. Write swarm state files (.claude/swarm/phase,
             .claude/swarm/tier) before returning.")

# Parent relays plan to human, gets approval/override, then:

# Phase 2+: New orchestrator executes the approved plan through all remaining phases
Agent(subagent_type="pds:orchestrator", name="orchestrator",
      prompt="Plan is approved by human. Execute /pds:swarm Phases 2-6 for: <context>.
             <paste approved plan + acceptance criteria here>.
             Proceed through all phases without stopping for approval.")
```

If no tier is specified, the Phase 1 orchestrator MUST run `/pds:grill` first to determine the tier. Grill is mandatory before any swarm — it validates requirements AND recommends a tier.

The orchestrator has `TeamCreate`, `TaskCreate`, `Task(worker)`, `SendMessage`, and other coordination tools. The main conversation does not — delegation is required.

Everything below is written for the orchestrator.

## Swarm Tiers

Three tiers control model selection and specialist inclusion. The tier is set during Phase 1 (via grill or user override) and stored in `.claude/swarm/tier`. Med matches the current agent defaults — existing swarms are implicitly med.

| Agent | Lite | Med | Heavy |
|-------|------|-----|-------|
| **orchestrator** | sonnet | opus | opus |
| **researcher** | _(skip)_ | sonnet | opus |
| **worker** | haiku | sonnet | sonnet |
| **validator** | haiku | sonnet | sonnet |
| **reviewer** | _(skip)_ | sonnet | opus |
| **documenter** | _(skip)_ | sonnet | sonnet |
| **scout** | haiku | haiku | sonnet |
| **auditor** | _(skip)_ | _(skip)_ | sonnet |

- **Lite**: Daily driver. Crosses 2 modules, follows existing patterns. Haiku workers, sonnet orchestrator. 1-2 workers. Orchestrator self-researches and self-reviews. Cheapest effective configuration.
- **Med**: Serious work. Crosses 2-3 boundaries, some design decisions. Current defaults — no model overrides needed. 2-3 workers. Full specialist roster as needed.
- **Heavy**: Maximum capability. 3+ boundaries, new interfaces, or core abstraction refactors. Opus for reasoning-heavy roles. 3-4 workers. Full specialist roster including auditor.

### Tier Override

User can force a tier: `/pds:swarm lite`, `/pds:swarm med`, `/pds:swarm heavy`. Without an argument, tier is auto-selected via `/pds:grill` step 10. The human confirms or overrides the tier during Phase 1 approval.

## Phase State Machine

The orchestrator tracks the current phase in `.claude/swarm/phase`. Transitions are **forward-only**:

```
plan → decompose → dispatch → validate → consolidate → knowledge
```

Initialize at swarm start:
```bash
mkdir -p .claude/swarm && echo "plan" > .claude/swarm/phase && echo "<tier>" > .claude/swarm/tier
```

Advance by writing the next phase name (`echo "X" > .claude/swarm/phase`) as the first step of each phase. The PR gate and teardown gate enforce phase state (defense-in-depth alongside artifact checks). If the phase file is absent, gates fall through to artifact-only checks.

## Phase 1: Plan

1. **Grill is mandatory.** Run `/pds:grill` to validate requirements and get a tier recommendation. If the caller already provided a tier override, grill still runs (for requirement validation) but the tier output is overridden.
2. Write the tier to state: `echo "<tier>" > .claude/swarm/tier`
3. **Lite tier**: Orchestrator self-researches (skip researcher spawn). **Med/Heavy tier**: Spawn a researcher for codebase context:
   ```
   Task(researcher, model="<tier-model>",
        prompt="Analyze the codebase for X. Query .claude/instincts.md for relevant prior patterns.")
   ```
   Tier models — med: omit `model` (sonnet default). Heavy: `model="opus"`.
   The researcher sends findings back via `SendMessage`. If it calls `ExitPlanMode`, respond with `plan_approval_response` to approve or reject its plan.
4. Synthesize findings into **mechanically verifiable acceptance criteria** — each criterion must be checkable by running a command or reading output (no subjective criteria)
5. **If spawned as Phase 1 only** (plan prompt): Return the plan + criteria + tier. The parent conversation handles human approval and spawns a Phase 2+ orchestrator.
   **If spawned with pre-approval** (full execution prompt): Proceed directly to Phase 2.

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
2. Read tier from `.claude/swarm/tier`. Spawn workers with tier-appropriate model overrides:
   ```
   # Lite — haiku workers
   Task(worker, team_name="project-name", name="worker-auth",
        model="haiku",
        prompt="Implement auth module per task description. Run /pds:verify before reporting done.")

   # Med — no model override needed (sonnet is the agent default)
   Task(worker, team_name="project-name", name="worker-auth",
        prompt="Implement auth module per task description. Run /pds:verify before reporting done.")

   # Heavy — workers stay sonnet (no override), but use more workers for parallelism
   ```
   Use `Task(validator)` for validation tasks, `Task(researcher)` for research, etc. The typed syntax restricts which agent definitions can fulfill the spawn. Always pass the tier-appropriate `model` override — see the Swarm Tiers table above.

   **Worktree isolation:** If workers will edit overlapping files, spawn them with `isolation: "worktree"` so each gets an isolated copy of the repo. If workers touch non-overlapping files (different modules/skills), they can share the current worktree — but document the boundary in each worker's prompt to prevent collisions.
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
2. **Med/Heavy tier**: Spawn a reviewer for pre-human code review:
   ```
   Task(reviewer, team_name="project-name", name="reviewer",
        model="<tier-model>",
        prompt="Review the diff against acceptance criteria from Phase 1. Send your review report via SendMessage when done.")
   ```
   Tier models — med: omit `model` (sonnet default). Heavy: `model="opus"`.
   Write reviewer report to `.claude/swarm/review-report.md` after receiving it via SendMessage.

   **Lite tier**: Orchestrator performs a lightweight diff review and writes `.claude/swarm/review-report.md` directly (no reviewer spawn). The PR gate checks file existence, not authorship.
3. `.claude/swarm/review-report.md` is **required** — PR gate checks for this file regardless of tier.
4. **Med/Heavy tier**: Spawn a documenter if user-facing docs are affected:
   ```
   Task(documenter, team_name="project-name", name="documenter",
        prompt="Update docs for the changes in this PR. Send summary via SendMessage when done.")
   ```
5. Create PR with full context:
   ```bash
   gh pr create --title "feat: ..." --body "## Summary\n...\n## Acceptance Criteria\n...\n## Validation\n...\n## Issues\n..."
   ```
   **Note:** The PR gate blocks `gh pr create` unless phase is `consolidate`+ AND both `validation-report.md` and `review-report.md` exist.
6. **Do not merge.** The PR is the human gate. The orchestrator creates the PR and reports it — the human merges after review.

## Phase 6: Knowledge

1. Spawn scout with tier-appropriate model:
   ```
   Task(scout, team_name="project-name", name="scout",
        model="<tier-model>",
        prompt="Read .claude/instincts.md. Update counts for re-observed patterns. Propose new instincts. Flag high-confidence patterns for skill promotion. Run /pds:eval on skills exercised in this swarm. Write report to .claude/swarm/scout-report.md. Send summary via SendMessage when done.")
   ```
   Tier models — lite: `model="haiku"` (default). Med: omit (haiku default). Heavy: `model="sonnet"`.
2. **Heavy tier only**: Spawn auditor for tech debt scan:
   ```
   Task(auditor, team_name="project-name", name="auditor",
        prompt="Scan the codebase for tech debt, missing tests, and inconsistencies. File findings as GitHub issues. Send summary via SendMessage when done.")
   ```
3. Scout writes report to `.claude/swarm/scout-report.md` **(required — TeamDelete gate checks for this file)**
4. Scout updates observation counts, proposes new patterns, flags promotions (human-gated — new skill = new file = PR review). Scout also runs skill evals per `/pds:eval`.
5. **Shutdown all agents** before cleanup:
   ```
   SendMessage(type="shutdown_request", recipient="worker-auth", content="Work complete, shutting down.")
   SendMessage(type="shutdown_request", recipient="validator", content="Work complete, shutting down.")
   # ... for each active agent
   ```
   Wait for `shutdown_response` from each agent before proceeding.
6. Clean up: `TeamDelete`
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
| `tier` | 1 | orchestrator | Dispatch (model selection) |
| `plan.md` | 2 | orchestrator | — |
| `contracts.md` | 2 | orchestrator | — |
| `validation-report.md` | 4 | validator | PR gate, teardown gate |
| `review-report.md` | 5 | reviewer (or orchestrator at lite tier) | PR gate, teardown gate |
| `scout-report.md` | 6 | scout | Teardown gate |

## See Also

- `/pds:grill` — Requirement interrogation (Phase 1)
- `/pds:verify` — Completion self-check (Phase 4 worker exit)
- `/pds:finish` — Branch completion protocol (Phase 5)
- `/pds:merge` — Merging subtask worktrees
- `/pds:team` — Agent roster, coordination tools, and protocols
- `/pds:instinct` — Pattern capture and lifecycle (Phase 6)
