# Swarm Plan — Fix Three Recurring Integration Issues

**Tier:** med (2-3 boundaries, moderate design decisions, 2-3 workers)
**Branch (current):** `feat/voice-ticket-grill-ledger-cut` — latest commit `0a76c85` adds voice + ticket + grill rewrite + ledger hard-cut + integration fixture. Landing these fixes on top of this branch.

## Context summary

Three independent reliability bugs observed in recent swarms need fixing and propagating:

1. **Worktree isolation hazard** — `git worktree add -b <branch>` from HEAD silently leaves uncommitted parent changes behind. Recovery has been ad-hoc.
2. **Teardown gate failure** — a med swarm wrote `.claude/swarm/phase=done` (not `knowledge`) and still completed `TeamDelete` without `validation-report.md` or `review-report.md`. Gate should have blocked.
3. **Reports should land in the GitHub issue** — `validation-report.md`, `review-report.md`, `scout-report.md` currently only live in `.claude/swarm/`. The associated tracking issue is the durable audit trail, so reports should post there at each phase transition.

All three need the fix itself AND propagation across the rest of the repo (skills, agents, whitepaper, ethos, README, shepherd journal).

## Root-cause analysis

### Issue 1 — Worktree isolation
- `skills/worktree/SKILL.md` documents the creation pattern but has no "is working tree clean?" precondition.
- `agents/orchestrator.md` dispatch workflow (Phase 3) tells workers to `Task(worker, isolation="worktree")` but doesn't require the orchestrator to commit or stash first.
- `hooks/scripts/sync-worktree-permissions.sh` is the existing `WorktreeCreate` hook — but it runs *after* the worktree already exists. Pre-branch protection belongs either (a) in skill/agent protocol, enforced by PreToolUse on Bash `git worktree add` commands, or (b) via an explicit "/pds:worktree dirty-check" step authors are told to run first.
- Chosen default: **auto-commit to a `wip:` marker commit** on the parent branch. Rationale below.

### Issue 2 — Teardown gate
The gate at `hooks/scripts/orchestrator-teardown-gate.sh` actually IS wired (`PreToolUse: matcher=TeamDelete` in `agents/orchestrator.md`) and WOULD reject a `phase=done` value via the `KNOWN_PHASES` check (line 34). So the observed bypass is one of four possibilities:

1. **`.claude/swarm/` was deleted/archived BEFORE `TeamDelete`** — line 19 silently `exit 0`s when the dir is absent. This is likely: the orchestrator archived to `docs/swarm-reports/` then cleared `.claude/swarm/` as part of Phase 6 cleanup *before* calling TeamDelete.
2. **`jq` is not installed in the sandbox** — line 7 silently `exit 0`s with no error surfaced. Easy to miss.
3. **Matcher mismatch** — `matcher: "TeamDelete"` may not match all TeamDelete tool variants if Claude Code fires a differently-named tool.
4. **Swallowed exit code** — some hooks runner path that ignores non-zero.

Fix covers 1, 2, 3 with explicit logging; 4 would show up once logging is loud.

### Issue 3 — Reports to issue
Mechanism already exists (`gh issue comment` in `skills/ticket/SKILL.md`). What's missing is the explicit per-phase wiring in `skills/swarm/SKILL.md`:
- Phase 4 completion → post `validation-report.md` (inline, not attachment)
- Phase 5 completion → post `review-report.md`
- Phase 6 scout completion → post `scout-report.md`
- Skip silently when `.claude/swarm/ticket` is a fallback marker (non-numeric)

Reports can be large (1-10kB). Post inline wrapped in a `<details>` block with a short summary above, so the issue stays readable. `gh issue comment --body-file` supports this.

---

## Acceptance criteria (checklist format — mechanically verifiable)

### Issue 1 — Worktree isolation hazard

- [ ] `skills/worktree/SKILL.md` has a new `### Pre-branch protocol` section BEFORE "Commands" that documents the three options (fail-fast / auto-stash / auto-wip-commit) and declares **auto-wip-commit** the default, with rationale
- [ ] `skills/worktree/SKILL.md` protocol step list for issue-tied creation includes an explicit step 0: "Check for uncommitted changes on the current branch; if present, create a `wip: pre-worktree snapshot` commit on the current branch before branching"
- [ ] `agents/orchestrator.md` Dispatch Workflow documents that worker worktrees MUST only be created when the orchestrator's branch is clean (references the worktree skill protocol)
- [ ] A new helper script `hooks/scripts/worktree-preflight.sh` enforces the protocol: called inline from `/pds:worktree` (not a PreToolUse hook — auto-commit should be explicit, not silent); prints the wip SHA it creates so the user can revert if needed
- [ ] Documentation notes that users can override the default by setting `PDS_WORKTREE_ON_DIRTY=fail` (fail-fast) or `PDS_WORKTREE_ON_DIRTY=stash` (auto-stash + re-apply)
- [ ] Integration fixture (`tests/fixtures/integration-minimal/` or `scripts/seed-integration.sh`) updated ONLY if the new script benefits from an exercisable test — otherwise leave alone

