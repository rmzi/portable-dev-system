# ADR 0009: Evolving-Body Issue Format + Slim PR — the Issue as Source of Truth

## Status
Accepted

## Context

Issue #156 proposed standardizing PDS's ticket/PR body shape to a strict 7-section issue format (TL;DR, Decisions, Risks, Acceptance Criteria, Full Plan, Dev Diary, Full Conversation) with a deliberately slim PR body that links to the issue instead of duplicating it. Issue #154 proposed the complementary process rule this shape needs to actually stay accurate over a ticket's life: the issue body reflects *current state*, not the original plan — progress lands as comments during the work, and at finish time the body is rewritten into a final writeup while the prior body is preserved as a comment first, never silently discarded.

Neither issue is a bug fix; both are a coordination-pattern decision that changes how `/pds:ticket` and `/pds:finish` behave, which per `/pds:contribute` requires this ADR and a whitepaper-alignment check.

### Why now, and why together

This surfaced directly from work already landed this session: `/pds:resume` (ADR 0008) already treats the GitHub ticket as the durable, portable source of truth for swarm state — that's the same thesis #156/#154 apply to the *human-readable* record, not just the machine-readable one. A code review of PR #160 in this same session found a PR description that had gone stale relative to its actual diff — a concrete, observed instance of exactly the failure mode #154 exists to prevent (a body that reflects an original plan long after reality diverged from it, with no mechanism forcing it to catch up). The two problems — durable *state* for resuming work, and durable *legibility* for a human or future agent reading the record cold — are the same underlying gap approached from two angles: git and GitHub are the coordination substrate humans and Claude Code both already read fluently; formality here is what makes that substrate actually trustworthy over time, not just present.

### What already existed, and why this isn't new infrastructure

