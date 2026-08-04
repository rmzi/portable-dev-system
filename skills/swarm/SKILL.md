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

The orchestrator has `TaskCreate`, `Task(worker)`, `SendMessage`, and other coordination tools. The main conversation does not — delegation is required.

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
| **shepherd** | _(skip)_ | opus | opus |

- **Lite**: Daily driver. Crosses 2 modules, follows existing patterns. Haiku workers, sonnet orchestrator. 1-2 workers. Orchestrator self-researches and self-reviews. **No shepherd** — workers invoke `advisor_consult` directly for substance questions. Cheapest effective configuration.
- **Med**: Serious work. Crosses 2-3 boundaries, some design decisions. Current defaults — no model overrides needed. 2-3 workers. Full specialist roster as needed. **Shepherd spawned** after Phase 1 grill to walk the ticket alongside workers.
- **Heavy**: Maximum capability. 3+ boundaries, new interfaces, or core abstraction refactors. Opus for reasoning-heavy roles. 3-4 workers. Full specialist roster including auditor. **Shepherd spawned** after Phase 1 grill.

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

Advance by writing the next phase name (`echo "X" > .claude/swarm/phase`) as the first step of each phase. **Write a checkpoint** at each transition — see orchestrator.md for the checkpoint protocol. The PR gate and teardown gate enforce phase state (defense-in-depth alongside artifact checks). If the phase file is absent, gates fall through to artifact-only checks.

## Phase 1: Plan

1. **Parallel tracks.** For Med/Heavy tiers, launch both tracks concurrently at Phase 1 init:
   - **Grill track** (sync, human-facing): Run `/pds:grill` to validate requirements and get a tier recommendation. If a tier override was provided, grill still runs for requirement validation. Load `.claude/instincts.md` (if it exists) and include high-confidence patterns in the grill context.
   - **Research track** (async, codebase exploration): Spawn researcher immediately — it explores while grill runs:
     ```
     Task(researcher, model="<tier-model>",
          prompt="Analyze the codebase for X. Query .claude/instincts.md for relevant prior patterns.
                  Send findings via SendMessage.")
     ```
     Tier models — med: omit `model` (sonnet default). Heavy: `model="opus"`.
     If the researcher calls `ExitPlanMode`, respond with `plan_approval_response` to approve or reject its plan.

   Both tracks must complete before Phase 2 begins. **Lite tier**: skip researcher; orchestrator self-researches after grill.

2. Write the tier to state: `echo "<tier>" > .claude/swarm/tier`
3. Synthesize grill output + researcher findings into acceptance criteria (see Phase 2 for format).
4. **Find or create the GitHub ticket.** Run `/pds:ticket` to search for an existing issue matching this task; create one if none, resolve ambiguity via `AskUserQuestion` if multiple match. Write the issue number to `.claude/swarm/ticket`. Ticket body contains plan + acceptance criteria checklist. If `gh` is unavailable or there's no GitHub remote, warn and proceed without a ticket — note it in `scout-report.md` at Phase 6. See `/pds:ticket` for the full protocol.
5. **Spawn shepherd (med/heavy only, after grill).** After the grill completes and you know the tier is med or heavy, spawn the shepherd agent to walk the ticket alongside workers through Phases 2-6:
   ```
   Task(shepherd, team_name=team_name, name="shepherd",
        model="opus",
        prompt="Walk this ticket. Reference corpus: docs/whitepaper.md, docs/philosophy.md, docs/ethos.md, CLAUDE.md, skills/swarm/SKILL.md, .claude/shepherd-journal.md. Tier: <tier>. Plan context: see .claude/swarm/context.md once Phase 2 writes it. Respond to substance questions via SendMessage. Flag observed drift proactively. Write to journal continuously and on teardown.")
   ```
   **Do NOT spawn shepherd at lite tier** — keeps lite cheap. Workers at lite tier invoke `advisor_consult` directly for substance questions.

   The shepherd reads its reference corpus on spawn, notes its arrival to the orchestrator via SendMessage, and enters steady state. It is single-instance per swarm — if one is already active, skip this step.

6. **If spawned as Phase 1 only** (plan prompt): Return the plan + criteria + tier. The parent handles human approval and spawns a Phase 2+ orchestrator.
   **If spawned with pre-approval** (full execution prompt): Proceed directly to Phase 2.

## Phase 2: Decompose