### Issue 2 — Teardown gate enforcement

- [ ] `hooks/scripts/orchestrator-teardown-gate.sh` fails loudly when `jq` is missing instead of silently passing (print `BLOCKED: jq required for teardown gate enforcement. Install jq.` and `exit 2`)
- [ ] Gate prints a diagnostic line to stderr on EVERY invocation (not just blocks) so the user can confirm it fired: `[teardown-gate] phase=<X> cwd=<Y> swarm_dir_exists=<bool>`
- [ ] When `.claude/swarm/` is absent but the orchestrator is calling `TeamDelete`, the gate warns (not silent) that it's skipping enforcement, and suggests archival-before-delete as the likely cause
- [ ] Gate's matcher in `agents/orchestrator.md` covers all TeamDelete variants — verify the literal tool name; if Claude Code uses a namespaced name (e.g. `mcp__.*TeamDelete`), adjust the matcher
- [ ] `skills/swarm/SKILL.md` Phase 6 cleanup sub-phase explicitly reorders so `TeamDelete` happens BEFORE `.claude/swarm/` archival (so the gate always has artifacts to inspect); archival/removal happens after teardown
- [ ] Test: create a fake `.claude/swarm/` with `phase=done` and no reports, simulate the gate invocation via piped JSON, confirm `exit 2` and a specific missing-artifact error message

### Issue 3 — Reports land in the GitHub issue

- [ ] `skills/ticket/SKILL.md` gets a new section "Posting phase reports" documenting the `gh issue comment --body-file` pattern wrapped in `<details>` blocks with a 2-3 line summary header
- [ ] `skills/swarm/SKILL.md` Phase 4 end: after validator writes `validation-report.md`, orchestrator reads `.claude/swarm/ticket`; if numeric, post report as issue comment via `gh issue comment`; if fallback marker, skip silently
- [ ] `skills/swarm/SKILL.md` Phase 5: same pattern for `review-report.md` (after reviewer finishes, before PR creation)
- [ ] `skills/swarm/SKILL.md` Phase 6: same pattern for `scout-report.md` (after scout finishes, before `TeamDelete`)
- [ ] `agents/orchestrator.md` Phase State Machine section updated to mention the ticket-post step at each phase transition (4, 5, 6)
- [ ] Report posting is idempotent: if a comment with a stable marker (`<!-- pds:report:validation -->`, etc.) already exists, edit it in place rather than duplicate
- [ ] Skip gracefully when `.claude/swarm/ticket` content is non-numeric (fallback marker) — no `gh` call, one-line log "ticket is fallback marker; skipping report posting"

### Cross-repo propagation