`/pds:finish` already had a substantial, working diary pipeline (`scripts/assemble-diary.sh`, `scripts/export-session.sh`) — commit-log gathering, instinct-delta detection, auto-memory extraction, shepherd-journal parsing, ★ Insight extraction from the raw transcript, all wired behind an experimental `PDS_DIARY` flag that posts the result as a single canonical issue *comment*. This ADR's mechanism does not duplicate that gathering — it reuses it. The new script (`scripts/assemble-finish-writeup.sh`) calls `assemble-diary.sh` in dry-run mode internally and extracts its Timeline/What-went-well/What-went-wrong sections and its collapsed transcript block directly, rather than re-implementing git/instinct/memory/shepherd parsing a second time. Mirror, don't invent (the instinct promoted earlier this session, #149) applies to PDS's own scripts, not just to code the agent writes for users.

## Decision

1. **Issue body shape**: 7 sections, fixed order, always present (even if some are placeholder text at kickoff) — TL;DR, Decisions, Risks, Acceptance Criteria, Full Plan, Dev Diary, Full Conversation. Templated at `skills/ticket/templates/issue-body.md`, marked with a stable `<!-- pds:evolving-body -->` HTML comment so tooling can detect the format on an issue that predates it.
2. **PR body shape**: slim — `Closes #<issue>`, a link back to the issue for full context, an optional conversation-file link. Templated at `skills/ticket/templates/pr-body.md`. `/pds:finish` step 7d uses it whenever the branch encodes a tracking issue; falls back to `gh pr create --fill` when it doesn't (not every branch is issue-tied, and forcing a `Closes #<issue>` placeholder with no issue would be actively wrong).
3. **Kickoff time** (`/pds:ticket`, issue creation): populate all 5 non-diary sections from grill/plan output — Decisions and Risks come from grill's own risk-surfacing and assumption-challenging steps, not invented fresh. Dev Diary and Full Conversation stay as explicit placeholder text (`_(Populated by /pds:finish when this branch ships)_`) since there's nothing to show yet.
4. **Mid-flight** (`/pds:ticket` section 3, during execution): only narrow, mechanical edits are allowed — flipping an acceptance-criterion checkbox, appending a new risk or decision as it surfaces. The body is never rewritten wholesale mid-flight; that's reserved for finish time. This is the load-bearing distinction from #154's "don't edit the body mid-flight" rule, narrowed to admit updates that add or toggle a line without touching the reasoning narrative.
5. **Finish time** (`/pds:finish` step 7g, `scripts/assemble-finish-writeup.sh`, gated behind a new `PDS_EVOLVING_BODY=1` flag): fetch the current body, post it as a comment (`### Kickoff (preserved)` the first time an issue goes through this, `### Snapshot (preserved) — <date>` on every rewrite after that — detected via a second marker appended on first rewrite), then overwrite the body with a finish-writeup in the same 7-section shape: TL;DR recomputed as the final outcome (not the kickoff intent), Decisions/Risks/Acceptance-Criteria/Full-Plan carried forward verbatim from the old body (already updated by the mid-flight mechanism in point 4 — this step must not clobber that), Dev Diary and Full Conversation populated for the first time via the reused `assemble-diary.sh` data.
6. **Conversation-text size handling** (#156 acceptance criteria B2/B3): if the assembled transcript exceeds ~60k characters, commit it to `docs/conversations/<date>-<issue>-<slug>.md` and link it from the Full Conversation section instead of embedding inline. PDS's own `docs/conversations/` is git-tracked, not gitignored (confirmed directly — one file already lives there, added April 2026) — a plain `git add` is sufficient; the `-f` force-add #156 specified was written for a different repo whose `docs/conversations/` is gitignored by convention, and doesn't apply here.
7. **Rollout**: `PDS_EVOLVING_BODY=1`, off by default, mirroring exactly how `PDS_DIARY` was introduced — new, unverified-in-live-use mechanisms that mutate a real issue's body earn default-on status by being dogfooded first, not by being shipped as the default on day one. The two flags are mutually exclusive in practice (enabling both would post the same dev-diary content twice, once as a standalone comment and once inside the rewritten body) — documented, not mechanically prevented, since preventing it would mean parsing the other flag's state from inside each script for a combination that's simply a documented misconfiguration to avoid.

## Consequences

### Positive
- Closes a real, observed failure mode (PR #160's stale description) with a mechanism, not just a one-off manual fix.
- Reuses `assemble-diary.sh`'s already-substantial data-gathering rather than duplicating it — the new script is a few hundred lines of composition and section-carrying logic, not a second git/instinct/memory/shepherd parser.
- The evolving-body mechanism directly complements `/pds:resume` (ADR 0008) — both treat the GitHub issue as the durable record; this ADR extends that thesis from machine-readable swarm state to human-readable project narrative.
- Never destructively loses a prior body version — every rewrite is preceded by a preserve-comment post, and if that post fails, the script stops before touching the body at all.

### Negative
- **Not verified against a live GitHub mutation.** Section-extraction logic, the marker-detection logic, and the size-threshold branch were all verified directly (dry-run against real issue bodies, isolated regex/arithmetic checks) — but the actual `gh issue comment` + `gh issue edit` sequence against a real issue has not been exercised end-to-end in this pass. If `gh issue edit` fails after the preserve-comment already posted, the writeup is saved locally and the path is surfaced — but that failure mode itself is unverified, not just assumed safe.
- **Full Plan and Decisions/Risks carry-forward is verbatim, not synthesized.** The finish-writeup does not attempt to annotate the Full Plan with what actually happened per phase (e.g. marking a phase "skipped" or adding a retroactive 4a) — it preserves what was there. Real synthesis of "plan vs. reality" divergence, which #156's own spec describes as valuable, is left to whoever runs `/pds:finish` to edit by hand if they want it; the automation carries forward, it doesn't interpret.
- **Two parallel, gated pipelines exist now** (`PDS_DIARY` comment-only, `PDS_EVOLVING_BODY` body-rewrite) rather than one. This is deliberate — issues created before this ADR don't have sections to carry forward, so the old comment-only path remains the right tool for them — but it's real surface area to maintain until one clearly supersedes the other in practice.
- **No skill-eval automation yet** for the new format (# 156's acceptance criteria C1/C2 — templated eval scenarios verifying exact section order and PR-body line count). Scenario descriptions were added to `skills/ticket/EVAL.md` and `skills/finish/EVAL.md`, but running them through `/pds:eval`'s statistical grading has not happened in this pass.

### Mitigations
- The unverified live-mutation path is exactly why the rollout is flag-gated and off by default (point 7) — the same posture PDS already took with `PDS_DIARY` before trusting it.
- The "two pipelines" surface area is documented explicitly in `/pds:finish` step 7e as a call-out (not left implicit), so a future contributor sees the reasoning rather than having to reconstruct it.

## Alternatives considered

### A. Build a wholly new diary/gathering pipeline for the finish-writeup
Pros: no coupling to `assemble-diary.sh`'s existing shape.
Cons: duplicates substantial, already-working logic (git log parsing, instinct/memory/shepherd extraction) for no benefit — directly against the mirror-don't-invent instinct this session already promoted (#149).
Rejected: reuse via dry-run call + section extraction was straightforward and kept the two scripts' gathering logic as one source of truth.

### B. Make `PDS_EVOLVING_BODY` default-on immediately, since the user explicitly wants this to land as real infrastructure
Pros: no experimental-flag friction; matches the strength of the user's intent.
Cons: the actual `gh issue edit`/`gh issue comment` mutation sequence hasn't been exercised against a live issue in this pass — shipping a body-rewriting mechanism default-on without that verification risks corrupting a real issue's body on first real use.
Rejected: the honest, tested pieces (parsing, template composition, size threshold) are solid; the untested piece (live mutation) is exactly the kind of risk a feature flag is for. Recommend flipping it on after the first real dogfooded run confirms the live path, not before.

### C. Prevent enabling both `PDS_DIARY` and `PDS_EVOLVING_BODY` mechanically (e.g. one script checks the other's env var and refuses to run)
Pros: eliminates the double-post risk entirely.
Cons: adds cross-script coupling for a misconfiguration that's simple to document and unlikely in practice (nobody sets two experimental off-by-default flags at once by accident).
Rejected: documented in the skill and this ADR instead; revisit if it proves to actually happen.

## Open questions

1. Should `assemble-finish-writeup.sh`'s Full Plan carry-forward eventually annotate per-phase outcomes automatically (completed/skipped/retroactively-added), closing the gap named in Consequences? Deferred — needs real dogfooded writeups to know whether manual editing is sufficient or annotation is worth automating.
2. At what point does `PDS_EVOLVING_BODY` graduate from experimental to default-on, and does `PDS_DIARY` get deprecated at that point or kept for issues that predate the 7-section format indefinitely? Not resolved here.
3. #156's acceptance criteria C1-C3 (skill-eval automation, dogfooding pass applying the format to a real PDS ticket) are only partially addressed (eval scenarios written, not run through `/pds:eval`; no live dogfood run in this pass) — worth a dedicated follow-up once the flag is live-tested.