1. Split along architecture boundaries. If CLAUDE.md defines **Agent Zones** (a table mapping zones to paths and merge order), use them to guide decomposition — one task per zone, foundation-first merge order.
2. Use TaskCreate for each work unit. Acceptance criteria in the `description` field must use **checklist format** so they can be mechanically verified:
   ```
   TaskCreate(
     subject: "Implement auth module",
     description: "- [ ] JWT login endpoint at POST /auth/login\n- [ ] Token validation middleware on protected routes\n- [ ] Tests pass for both",
     activeForm: "Implementing auth module"
   )
   ```
3. **DAG validation.** After setting dependencies with `TaskUpdate(addBlockedBy/addBlocks)`:
   - Verify no dependency cycles (if A blocks B, B must not directly or transitively block A)
   - Warn on orphan tasks — tasks with no `blocks` relationship (may be missing connections)
4. When zones cross a boundary (e.g., backend <-> frontend), write a **contract** to `.claude/swarm/contracts.md` defining the interface before dispatching.
5. Write decomposition plan to `.claude/swarm/plan.md`.
6. **Write context file.** Before dispatching workers, write `.claude/swarm/context.md` containing:
   - **Plan summary** — what we're building and why
   - **Research findings** — key codebase facts from the researcher
   - **Acceptance criteria** — the mechanically verifiable criteria from Phase 1
   - **Key decisions** — architectural choices made during planning, with rationale
   - **Contracts** — interface boundaries between zones (if any)

   This file bridges the context gap — workers read it on init to recover the orchestrator's reasoning without requiring fork-level context inheritance. Keep it concise (under 200 lines) and factual. The shepherd (if spawned) also reads this file to pick up the current swarm's plan.

7. **Update the ticket** (if a ticket was newly created in Phase 1). Write the finalized acceptance-criteria checklist to the ticket body. For a reused ticket that already contains criteria, skip this step — don't duplicate. See `/pds:ticket` for the `gh issue edit` pattern.

## Phase 3: Dispatch

1. Read tier from `.claude/swarm/tier`. Spawn workers with tier-appropriate model overrides — team formation is automatic on the first teammate spawn below, no explicit create call:
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
2. Assign initial tasks to workers:
   ```
   TaskUpdate(taskId="1", owner="worker-auth", status="in_progress")
   ```
3. Workers implement autonomously using a **pull model**:
   - Read task via `TaskGet` for requirements and acceptance criteria
   - Implement, commit frequently
   - Use `SendMessage` for cross-agent coordination or to report blockers
   - For **substance questions** (design, trade-offs, principle-checks), SendMessage the **shepherd** (med/heavy) or invoke `advisor_consult` (lite or shepherd down)
   - For **graph questions** (dispatch, dependencies, phase state), SendMessage the **orchestrator**
   - Run `/pds:verify` before declaring done
   - Mark task completed: `TaskUpdate(taskId="1", status="completed")`
   - Check `TaskList` and **self-claim** next unblocked task (prefer lowest ID)
   - Create new tasks via `TaskCreate` if they discover additional work
4. **Monitor and backpressure.** Check progress via `TaskList`. On `TeammateIdle` events:
   - Check `TaskGet` first — if the agent awaits a blocked dependency, no action needed
   - If the agent has an unblocked task and is idle, send a `SendMessage` to re-activate
   - **Health timeout**: default is 2x the task's estimated turns. On first timeout, send a warning via `SendMessage`. On second timeout, use `TaskStop` and reassign the task
   - If 3+ workers are idle simultaneously with blocked tasks, the bottleneck task may need decomposition or priority escalation
5. **Shepherd is idle-resilient.** The shepherd spawned in Phase 1 continues to respond to SendMessage during Phase 3 and later. If the shepherd goes idle with no traffic, that's normal — proactive flagging is evidence-based, not scheduled. The shepherd will log observations as they accrue.
6. **Comment on ticket** (if one exists). Post a short comment: *"Phase: dispatch. Tier: <tier>. Workers: <count>."* See `/pds:ticket`.

**Hook note:** PDS hooks log `WorktreeCreate` and `WorktreeRemove` events as workers start and finish. These appear in the audit log for lifecycle traceability.

## Phase 4: Validate

