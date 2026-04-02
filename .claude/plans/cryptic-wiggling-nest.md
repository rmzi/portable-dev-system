# Swarm Plan: Ship All 30 Open Issues

## Context

PDS has 30 open GitHub issues spanning SDLC phase gap improvements, already-shipped features needing closure, documentation updates, and research tasks. ~15 issues are already implemented in the codebase but not closed. The 8 SDLC phase gap issues (#101-108) are the core code work — they improve the swarm skill's 6-phase model with backpressure, pipeline validation, parallel finish, cleanup, and failure recovery. Research issues (#80, #94, #111) produce design docs only. The user wants auditor running per-phase and a cleanup sub-phase added to Phase 6.

## Grill Summary (Validated)

- **Scope:** All 30 issues. ~15 verify-and-close, 8 SDLC phase gaps, 3 docs, 3 research
- **Boundary:** No code implementation for research issues. SDLC changes are protocol/documentation + implement-where-easy hooks
- **Ship mode:** One consolidated PR for SDLC + docs. Research docs included
- **Auditor:** Per-phase (orchestrator can skip only if truly unnecessary)
- **Cleanup:** Sub-phase of Phase 6 (worktree deletion, artifact archival to `docs/swarm-reports/`, state validation, branch cleanup)
- **Artifact archival:** Move `.claude/swarm/*.md` reports to `docs/swarm-reports/` with timestamps
- **Priority:** Must (SDLC #101-108, verify-close), Should (docs #92-93, research #80 #94 #111), Could (nothing deferred)

## Tier: Heavy

Crosses 4+ architecture boundaries. Modifies core SDLC phase model. 30 issues. Full specialist roster.

## Task Decomposition (DAG)

```
                    ┌─────────────┐
                    │  Phase 1    │
                    │  Plan/Grill │
                    └──────┬──────┘
                           │
                    ┌──────┴──────┐
                    │  Phase 2    │
                    │ Decompose   │
                    └──────┬──────┘
                           │
            ┌──────────────┼──────────────┐
            │              │              │
     ┌──────┴──────┐ ┌────┴────┐ ┌───────┴───────┐
     │  worker-1   │ │worker-2 │ │  researcher   │
     │verify-close │ │sdlc-core│ │ #80,#94,#111  │
     │#82-91,95-98 │ │#101-108 │ │ design docs   │
     │    #110     │ │         │ │               │
     └──────┬──────┘ └────┬────┘ └───────┬───────┘
            │              │              │
            │        ┌─────┴─────┐        │
            │        │           │        │
            │  ┌─────┴─────┐ ┌──┴───┐    │
            │  │  worker-3  │ │work-4│    │
            │  │   hooks    │ │ docs │    │
            │  │#103,107,108│ │#92,93│    │
            │  └─────┬─────┘ └──┬───┘    │
            │        │          │         │
            └────────┴────┬─────┴─────────┘
                          │
                   ┌──────┴──────┐
                   │  Phase 4    │
                   │  Validate   │
                   └──────┬──────┘
                          │
                   ┌──────┴──────┐
                   │  Phase 5    │
                   │ Consolidate │
                   └──────┬──────┘
                          │
                   ┌──────┴──────┐
                   │  Phase 6    │
                   │  Knowledge  │
                   │ + Cleanup   │
                   └─────────────┘

Auditor runs at each phase transition (orchestrator decides if skip is justified)
```

### Task 1: worker-1 (verify-close) — No blockers
**Issues:** #82, #83, #84, #85, #86, #87, #88, #89, #90, #91, #95, #96, #97, #98, #110
**Work:**
- For each issue: read issue body, find corresponding implementation in codebase, verify every requirement is met
- If complete: `gh issue close <N> -c "Verified: [evidence]"`
- If partially complete: leave open with comment explaining what's missing
- Output: list of closed issues with evidence, list of any issues left open

**Acceptance Criteria:**
- [ ] Each closed issue has a comment citing specific file paths and code evidence
- [ ] No false closures — partial implementations stay open with gap description
- [ ] At least 12 of 15 issues closed (remaining have documented gaps)

### Task 2: worker-2 (sdlc-core) — No blockers
**Issues:** #101, #102, #103, #104, #105, #106, #107, #108
**Files to modify:**
- `skills/swarm/SKILL.md` — All 6 phases updated
- `agents/orchestrator.md` — Checkpoint, TaskStop, pipeline triggers, cleanup
- `agents/shared-rules.md` — Backpressure awareness, health reporting
- `agents/validator.md` — Pipeline validation, structured report schema
- `agents/scout.md` — Run before shutdown, feedback loop
- `agents/worker.md` — Health heartbeat, checkpoint awareness

**Specific changes per issue:**
- **#101:** Phase 1 → parallel grill (sync) + research (async) tracks. Researcher spawns at same time as grill, converge before Phase 2
- **#102:** Phase 2 → structured acceptance criteria format (markdown checklist with `[ ]` items). DAG validation rules: reject cycles, warn on tasks with no dependents. Agent Zone reference from CLAUDE.md
- **#103:** Phase 3 → backpressure section: TeammateIdle triggers orchestrator review (not just logging), configurable health timeout per task, TaskStop for workers exceeding 2x expected turns. Update shared-rules.md with health reporting
- **#104:** Phase 4 → pipeline validation: validator starts when first task completes (not last). Structured validation report with JSON-checkable fields. LLM eval as supplement
- **#105:** Phase 5 → parallel `/finish` across worktrees. Structured human approval via plan_approval_request/response protocol
- **#106:** Phase 6 → scout spawns BEFORE agent shutdown (can SendMessage to workers). Instincts from `.claude/instincts.md` injected into Phase 1 grill context for next swarm. Cleanup sub-phase: worktree deletion, artifact archival to `docs/swarm-reports/<timestamp>/`, state validation, branch cleanup
- **#107:** Integrate into relevant phases: TaskStop (Phase 3), ExitWorktree (Phase 6 cleanup), TeammateIdle remediation (Phase 3), TaskCompleted triggers (Phase 4)
- **#108:** Checkpoint protocol: orchestrator writes `.claude/swarm/checkpoint.json` at each phase transition (phase, task assignments, progress). Restart protocol: new orchestrator reads checkpoint and resumes

**Acceptance Criteria:**
- [ ] Each phase in SKILL.md reflects the issue's proposed solution
- [ ] Agent .md files reference new protocols where applicable
- [ ] No broken cross-references between SKILL.md and agent files
- [ ] Phase 6 includes cleanup sub-phase with: worktree deletion, artifact archival, state validation, branch cleanup
- [ ] Checkpoint protocol documented with JSON schema example

### Task 3: worker-3 (hooks) — Blocked by Task 2
**Issues:** #103 (backpressure hooks), #107 (Claude Code primitives), #108 (checkpoint)
**Files to modify/create:**
- `hooks/scripts/teammate-idle-gate.sh` — Upgrade from log-only to remediation (send alert to orchestrator)
- `hooks/scripts/orchestrator-teardown-gate.sh` — Add cleanup verification (worktrees removed, artifacts archived)
- Potentially new: `hooks/scripts/checkpoint-write.sh` — If checkpoint writes can be hooked

**Implement-where-easy rule:**
- TeammateIdle upgrade: straightforward (< 50 lines) → implement
- Teardown gate update: straightforward → implement
- Checkpoint hook: evaluate complexity. If > 50 lines or requires new hook event, document only

**Acceptance Criteria:**
- [ ] `teammate-idle-gate.sh` sends structured alert (not just log) when worker has uncommitted changes
- [ ] `orchestrator-teardown-gate.sh` verifies worktree cleanup before allowing TeamDelete
- [ ] Any new hooks registered in `hooks/hooks.json` and `.claude/settings.json`
- [ ] Complex hooks documented in SKILL.md but deferred for implementation

### Task 4: worker-4 (docs) — Blocked by Task 2
**Issues:** #92, #93
**Files to modify:**
- `docs/whitepaper.md` — Update known-gap sections to "implemented" status, add observability layer section
- `CLAUDE.md` — Update project structure (new artifacts, hook count, skill count)
- `README.md` — If it has stale references

**Acceptance Criteria:**
- [ ] Whitepaper known-gap sections for Phases 1-6 updated to reflect implemented solutions
- [ ] CLAUDE.md project structure matches actual file tree
- [ ] No stale references to hook counts, skill counts, or file paths

### Task 5: researcher — No blockers
**Issues:** #80, #94, #111
**Files to create:**
- `docs/auto-claude-research.md` — Analysis of auto-claude (Claude's scheduled/background agent feature) and its relevance to PDS headless agents, plugin distribution, and swarm orchestration
- `docs/model-agnostic-research.md` — Update/expand existing analysis. Actionable recommendations for PDS portability
- `docs/orchestrator-redesign-research.md` — Architecture proposal: dedicated orchestrator agent (not main session), DAG visualization approach, polling mechanism for orchestrator responsiveness

**Acceptance Criteria:**
- [ ] Each doc has: problem statement, analysis, recommendations, next steps
- [ ] #111 doc includes DAG visualization mockup (ASCII or mermaid)
- [ ] #94 doc references existing `pds_llm_agnostic_strategy.md` memory and Claude Code source analysis
- [ ] #80 doc uses WebSearch for current auto-claude documentation

### Auditor: Per-phase
**Trigger:** After each SDLC phase transition
**Focus:**
- Phase 2 → Decomposition: Are tasks well-scoped? Dependencies correct?
- Phase 3 → Dispatch: Are workers assigned correctly? Model tiers appropriate?
- Phase 4 → Validate: Are acceptance criteria being checked mechanically?
- Phase 5 → Consolidate: Cross-reference consistency? No broken links?
- Phase 6 → Knowledge: Cleanup complete? Artifacts archived?

**Orchestrator may skip auditor if:** The phase transition is trivially safe (e.g., no code changes in that phase). Must document skip reason.

## Verification

After the swarm completes:
1. `make test` passes (install smoke tests)
2. `gh issue list --state open` shows reduced count (target: ~3-5 remaining at most)
3. `git diff main --stat` shows expected file changes
4. Cross-reference spot-check: grep for "Phase 1" in SKILL.md and orchestrator.md — descriptions should align
5. `docs/swarm-reports/` directory exists with archived artifacts
6. Research docs exist and have substantive content (not stubs)

## Risk Mitigations

1. **Cross-reference consistency:** worker-2 owns ALL skill + agent .md files. No other worker touches them
2. **False issue closures:** worker-1 must cite specific evidence per-requirement, not just file existence
3. **SKILL.md bloat:** Keep additions concise. Reference agent .md files for details
4. **Research quality:** Researcher uses WebSearch/WebFetch for current information beyond training cutoff