- [ ] `CLAUDE.md` — add a note under Rules referencing the new worktree pre-branch protocol (so project-level rules stay in sync with the skill)
- [ ] `docs/whitepaper.md` — amend the section that mandates the three reports to note they ALSO land in the tracking issue (line ~83, ~95, ~101 in current file): "The report is archived to `.claude/swarm/<name>-report.md` AND posted to the associated GitHub issue as a comment, so the issue becomes a complete audit trail."
- [ ] `docs/ethos.md` OR `docs/philosophy.md` — add one-line principle on "the ticket is the audit trail" if either file has a relevant section; otherwise skip this bullet (don't force it)
- [ ] `.claude/shepherd-journal.md` — append a session entry documenting the three fixes, the rationale behind the worktree default, and the reordering of Phase 6 cleanup
- [ ] `README.md` — ONLY if a top-level surface (feature list / workflow) references "agentic SDLC" or "swarm reports", add one line noting tickets now carry the full audit trail; otherwise skip
- [ ] Integration fixture — update `scripts/seed-integration.sh` ONLY if exercising the new preflight script requires additional seed state (dirty files, etc.); otherwise skip

---

## File-by-file change list

| File | Change | Rationale |
|------|--------|-----------|
| `skills/worktree/SKILL.md` | Add `### Pre-branch protocol` section; document wip-commit default + env var overrides | Root doc for the skill; authors read this first |
| `skills/swarm/SKILL.md` | (a) Phase 4/5/6 add "post report to ticket" step; (b) Phase 6 reorder: TeamDelete BEFORE archival | Wires the audit-trail behavior; fixes silent-gate root cause #1 |
| `skills/ticket/SKILL.md` | Add "Posting phase reports" section with `<details>` pattern + idempotent markers | Keeps the `gh issue comment` surface centralized in one skill |
| `agents/orchestrator.md` | (a) Phase 3 dispatch: reference pre-branch protocol; (b) Phase state machine mentions ticket post at 4/5/6; (c) verify `TeamDelete` matcher | Orchestrator is the actor; needs explicit cues |
| `hooks/scripts/orchestrator-teardown-gate.sh` | (a) Fail loud on missing `jq`; (b) always-on stderr diagnostic line; (c) warn when swarm dir absent | Fixes bug; makes silent pass-throughs visible |
| `hooks/scripts/worktree-preflight.sh` (new) | Dirty-check + wip commit; honors `PDS_WORKTREE_ON_DIRTY` env var | Mechanical enforcement of Issue 1 protocol |
| `CLAUDE.md` | One-line rule addition referencing pre-branch protocol | Project-level rules mirror skills |
| `docs/whitepaper.md` | Amend three report-mandate locations to note ticket posting | Whitepaper mandates these reports; now includes destination |
| `docs/ethos.md` or `docs/philosophy.md` | Optional one-liner on ticket-as-audit-trail | Only if it fits existing sections |
| `.claude/shepherd-journal.md` | Append session entry documenting fixes | User requested this explicitly |
| `README.md` | Optional — add line if top-level surface discusses SDLC/swarms | Surface behavior change if user-facing |
| `scripts/seed-integration.sh` | Optional — add dirty-state seed if needed for preflight test | Only if the preflight test needs it |

---

## Decomposition hints (Phase 2)

Three natural work units, one per issue, plus a docs sweep. Recommend **3 workers + 1 documenter**:

1. **worker-worktree** — Issue 1: new preflight script, worktree skill, orchestrator dispatch section, CLAUDE.md rule
2. **worker-teardown** — Issue 2: gate script fixes, swarm Phase 6 reordering, regression test
3. **worker-reports** — Issue 3: ticket skill extension, swarm Phase 4/5/6 wiring, orchestrator phase-state notes, idempotent-marker logic
4. **documenter** — whitepaper amendments, ethos/philosophy line, README line, shepherd-journal append

Dependencies (DAG):
- `worker-worktree`, `worker-teardown`, `worker-reports` → parallel (different file sets)
- `documenter` blockedBy all three workers (references their changes)

Worker boundaries — non-overlapping files, so they can share the current worktree rather than spawn individual worktrees. Orchestrator documents the boundary explicitly in each worker's prompt.

---

## Risks and ambiguities (for human to resolve)

1. **Worktree default** — I chose **auto-wip-commit** over fail-fast because:
   - Fail-fast interrupts flow and forces the user to context-switch (commit + retry).
   - Auto-stash is lossy on conflict and requires a separate re-apply step downstream.
   - Auto-commit preserves work, is visible in `git log`, and is trivially revertible with `git reset --soft HEAD~`.
   **Confirm this is the right default.** If you'd prefer fail-fast (safer, more explicit), flip one line in the plan.

2. **TeamDelete matcher** — the current matcher `"TeamDelete"` may or may not catch the exact tool name as Claude Code fires it. Worker-teardown should verify via a test invocation and adjust to a regex like `"^(mcp__.*__)?TeamDelete$"` if needed. If this is the actual root cause of the observed bypass, the fix is one line.

3. **Report size on GitHub** — GitHub issue comments have a 65k char limit. `validation-report.md` can be large on heavy swarms. Worker-reports should truncate with "[full report in `.claude/swarm/validation-report.md`]" if the report exceeds ~50kB, rather than failing the post.

4. **README scope creep** — the task says "README.md if the ticket-as-audit-trail behavior needs surfacing at top level." This is a judgment call; defer to documenter, but lean toward skipping unless README already has a relevant workflow description.

5. **Integration fixture changes** — the task says update ONLY if exercising fixes requires it. Preflight test (Issue 1) can be a unit test of the bash script with a scratch git repo; Issue 2 test is stdin piping to the gate script; Issue 3 test needs `gh` mocking. None of these strictly need the fixture. Recommend workers add small `tests/unit/` bash tests rather than expand the fixture.

---

## Tier confirmation: med

- 2-3 module boundaries touched (skills/, agents/, hooks/, docs/)
- Moderate design decisions (worktree default; idempotent ticket comment marker format; Phase 6 reordering)
- 3 workers + documenter fits med perfectly
- Full specialist roster: shepherd spawned after Phase 1 (this plan), reviewer + documenter in Phase 5, scout in Phase 6