1. Workers run `/pds:verify` (self-check) before reporting task complete.
2. **Pipeline validation** — spawn the validator when the FIRST task completes (don't wait for all workers):
   ```
   Task(validator, team_name="project-name", name="validator",
        prompt="Check TaskList for completed tasks. Merge branches as they complete, run tests
                incrementally. Write structured report to .claude/swarm/validation-report.md.")
   ```
3. The validator monitors `TaskList` continuously, merges and tests incrementally. The report must include these JSON-checkable fields:
   - `merge_status`: `"merged" | "conflict" | "failed"` per branch
   - `test_counts`: `{ "total": N, "passed": N, "failed": N, "skipped": N }`
   - `criteria_verdicts`: `[ { "criterion": "...", "status": "pass"|"fail", "evidence": "..." } ]`
   - `overall`: `"ready" | "needs_fixes"`

   LLM evaluation (the validator's Stop hook) supplements these mechanical checks — it does not replace them.
4. If issues found:
   - Update tasks: `TaskUpdate(taskId="1", status="in_progress", description="Fix: ...")`
   - Dispatch targeted workers to fix specific failures
   - Re-validate
5. **Escalate to human after 2 failed validation cycles** — don't loop indefinitely
6. **Flip ticket checkboxes** (if a ticket exists). For each `criteria_verdicts` entry with `status: "pass"`, flip the matching `- [ ]` to `- [x]` in the ticket body via `gh issue edit --body-file`. On overall `"needs_fixes"`, post a comment summarizing which criteria failed. See `/pds:ticket`.

## Phase 5: Consolidate

1. **Parallel `/finish`.** Run `/pds:finish` on each task branch simultaneously — each branch gets its own finish (rebase, clean history, post-rebase tests) in parallel. Wait for all to complete before proceeding.
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
5. **Human approval gate.** Present the consolidated package before creating the PR:
   ```
   ExitPlanMode(plan="## Proposed Merge\n<diff summary>\n\n## Validation\n<key results from validation-report.md>\n\n## Review\n<key findings from review-report.md>")
   ```
   The parent responds with `plan_approval_response`. On approval, create PR. On rejection, return to earlier phases as directed.
6. Create PR with full context. **Include `Closes #<ticket-num>`** in the PR body if a ticket exists (read from `.claude/swarm/ticket`):
   ```bash
   gh pr create --title "feat: ..." --body "## Summary\n...\n## Acceptance Criteria\n...\n## Validation\n...\n## Issues\n...\n\nCloses #<ticket-num>"
   ```
   **Note:** The PR gate blocks `gh pr create` unless phase is `consolidate`+ AND both `validation-report.md` and `review-report.md` exist.
7. **Comment on ticket** (if one exists) linking the PR: `gh issue comment <ticket-num> --body "PR opened: <pr-url>"`. See `/pds:ticket`.
8. **Do not merge.** The PR is the human gate. The orchestrator creates the PR and reports it — the human merges after review.

### Branch Merging

When merging worker branches back into the coordinator, use a rebase-then-fast-forward approach to keep history clean.

#### Single Branch Merge

1. Worker rebases onto coordinator: `git rebase coordinator-branch`
2. Run tests to verify nothing broke during rebase
3. Fast-forward merge: `git merge --ff-only worker-branch` (from coordinator worktree)
4. Clean up: `git branch -d worker-branch`

#### N-Branch Merge (Ordered)

When multiple workers complete in parallel, establish a merge order (foundation-first, smaller changes first) and merge sequentially:

```
Merge order: [W1, W2, W3, ... WN]

Round 1: W1 rebases onto coordinator (conflict-free), merges
         W2..WN rebase onto updated coordinator
Round 2: W2 rebases onto coordinator, merges
         W3..WN rebase onto updated coordinator
...
Round N: WN rebases onto coordinator, merges
         Done.
```

**The worker that is merging owns their conflicts.** They understand their changes best and resolve during rebase. Never force through a conflict resolution without testing.

#### Merge Commands Reference

```bash
# Rebase worker onto coordinator
git rebase coordinator-branch

# Squash fixup commits before merging (non-interactive)
git rebase --autosquash coordinator-branch

# Fast-forward merge (coordinator worktree)
git merge --ff-only worker-branch

# Abort a rebase if things go wrong
git rebase --abort

# Continue rebase after resolving conflicts
git add <resolved-files>
git rebase --continue

# Clean up after merge
git branch -d worker-branch
```

#### Merge to Main

Landing approved PRs on the main branch:

1. Confirm context — verify you're on `main` and in the correct worktree
2. List open PRs — `gh pr list`
3. For each approved PR: check `gh pr checks <number>`, then `gh pr merge <number> --merge`
4. Push main — `git push origin main`
5. Never force-push main. Never merge PRs that haven't passed CI.

## Phase 6: Knowledge

1. **Scout spawns before agent shutdown** — workers are still active so scout can query them for clarification:
   ```
   Task(scout, team_name="project-name", name="scout",
        model="<tier-model>",
        prompt="Read .claude/instincts.md. Update counts for re-observed patterns. Propose new instincts. Flag high-confidence patterns for skill promotion. Run /pds:eval on skills exercised in this swarm. Compact .claude/shepherd-journal.md (keep 3 most recent swarms verbatim, digest older into Historical Digest, promote 3+-observation patterns to instincts). Distill key learnings: write 1-2 auto-memory entries (project or feedback type) capturing decisions that future sessions need, patterns worth remembering, and constraints discovered — skip anything derivable from code or git history. If telemetry exists, run scripts/detect-patterns.sh and scripts/efficiency-chart.sh — include pattern results and efficiency ratio in the report. Permission audit: read .claude/settings.local.json and .claude/settings.json — identify glob-style allow patterns in local that should be promoted to project-level settings (exclude one-off paths). Write a '### Permission Promotions' section in the report. Write report to .claude/swarm/scout-report.md. Send summary via SendMessage when done.")
   ```
   Tier models — lite: `model="haiku"` (default). Med: omit (haiku default). Heavy: `model="sonnet"`.
2. **Heavy tier only**: Spawn auditor for tech debt scan:
   ```
   Task(auditor, team_name="project-name", name="auditor",
        prompt="Scan the codebase for tech debt, missing tests, and inconsistencies. File findings as GitHub issues. Send summary via SendMessage when done.")
   ```
3. Scout writes report to `.claude/swarm/scout-report.md` **(required — the teardown gate checks for this file)**
4. Scout updates observation counts, proposes new patterns, flags promotions (human-gated — new skill = new file = PR review). Scout also runs skill evals per `/pds:eval` and compacts `.claude/shepherd-journal.md`.
5. **Memory distillation**: Before writing scout-report.md, scout distills key learnings into **1-2 auto-memory entries** (project or feedback type). Focus on:
   - Decisions that future sessions need (WHY option A was chosen over B)
   - Patterns worth remembering (recurring constraints, architectural boundaries)
   - Constraints discovered during the swarm (API limits, performance cliffs, edge cases)
   - Skip anything derivable from code, git history, or existing CLAUDE.md
6. **Telemetry analysis**: If `.claude/telemetry.jsonl` exists, scout runs `scripts/detect-patterns.sh` to detect usage patterns and proposes instinct entries for recurring patterns. Results appear in `### Telemetry-Detected Patterns` section of the scout report.
7. **Permission audit**: Scout reads `.claude/settings.local.json` and `.claude/settings.json`. Identifies recurring allow patterns in local (e.g., `Bash(git add:*)`, `Bash(gh pr:*)`) that aren't already in project-level settings. Recommends promotions in a `### Permission Promotions` section of the scout report. One-off commands (specific file paths, session artifacts) are excluded. Only glob-style patterns (`Bash(git *:*)`, `Bash(gh *:*)`, tool names) qualify for promotion.
8. **Shepherd teardown.** If a shepherd was spawned (med/heavy), send shutdown after scout completes and before ending the swarm:
   ```
   SendMessage(type="shutdown_request", recipient="shepherd", content="Swarm complete, shutting down.")
   ```
   The shepherd marks its current swarm section `**Status**: graceful` in the journal and responds with `shutdown_response`. The `SubagentStop` hook (`hooks/scripts/shepherd-finalize.sh`) also fires on abort paths, so the journal is finalized even if shutdown is interrupted.
9. **Shutdown all remaining agents** after scout, auditor, and shepherd complete:
   ```
   SendMessage(type="shutdown_request", recipient="worker-auth", content="Work complete, shutting down.")
   SendMessage(type="shutdown_request", recipient="validator", content="Work complete, shutting down.")
   # ... for each active agent
   ```
   Wait for `shutdown_response` from each agent before proceeding. **This is now the only safeguard against tearing down while agents are still active** — team cleanup is automatic on session end, so there is no `TeamDelete` call left to mechanically fail if a shutdown was skipped. Do not skip this step because it "used to be enforced" by the tool; it is the enforcement now.
10. **Complete the swarm.** There is no explicit teardown call — team cleanup happens automatically when this session ends. This agent's `Stop` hook (`orchestrator-teardown-gate.sh`) gates the stop itself: it blocks with a reason (and this agent's turn continues, unblocked, to address it) unless phase is `knowledge` AND all 3 reports exist AND `.worktrees/` is clean AND `docs/swarm-reports/` exists. Finish the cleanup sub-phase below, then let this turn end normally.
11. **Cleanup sub-phase.** Before ending the turn:
    - **Worktree deletion**: For each `.worktrees/` directory created during the swarm, run `git worktree remove <path>` (call `ExitWorktree` if the orchestrator is inside a worktree)
    - **Artifact archival**: Copy `.claude/swarm/*.md` to `docs/swarm-reports/<YYYY-MM-DD-HHmm>/`
    - **State validation**: Verify all tasks have status `completed` and all branches are merged
    - **Branch cleanup**: Delete merged feature branches: `git branch -d <branch>`
12. **Ticket completion comment** (if a ticket exists). Post a final comment summarizing the swarm outcome and linking the archive path: `gh issue comment <ticket-num> --body "Swarm complete. Archive: docs/swarm-reports/<YYYY-MM-DD-HHmm>/. PR: <pr-url>."` The ticket closes automatically when the PR merges (via `Closes #<num>`). See `/pds:ticket`.

## Phase Gates

Mechanical enforcement of phase transitions via PreToolUse hooks on the orchestrator:

| Gate | Hook Script | Trigger | Blocks Unless |
|------|-------------|---------|---------------|
| PR gate | `orchestrator-pr-gate.sh` | `gh pr create` in Bash | Phase >= `consolidate` + `validation-report.md` + `review-report.md` exist |
| Teardown gate | `orchestrator-teardown-gate.sh` | Orchestrator `Stop` | Phase != `knowledge`: always allowed (not a teardown attempt). Phase = `knowledge`: all 3 reports + clean `.worktrees/` + `docs/swarm-reports/` exist |
| Validator stop | Prompt hook in validator.md | Validator Stop | Structured report written to `.claude/swarm/validation-report.md` |
| Shepherd finalize | `shepherd-finalize.sh` (SubagentStop) | Shepherd subagent stops (graceful or abort) | Always runs — finalizes journal; never blocks |

**Note on the teardown gate:** it fires on every orchestrator turn-end, not just intended teardown — since `TeamCreate`/`TeamDelete` were removed as tools (Claude Code v2.1.178, team lifecycle now automatic), there is no explicit teardown call left to gate. The phase check above is what keeps this safe: an orchestrator instance stopping mid-swarm (e.g. the Phase-1-only orchestrator returning a plan for human approval) is a normal handoff, not a teardown attempt, and passes through unconditionally. Only a stop while phase = `knowledge` is treated as "the swarm claims to be done" and gets the full artifact check. See `docs/adr/0007-teardown-gate-migration-from-teamdelete-to-stop.md`.

All gates are no-ops when `.claude/swarm/` doesn't exist (non-swarm tasks pass through). Phase checks are defense-in-depth — if the phase file is absent, gates fall through to artifact-only checks.

### Swarm Artifacts

All phase artifacts are written to `.claude/swarm/` (ephemeral, archived to `docs/swarm-reports/` in cleanup):

| File | Phase | Producer | Required By |
|------|-------|----------|-------------|
| `phase` | all | orchestrator | PR gate, teardown gate |
| `tier` | 1 | orchestrator | Dispatch (model selection) |
| `plan.md` | 2 | orchestrator | — |
| `context.md` | 2 | orchestrator | Worker init, shepherd |
| `contracts.md` | 2 | orchestrator | — |
| `checkpoint.json` | all | orchestrator | Restart recovery |
| `validation-report.md` | 4 | validator | PR gate, teardown gate |
| `review-report.md` | 5 | reviewer (or orchestrator at lite tier) | PR gate, teardown gate |
| `scout-report.md` | 6 | scout | Teardown gate |
| `ticket` | 1 | orchestrator (via `/pds:ticket`) | All phases (ticket reference) |

The shepherd's journal lives at `.claude/shepherd-journal.md` (project-level, not under `.claude/swarm/`). It persists across swarms and is gitignored by default. Scout compacts it in Phase 6.

## See Also

- `/pds:grill` — Requirement interrogation (Phase 1)
- `/pds:ticket` — GitHub issue find-or-create, plan + criteria tracking (Phase 1 + all phases)
- `/pds:verify` — Completion self-check (Phase 4 worker exit)
- `/pds:finish` — Branch completion protocol (Phase 5)
- `/pds:team` — Agent roster, coordination tools, and protocols (including graph-vs-substance routing)
- `/pds:voice` — Terse register for orchestrator-to-user inline status
