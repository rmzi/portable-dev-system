# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

## [5.0.0] - 2026-08-04

Breaking-change-scale consolidation: the native agent-teams migration (implicit team formation/teardown, named-teammate dispatch fix) changes how orchestrators and skills spawn and coordinate agents. No skill/agent public interface (slash commands, skill names) changed — the break is in the *internal* spawn/coordination pattern that PDS's own docs prescribe, not in anything an end user invokes directly. See `docs/adr/0007` (teardown-gate migration) and `docs/adr/0009` (evolving-body format) for the two largest design decisions folded in here.

### Changed
- **Swarm/team coordination retrofitted onto implicit-team semantics.** Claude Code removed `TeamCreate`/`TeamDelete` at v2.1.178 — agent teams are now implicit per-session (one team, formed on the first spawn; `team_name` accepted-but-ignored, session-derived name). The orchestrator agent, `/pds:swarm`, `/pds:team`, the SessionStart context, and the whitepaper/architecture/teams/proposal docs no longer instruct agents to call the removed tools; teardown is now "shut every agent down, then the team dissolves at session end." Enduring docs state the durable guarantee only — migration notes live in code comments and the tracker (#159), not in the whitepaper.

### Removed
- **`TeamCreate`/`TeamDelete` references across the live surface** (agent, skills, hooks, settings, docs). The teardown gate's dead `TeamDelete` `PreToolUse` trigger was removed; its completion checks are preserved and now run as an orchestrator-scoped `Stop` hook (`orchestrator-teardown-gate.sh`) — see the `[4.24.0]` entry above and `docs/adr/0007` for the resolved re-home decision (Stop-based gate).

### Fixed
- **#170 — `pds:worker` unspawnable: `WorktreeCreate` hook succeeded but returned no path.** PDS's only registered `WorktreeCreate` hook (`sync-worktree-permissions.sh`) never printed the worktree path to stdout — it's a pure side-effect script (symlinks `settings.local.json`) that historically just ran silently. Claude Code's documented `WorktreeCreate` contract requires a command hook to print the worktree path on exit 0; a silent hook satisfies that contract with no output at all, which is exactly the "hook succeeded but returned no worktree path" failure shape reported. Fixed by printing the resolved worktree path (`$WT_ROOT`, already `pwd` inside the worktree Claude Code switched into before firing the hook) on every code path that represents a genuine worktree context — not just the ones that also do symlink work. Verified directly: the fixed hook prints the correct path when run from inside a real `git worktree`. Not verified against a live reproduction of the original error — the reporter's exact failure could not be reproduced in this environment (worktree-isolated agent spawning worked cleanly here even before the fix, likely because this environment isn't exercising PDS's own `hooks.json` wiring). Landed as a doc-aligned hardening fix regardless, since it closes a real gap against the documented contract. The reporter's own two suggested fixes (caller-overridable `isolation`, graceful non-isolated fallback) were confirmed architecturally impossible — `isolation` is frontmatter-only with no spawn-time override, and `WorktreeCreate` failure hard-fails session startup with no fallback path — so this hook fix is the only lever actually available to PDS.
- **#171 — named-worker dispatch pattern documented a constraint that doesn't hold.** The orchestrator is spawned as a named teammate (`Agent(name="orchestrator", ...)`); a teammate cannot spawn further named teammates ("the team roster is flat," per the platform's own error text) — so every `Task(worker, name="worker-auth", ...)` example throughout `skills/swarm/SKILL.md`, `agents/orchestrator.md`, and `skills/team/SKILL.md` documented a spawn pattern that fails in the normal case, not an edge case. Rewrote every spawn example to omit `name=` and capture the returned `agent_id` instead, and made task-mediated coordination (contract in the task description, workers self-claim via `TaskList`) the primary pattern rather than agent-addressed `SendMessage`, per the issue's own recommended fix. This also explains the issue's secondary finding — the shepherd silently degrading to a one-shot consult, since `SendMessage(recipient="shepherd")` would fail the same way.
- **#172 — PR-gate block silently discards chained heredoc writes; gate output could be mistaken for a directive by another agent.** A `PreToolUse` block voids the *entire* Bash command it fires on, not just the `gh pr create` portion — composing a PR body via heredoc and calling `gh pr create` in the same invocation meant a block discarded the composed body along with it, discovered only when the orchestrator went looking for a file that was never written. `orchestrator-pr-gate.sh` now detects chained commands (`<<`, `&&`, `;` before `gh pr create`) and states explicitly in the block message that the chained write did not run either. `skills/swarm/SKILL.md` Phase 5 now documents the safe two-call pattern (write body, confirm it exists, then `gh pr create --body-file` separately) instead of showing the risky one-call version. Separately, both `orchestrator-pr-gate.sh` and `orchestrator-teardown-gate.sh` now prefix every block/warning message with `[PDS GATE]`, so output that reaches an agent other than the one that triggered it (a reported, not fully root-caused, cross-agent bleed) reads unambiguously as tooling output rather than an instruction addressed to whoever's context it lands in. New test suite: `hooks/tests/test-orchestrator-pr-gate.sh` (8 cases).
- **#158 — heavy-tier orchestrator can silently collapse to solo-implementer mode.** Two confirmed spec gaps in `skills/swarm/SKILL.md`, both now closed: (1) Phase 3 had no rule against the orchestrator owning implementation tasks itself — added an explicit hard rule at the top of the phase. (2) Shepherd spawn lived only in Phase 1 step 5, which the two-phase delegation pattern's own prompt language ("do NOT proceed to decomposition" / "Execute Phases 2-6") caused to silently drop across the plan-only/execute split — added a guaranteed checkpoint at the start of Phase 3 that spawns the shepherd if it isn't already active, regardless of what Phase 1 did. Also strengthened the existing advisor-fallback note (substance questions route to `advisor_consult` directly when the shepherd isn't spawned, is idle past its health timeout, or has shut down — not just "shepherd down"). Not implemented: the issue's proposed validator-gate check for ≥1 `advisor_consult` event at med/heavy tier before Phase 5 — that's a real, separate enforcement mechanism on top of the three root-cause fixes, not one of the root causes itself; left for its own pass.

### Added
- **Evolving-body issue format + slim PR bodies (#156, #154), experimental (`PDS_EVOLVING_BODY=1`, off by default).** `/pds:ticket` now creates issues in a fixed 7-section shape — TL;DR, Decisions, Risks, Acceptance Criteria, Full Plan, Dev Diary, Full Conversation — populated from grill/plan output at kickoff (`skills/ticket/templates/issue-body.md`), with only narrow mechanical mid-swarm edits allowed (checkbox flips, appended risks) per section 3's existing convention, no wholesale body rewrites until ship time. `/pds:finish` (new step 7g, `scripts/assemble-finish-writeup.sh`) preserves the current body as a comment first — `### Kickoff (preserved)` the first time an issue goes through this, `### Snapshot (preserved) — <date>` on every rewrite after — then overwrites the body with a finish-writeup: TL;DR recomputed as the final outcome, Decisions/Risks/Acceptance-Criteria/Full-Plan carried forward verbatim, Dev Diary and Full Conversation populated for the first time by internally reusing `assemble-diary.sh`'s existing data-gathering (dry-run call, no duplicate git/instinct/memory/shepherd parsing — mirror, don't invent, per the instinct promoted earlier this session). PR bodies stay slim (`skills/ticket/templates/pr-body.md`) — `Closes #<issue>` plus a link back, not a duplicate of the issue's content; `/pds:finish` step 7d uses it whenever the branch encodes a tracking issue, falls back to `--fill` otherwise. Oversized conversation transcripts (>~60k chars) commit to `docs/conversations/<date>-<issue>-<slug>.md` and link instead of embedding inline. Directly motivated by an observed failure this session: a PR description (#160) that had gone stale relative to its own diff. See `docs/adr/0009-evolving-body-issue-and-slim-pr-format.md` for the full design, including what was deliberately *not* verified (the live `gh` mutation path — hence the flag) and what's carried forward rather than synthesized (Full Plan doesn't get automatic per-phase outcome annotation).
- Eval scenarios for the new format in `skills/ticket/EVAL.md` (new file) and `skills/finish/EVAL.md` — not yet run through `/pds:eval`'s statistical grading.

## [4.24.0] - 2026-08-03

### Added
- **`/pds:resume` skill — reconstructs swarm state after a pause, a crash, or a handoff to a different machine or person.** Reads local `.claude/swarm/checkpoint.json`/`pause.json` when present (same-machine, full fidelity); falls back to the GitHub ticket's comment thread and acceptance-criteria checklist (cross-machine/person — coarser, since the ticket only carries plan-level criteria, not the original fine-grained task decomposition); falls back further to the archived `docs/swarm-reports/<timestamp>/` for swarms that already completed. Discovers in-flight swarms with zero local state via a new `pds-active-swarm` label (explicit argument and branch-name inference tried first; `AskUserQuestion` disambiguates multiple candidates). Recreates stale `in_progress` tasks as `pending` with owner cleared — reattaching a prior session's in-process workers isn't possible on this platform, so Phase 3's normal pull-model redispatch picks the work back up; git-branch partial-completion detection is deferred to a v2 follow-up. See `docs/adr/0008-task-mobility-via-ticket-not-sub-issues.md` for why a fuller design — mirroring every task to a GitHub sub-issue via `github-mcp-server` — was drafted and rejected after adversarial review: hot-path latency in Phase 3's task-claiming, a new mid-swarm GitHub single point of failure, rate-limit exposure at Phase 2 decomposition, 15-30 sub-issues of clutter per swarm with no real reader, and no remaining justification for migrating `/pds:ticket`/`/pds:triage`/`/pds:worktree` off `gh` CLI once sub-issue mirroring itself was cut.
- **`pds-active-swarm` label.** `/pds:ticket` applies it at ticket creation/reuse and removes it at Phase 6 teardown — the mechanism that makes zero-local-state `/pds:resume` discovery possible.

### Fixed
- **`/pds:pause` pointed at a `/resume` skill that never existed** — a dangling, wrongly-namespaced reference (plain `/resume`, no `pds:` prefix). Fixed to `/pds:resume`, which now exists (see Added). `/pds:pause` also now posts the pause state — branch, phase, tier, note — as a `gh issue comment` when a real ticket is on file, reusing the exact mechanism `/pds:ticket` already uses for phase-transition comments. This is what makes a pause portable across machines and people, for the cost of one already-proven API call.
- **The Phase 6 teardown gate has been silently inert since `TeamCreate`/`TeamDelete` were removed as Claude Code tools (confirmed as of v2.1.178).** The gate was a `PreToolUse` hook bound to the `TeamDelete` call; team formation and cleanup are now automatic, so there was no tool call left to trigger it — the check for all three phase artifacts (validation, review, scout reports) plus a clean `.worktrees/` and an existing `docs/swarm-reports/` had nothing enforcing it. Migrated to an orchestrator-scoped `Stop` hook (`hooks/scripts/orchestrator-teardown-gate.sh`, unchanged mechanical body). Confirmed directly against Claude Code's hooks documentation before landing, rather than assumed: `Stop` hooks receive the same `cwd`-bearing stdin JSON `PreToolUse` hooks do, support the same exit-code-2 blocking, and multiple `Stop` hooks (a global plugin-level one plus this new agent-scoped one) compose as AND — neither overrides the other. One behavior change beyond a literal port was required, not optional: `Stop` fires on every orchestrator turn-end, not just an intended teardown, so the gate now passes through unconditionally at every phase before `knowledge` — otherwise a Phase-1-only orchestrator returning a plan for human approval (a documented, normal mid-swarm handoff) would have been wrongly blocked. See `docs/adr/0007-teardown-gate-migration-from-teamdelete-to-stop.md`.
- **`git`/`gh` failed under the sandbox despite being `excludedCommands`, surfaced while pushing this very branch — tracked in #174.** Confirmed by direct testing (identical command, sandboxed vs. sandbox disabled, only variable changed): (1) an SSH remote (`git@github.com:...`) fails deterministically — the sandbox's network proxy is HTTP(S)-only and can't tunnel raw SSH, even to an allowed domain; (2) even after switching to HTTPS, `git fetch` of substantial pack data can still fail (`did not send all necessary objects`) while small pushes and `ls-remote` succeed — an apparent proxy-level issue with git's binary transfer, distinct from the SSH problem; (3) standalone `gh` network calls (`gh api`, `gh auth status`) hit the same TLS/keychain symptoms `excludedCommands` was added in v4.14.0 to fix, though `git credential fill` (shelling out to `gh` as credential helper) worked fine — inconsistent even across `gh` invocation paths. None of the three produced a permission prompt; all ran silently through what behaved like the sandboxed path, contradicting `docs/sandbox.md`'s documented "bypass the sandbox entirely" claim for excluded commands. Whether this is a regression, a harness-specific difference, or a genuine `excludedCommands` scope gap is unresolved — see #174. The only workaround confirmed to work in all three cases: disable the sandbox for that specific git/gh network command. `docs/sandbox.md`'s "Excluded commands" section now documents this; `docs/teams.md` corrected to point there instead of asserting full bypass; `session-start.sh` warns once at session start for the deterministic SSH-remote case.

### Added
- **`hooks/tests/test-orchestrator-teardown-gate.sh` — 14 passing unit tests for the new `Stop`-based teardown gate.** Fixture-based (temp `.claude/swarm/` directories, no live Claude Code session needed), covering the core regression fix (phase pass-through for `plan`/`decompose`/`dispatch`/`validate`/`consolidate`) and every artifact/worktree/archive branch at phase `knowledge`, plus the defense-in-depth edge cases (missing/empty/unrecognized phase file). This also makes true a whitepaper claim ("See `hooks/tests/` for the fixture structure and test runner") that referenced a directory which didn't exist until now.

### Documentation
- **`docs/whitepaper.md` bumped to v4.1.** New "Implemented:" notes for both fixes above (Phase 6, and the "Failure recovery" row in Resolved Questions), a "Platform shift worth tracking:" note in "Native Agent Teams" for the `TeamCreate`/`TeamDelete` removal itself, an updated `TeamCreate` glossary entry (concept, not a callable tool), and a dated Appendix D addendum. `agents/orchestrator.md`, `skills/swarm/SKILL.md`, `skills/team/SKILL.md`, `docs/proposal.md`, `docs/architecture.md`, `docs/teams.md`, `docs/claude-code-source-analysis.md` (dated addendum, March snapshot untouched), and `.claude/settings.json` updated for the same removal. `docs/teams.md`'s already-stale `PermissionRequest` references (removed in v4.6.0) fixed in the same pass while that table was open. `docs/adr/0001` and the archived `docs/swarm-reports/`/`docs/conversations/` snapshots deliberately left untouched — historical record.
- **`docs/sandbox.md`'s "Default Configuration" example corrected to match what `install.sh` actually ships** (it copies the `sandbox` key verbatim from this repo's own `.claude/settings.json`): `excludedCommands` was missing `gh`, `allowUnsandboxedCommands` was documented as `false` but is actually `true`, and `additionalWritePaths` was undocumented entirely. Also fixed a reference to `/pds:allow` (pruned during skill consolidation, #131 — no longer exists) and reconciled a flat contradiction between "never use `dangerouslyDisableSandbox`" and the git/gh workaround documented lower in the same file.
- **Issue #139 ("What's the best way to use `sandbox.excludedCommands`?"), open since April, closed as superseded by #174** — #174 has the actual repro and diary; #139 was a one-line reminder that prompted the v4.14.0 partial fix this session showed to be incomplete.

### Notes
- **`TeamDelete`'s other guarantee — failing outright if agents were still active — has no mechanical replacement now that the tool doesn't exist.** That safeguard is instruction-only from here on (the orchestrator's `SendMessage(shutdown_request)` protocol, awaited before it lets its own turn end) — a named reduction in defense-in-depth, documented in `skills/team/SKILL.md` and ADR 0007, not a silent one.
- **Not yet exercised**: a full live swarm run through Phase 6 to observe the `Stop`-based teardown gate fire in a real orchestrator session (the gate script's own logic is now unit-tested — see Added — but the Stop-hook wiring itself is doc-confirmed, not live-confirmed), and a live `/pds:resume` run against all three of its stated scenarios (same-machine, cross-machine via ticket, zero-local-state via label).

## [4.23.0] - 2026-07-27T22:25:08-04:00

### Added
- **`config-presets/security-baseline.yaml` — the credential perimeter, as a preset.** Denies reading, tampering with, and shelling into credential stores (cloud SDK configs, private keys, package-registry tokens), credential files (`.env`, `*.pem`, `id_rsa*`, `.git-credentials`), and process environments. 58 entries, `scope: both`, each annotated with a `reason`. **On by default in `examples/config.yaml`.** Until now these rules lived only in the repo's `.claude/settings.json`, which is applied exclusively by `install.sh` — so anyone who installed via the marketplace ran with an empty deny list and no perimeter at all. No shipped preset carried any of it, so `pds sync` did not deliver it either. Two groups inside the preset are opinionated and documented as such (outbound remote access; production tripwires) — they false-positive on real infrastructure work and are meant to be dropped by users who do it.

### Fixed
- **Orchestrator couldn't run grill's Q&A protocol.** `skills/grill/SKILL.md` was rewritten in 4.22.0 to require `AskUserQuestion` (every step) and `EnterPlanMode` (its Mode section) — but `agents/orchestrator.md`'s `tools:` frontmatter never granted either, and `pds:grill` wasn't in its `skills:` list. Subagents only get tools explicitly listed in frontmatter, so orchestrator-driven Phase 1 grill (mandatory before every swarm) had no way to ask a structured question — silently degrading to prose or failing outright, with nothing to catch it. Direct `/pds:grill` from the main session was unaffected (the top-level session isn't gated by agent frontmatter). Added `AskUserQuestion`, `EnterPlanMode`, and `pds:grill` to the orchestrator's frontmatter.
- **Nine credential deny rules were silently dead and are now enforced.** Claude Code honours only `Edit(path)` for file permission checks; `Write(path)` deny rules are skipped, with a warning printed to stderr that nothing surfaced. Every file-tampering rule in `.claude/settings.json` was a `Write(...)` and had been a no-op since `f4cd05a`. The effect was one-directional and in the wrong direction: reading a private key was blocked, **overwriting one was not**. Same for `.env`, `*.pem`, and `.git-credentials`. All nine rewritten to `Edit(...)`, which covers every file-editing tool, so the `Read(x)` + `Edit(x)` pairs finally close. Enforcement verified behaviourally — by attempting a write to a matching path and confirming the block — not by counting entries.
- **`mcp__*` removed from `permissions.allow`.** Wildcard tool names are rejected in allow rules, so the entry was a no-op that emitted a startup warning. It was the visible instance of the same class as the nine above.
- **`examples/config.yaml` shipped `protected_branches: []`.** `/pds:finish` reads this list and prompts before pushing to a match — an empty list meant nothing was protected and the prompt never fired, for anyone who copied the example as documented. Now `[main]`.

### Documentation
- **`docs/config.md` — shipped-presets table and a `security-baseline` section.** Documents what the preset does, which parts are opinionated, and how to drop it correctly. Also records three things that had no home: `pds sync` cannot manage the sandbox (no `sandbox` key in the schema); presets resolve from the installed plugin cache, not a repo checkout; and `pds doctor` reports "config parses: ok" for YAML that Claude Code then rejects rule-by-rule — it validates syntax, not semantic acceptance by the consumer.
- Documented that `Bash(...)` deny patterns substring-match the entire command string, so a command that merely *mentions* a guarded path is denied — including one documenting the perimeter itself.

### Notes
- `security-baseline` is committed **unverified**. `pds sync` resolves presets from the installed plugin cache, not the repo, so it cannot be exercised until published. It parses; parsing is not enforcement — that exact distinction is what let nine dead rules ship for months. Verify behaviourally before trusting it.
- Still open: the gap is **activation, not distribution**. The marketplace ships the whole tree — settings, presets, `install.sh`, CLI source — into every user's plugin cache, and nothing applies any of it. Claude Code auto-activates only skills, agents, hooks, and MCP servers, so a `SessionStart` perimeter check is the only mechanism that reaches a user who does not already know they are exposed. Not written. Tracked in #159.
- The sandbox is not observably enforcing in the environment where this was found — writes outside CWD and non-allowlisted network both succeed. Cause undetermined; `docs/proposal.md:63` asserts confinement that could not be demonstrated. Tracked in #159.

### Documentation
- **`docs/whitepaper.md` bumped to v4.0 — a 12-week industry refresh plus a new strategic thesis.** Refreshes model pricing (Sonnet 5, Opus 5, Fable 5/Mythos 5), MCP ecosystem stats and the 2026-07-28 spec overhaul, and cites EARS notation as prior art for acceptance criteria. Adds "The Harness Layer: Where PDS Sits Today," naming PDS's current position as a config layer on Claude Code's generic harness and stating a directional next move toward owning more of the harness layer itself, grounded in 2026's harness-engineering discourse, Gartner's domain-specific-model projections, and Claude Cowork. Two platform-behavior gaps (background-default subagent backpressure, native auto-PR vs. the human gate) are flagged as known-but-unresolved rather than silently assumed away. See `docs/adr/0006-harness-layer-thesis.md`.
- **`docs/competitive-analysis.md` — added the spec-driven-development landscape** (GitHub Spec Kit, BMAD-METHOD, AWS Kiro), previously unaddressed. BMAD's GitHub-issue-documented cost blowouts (80-100x token usage, no lightweight mode) are now cited as external validation of PDS's lite/med/heavy swarm tiers, not just an internally-reasoned optimization.

### Notes
- Filed four follow-up issues from this update, tracked separately rather than folded into this docs-only pass: #164 (EARS into `/pds:grill`), #165 (`TeammateIdle` backpressure vs. background-default subagents), #166 (PR gate vs. native auto-PR), #167 (refresh stale pricing/MCP facts in `docs/claude-code-source-analysis.md` / `docs/model-agnostic-research.md`).

## [4.22.0] - 2026-04-23

### Added
- **`/pds:voice` skill — terse haro+caveman register for main session + orchestrator inline status.** User-facing voice only (subagents unaffected). Fragments, no pleasantries, no hedging ("I think", "basically", "let me"). Doubled key phrase on state transitions ("Done. Done.", "Blocked. Blocked.", "Found. Found."). Relaxes to full prose for architecture/post-mortem/teaching. Code, diffs, paths, commits, PR bodies, tool output: unchanged. Installed via `skills/voice/SKILL.md`; referenced from `CLAUDE.md`.
- **`/pds:ticket` skill — GitHub issue find-or-create with plan + acceptance-criteria tracking.** Orchestrator responsibility. Falls back to a `<!-- pds:ticket -->` marker in-branch when no remote exists. Standardizes the criteria checklist format the swarm/finish pipeline already expects.
- **Minimal Python integration fixture.** `tests/fixtures/integration-minimal/` plus `scripts/seed-integration.sh` provide a realistic, disposable repo for end-to-end PDS verification (voice, grill, ticket, swarm) outside the main codebase.

### Changed
- **`skills/grill/SKILL.md` — number-pad-first rewrite.** `AskUserQuestion` with yes/no or 2-4 numbered options is the default interaction. Mermaid diagram blocks removed (not legible on the number-pad + voice interface). Tier decision reframed as a structured question instead of a recommendation-with-override. `EVAL.md` updated to the new flow.
- **Shepherd word-cap relaxed.** `agents/shepherd.md` drops the 200-word ceiling. Shepherd can now explain like a person while preserving citation rigor. Orchestrator consultation guidance in `agents/orchestrator.md` updated to match.
- **`CLAUDE.md` interface preference.** Explicit note that the user's primary input is number-pad + voice; defaults for agent questions and orchestrator prompts follow from that.

### Removed
- **Ledger daemon coupling severed entirely.** PDS no longer has an external daemon dependency. Four pure-ledger hook stubs deleted, three scrub hooks stripped of `ledger log` calls, and `hooks/hooks.json` deregistrations cleaned up. PDS is now standalone — scrub-and-telemetry hooks still run locally but never call out to an external federation process. This is a breaking removal for any environment that relied on ledger-forwarded events from PDS hooks; nothing in the plugin itself depended on the forwarded data.

### Notes
- Voice + grill + ticket verified end-to-end in an isolated `--plugin-dir` session against `tests/fixtures/integration-minimal/`.
- Shepherd warmth (post-word-cap-removal) not observable during verification — orchestrator never consulted it in the test swarm. Tracked as a follow-up.

## [4.21.0] - 2026-04-22T21:10:47-04:00

### Added
- **`pds.config.yaml` + Rust CLI — portable user-preference surface.** New `cli/` crate ships a `pds` binary (`sync`, `config`, `archive`, `doctor`, `plugins`, `migrate`) that reads `${XDG_CONFIG_HOME:-~/.config}/pds/config.yaml` and fans the contents out to the sinks Claude Code consumes — `~/.claude/settings.json` (permission allow/ask/deny after preset expansion), global gitignore (managed block), per-project `CLAUDE.md` (content between `<!-- pds:start -->` / `<!-- pds:end -->` markers). One source of truth, portable across machines via dotfiles. Replaces the accumulating `PDS_*` env-var surface (14 vars across hooks and skills) with a single queryable config. Hooks now call `pds config get health.serious_min` with env-var fallback; changing a threshold in `config.yaml` takes effect immediately.
- **Permission presets** (`config-presets/pds-default.yaml`, `dev-tools.yaml`). Each entry annotated with `{pattern, verb, scope, reason}` for auditability. User config references presets by name (`presets: [pds-default, dev-tools]`) plus optional per-user `allow/ask/deny` additions. Reasons never reach `settings.json` — they stay in the preset source so future-you understands why a rule exists.
- **Managed-state tracking** at `$XDG_CACHE_HOME/pds/managed-permissions.json` — `pds sync` remembers exactly which allow/ask/deny entries it wrote last time, so dropping a preset from config removes the entries that preset contributed without touching user-authored edits or team-scope additions. Reconcile model: remove `(prev_managed − new_desired)`, add `(new_desired − current_file)`, preserve everything else.
- **TOFU trust model** with fingerprint at `$XDG_CACHE_HOME/pds/sync-fingerprint.sha256`. First sync prompts for confirmation; later syncs are silent unless the config *shape* (top-level keys + preset names + plugin list) changes. Value tweaks (e.g., bumping a threshold) stay silent; structural changes re-prompt.
- **`--project` flag on `pds sync`** — project-scope writes to `$PWD/.claude/settings.json` require explicit opt-in *and* config declaration (`permissions.write_target = user_plus_project_seed`). Prevents `pds sync` in an arbitrary checkout from modifying tracked team files. When config declares intent but `--project` wasn't passed, emits a `note:` line so the skip isn't silent.
- **`pds migrate`** — consolidates pre-journal-layout data (`<repo>/.claude/shepherd-journal.md` per-repo, ephemeral `${TMPDIR}/pds-diary-*.md` temp files) into `$XDG_DATA_HOME/pds/journal/`. Default dry-run; `--apply` to write; copy (not move) by default; `--remove-source` to delete after. Idempotent via "skip if target exists."
- **`pds doctor`** — cross-install health check (config parses, presets resolve, XDG paths writable, `claude` CLI present).
- **Terraform module** (`terraform/pds-s3/`) + one-command apply root (`terraform/examples/default/`) for S3 archive with 30-day Standard → Deep Archive lifecycle. Bucket hardened (public-access-block, SSE-S3, versioning) + least-privilege IAM user (`s3:PutObject` + `s3:ListBucket` only, scoped to bucket).
- **`docs/config.md`** — quick start, XDG path table, sink list, trust model, merge semantics, preset schema, S3 archive setup, debugging recipes.
- **Validation harness** `scripts/test-pds-cli.sh` — 17-checkpoint interactive end-to-end walk through every sync phase, run in a `HOME=$TMPDIR/pds-e2e/` sandbox so CLI writes never touch real settings. Covers preset expansion, JSON merge with user-owned keys preserved, CLAUDE.md markers, global gitignore, TOFU fingerprint, idempotent re-run, value-only change stays silent, shape change triggers re-confirm, reconcile-with-removals, and doctor.

### Changed
- **Capture taxonomy collapsed**: `capture.diary` + `capture.telemetry` + `capture.shepherd_journal` → single `capture.journal` toggle, single `$XDG_DATA_HOME/pds/journal/` root. Session transcripts, telemetry events, and shepherd consultations are entry types inside one journal — not separately-togglable sibling streams. Eliminates the English-synonym confusion (diary/journal) and the incoherent state where "keep the raw data but skip the write-up" was a togglable combination.
- **`hooks/scripts/health-check.sh`** — reads thresholds from config via `pds config get health.serious_min|very_serious_min|idle_reset_min|very_serious_action`, falling back to the existing `PDS_*` env vars if the CLI isn't on PATH. New `very_serious_action: ack` render prefixes the message with "Type 'continue' to acknowledge or /pds:pause to stop" so the user can't slip past a threshold without a conscious response.
- **`hooks/scripts/skill-hint.sh`** — hint decay state at `$XDG_DATA_HOME/pds/hints.json`. Each skill tracks shown→ignored→used counts; after N consecutive ignores (configurable via `hints.decay_after_ignores`, default 3) the hint self-silences for that skill. Respects `hints.enabled: false` in config.
- **`install.sh`** — two new phases: `install_cli` runs `cargo install --path <src>/cli --locked` (warns + degrades if cargo absent), and `run_pds_sync` runs `pds sync --yes` post-install when a config exists. Both wired into the plugin-install path and the `--plugin-dir` dev path.
- **`CLAUDE.md`** — Project Structure section extended with `cli/`, `config-presets/`, `examples/`, `terraform/`. Protected branches rule updated to point at `pds.config.yaml` under `worktree.protected_branches` instead of the prior inline-CLAUDE.md convention. New "User preferences" rule names `pds.config.yaml` as the source of truth.
- **`.gitignore`** — added `cli/target/`, `terraform/**/.terraform/`, `terraform/**/*.tfstate*`, `terraform/**/terraform.tfvars`, `terraform/**/.terraform.lock.hcl`.

## [4.20.1] - 2026-04-21

### Added
- **Shepherd journal as 4th diary signal source.** `scripts/assemble-diary.sh` now reads `.claude/shepherd-journal.md` when present, parses the current swarm section (matched by today's date, or the most recent section as fallback), and routes `### Decisions` + `### Observations` bullets into the "What went well" bucket and `### Violations caught` + `### Failure mode` content into "What went wrong." Complements the existing three sources (instincts deltas, auto-memory files, ★ Insight blocks) without replacing them. No-op when the journal is absent, which is the default for any project that hasn't run a med/heavy swarm with shepherd. Closes the obvious integration gap between 4.20.0 (shepherd) and 4.19.0 (diary): shepherd captures substance live, diary now surfaces it at ship/session-end.

## [4.20.0] - 2026-04-21

### Added
- **Shepherd agent (`agents/shepherd.md`) — persistent cross-swarm substantive advisor.** New first-class role in the agentic SDLC. Spawned once per med/heavy swarm after Phase 1 grill completes; walks the ticket alongside workers through Phases 2-6. Distinct from the orchestrator: orchestrator owns **graph** (dispatch, dependencies, phase state), shepherd owns **substance** (design, trade-offs, principle-checks, whitepaper enforcement). Opus model. Advisory-only — never blocks work. Four capabilities: reactive consult (with citation), running journal (`.claude/shepherd-journal.md`), proactive drift flagging, loop-break after 3 consults on the same unresolved question. Conflict handling: defers to user on user-vs-whitepaper conflicts; after 3 overrides of the same principle across swarms, files a GitHub issue proposing whitepaper review (living-whitepaper feedback loop). Addresses issue #134 and the capacity-waste dimension of issue #111 — shepherd absorbs orchestrator idle time identified in instinct #2.

- **`pds-advisor` MCP server (`mcp/advisor/`).** Bundled MCP server wraps the Anthropic `advisor_20260301` beta tool and exposes a single `advisor_consult` tool. Three-level graceful fallback: (1) no `ANTHROPIC_API_KEY` -> structured degraded response, (2) beta 4xx/5xx/timeout -> retry as plain opus `/v1/messages` without the beta header, (3) 401/403 auth -> surface immediately (no retry). Never throws — every error path returns `{ advice, degraded, reason }`. Registered in `.claude-plugin/plugin.json` as `mcpServers.pds-advisor`. TypeScript source at `mcp/advisor/src/server.ts`; requires one-time `npm install && npm run build` in that directory to produce `dist/server.js`. See `mcp/advisor/README.md`.

- **Shepherd journal protocol.** Project-level `.claude/shepherd-journal.md` accumulates across swarms: decisions made, observations, violations caught + outcomes, user preferences, and cross-swarm technical context. Free-form markdown with per-swarm `## Swarm <id>` sections. Shepherd creates the journal with header on first spawn if absent. Gitignored by default (privacy); users can commit explicitly. Scout compacts in Phase 6 via a keep-recent + historical-digest scheme — patterns seen 3+ times get promoted to `.claude/instincts.md` (the living-instincts feedback loop).

- **`SubagentStop` hook for shepherd journal finalization (`hooks/scripts/shepherd-finalize.sh`).** Idempotent bash script scoped to the `shepherd` subagent via matcher. Finalizes the journal on both graceful exit and abort paths (captures failure-mode data on abort — high-signal pattern learning). Never blocks termination (always exits 0). Safe to retry. Registered in `hooks/hooks.json` under `SubagentStop` with matcher `shepherd`.

- **Worker `advisor_consult` fallback.** `agents/worker.md` adds `mcp__pds-advisor__advisor_consult` to its tools allowlist with a shepherd-style prompt template. Workers route substance questions to the shepherd primarily; when shepherd is unavailable (lite tier — no shepherd — or the shepherd is down), workers invoke `advisor_consult` directly as a fallback with the shepherd-style prompt shape.

### Changed
- **`skills/swarm/SKILL.md` — shepherd spawn in Phase 1, presence through Phase 3.** Phase 1 step 4 spawns the shepherd after grill completes when tier is med or heavy (never lite — keeps lite cheap). Phase 3 (Dispatch) adds a "shepherd is idle-resilient" note — proactive flagging is evidence-based, not scheduled, so an idle shepherd is normal. Worker pull-model updated: substance questions go to shepherd, graph questions go to orchestrator.

- **`skills/team/SKILL.md` — shepherd added to the roster** with the graph-vs-substance routing rule.

- **`agents/shared-rules.md` — shepherd consultation protocol.** Documents how any agent consults the shepherd via `SendMessage` for substance questions.

- **`agents/scout.md` — journal review, compaction, and instinct promotion capability.** Scout now reads `.claude/shepherd-journal.md` in Phase 6, compacts older swarms into a historical digest while preserving the 3 most recent swarms verbatim, and promotes 3+-observation patterns to `.claude/instincts.md`. Write scope extended to include the journal.

- **`docs/whitepaper.md` — shepherd subsection.** Shepherd named as a first-class role; ~20-line paragraph explains shepherd-absorbs-orchestrator-idle-capacity, citing instinct #2 and the transport-waste observation from `docs/claude-code-source-analysis.md`.

- **`docs/philosophy.md` — shepherd principle.** The substance-vs-graph separation added as a development principle.

- **`docs/ethos.md`, `CLAUDE.md`** — shepherd referenced in the agent roster.

- **`.gitignore`** — `/.claude/shepherd-journal.md` ignored by default (privacy).

### Notes
- **Prior-art linkage**: Issue #111 (orchestrator capacity waste + stalling + opacity) seeded `docs/orchestrator-redesign-research.md`, which proposed Option A (spawned orchestrator) and Option B (heartbeat). Shepherd is a third, orthogonal solution — it keeps the orchestrator topology intact and adds a persistent opus companion. Shepherd's existence means Option A can be **explicitly deferred**. #111's remaining recommendations (heartbeat, DAG visualization, TeammateIdle re-engagement) address stalling and opacity, not capacity, and remain separate work.
- **Bootstrapping note**: This release was built by a HEAVY swarm under the old orchestrator topology (no shepherd was available during the build — the feature was being created). Future med/heavy swarms will have shepherd presence by default.
- **MCP build prerequisite**: The advisor MCP server requires `npm install && npm run build` inside `mcp/advisor/` once before Claude Code can spawn it. Without the build, the plugin entry exists but fails to launch; the shepherd degrades to its native opus reasoning with no `advisor_consult` tool. This is an accepted v1 trade-off — making the MCP server portable (pure-bash or python) is a follow-up candidate.

## [4.19.0] - 2026-04-21

### Added
- **SessionEnd hook auto-fires the diary (`hooks/scripts/diary-session-end.sh`).** Registered in `hooks/hooks.json` under `SessionEnd`. Reads `session_id`, `transcript_path`, and `cwd` from the hook JSON payload (schema: `SessionEndHookInputSchema` in Claude Code source). Gated behind `PDS_DIARY=1` and a parseable `<type>/<issue>-<slug>` branch name — no-ops silently otherwise. Invokes `assemble-diary.sh` in the background so shutdown is never blocked. Manual `/pds:finish` invocation remains supported; both paths edit the same canonical comment via the `<!-- pds:diary -->` marker, so double-fires are idempotent.
- **`TRANSCRIPT_PATH` env var in `scripts/export-session.sh`.** Short-circuits the CWD-hash session discovery when an absolute JSONL path is handed in directly. This is the canonical resolution path — Claude Code hooks receive `transcript_path` in their stdin payload, and `assemble-diary.sh` now passes it through. Fixes the fragile "two projects with similar CWD" edge case in the previous heuristic.
- **`FILTER_BRANCH` env var in `scripts/export-session.sh`.** Filters JSONL entries by their `gitBranch` field (confirmed load-bearing via `SerializedMessage` in Claude Code source). Entries without `gitBranch` (early-session system messages) pass through. `assemble-diary.sh` now always passes the current branch, producing a branch-scoped transcript instead of the whole session log.

### Changed
- **`/pds:finish` 7e/7f prose** — Added a pointer to the SessionEnd auto-fire so users understand the diary posts on session close when `PDS_DIARY=1`, not only at ship time.
- **`/pds:export` skill** — Documents `TRANSCRIPT_PATH` and `FILTER_BRANCH` env vars for advanced callers (hook scripts, CI).

### Source-derived
These three changes came from a read of the Claude Code TypeScript source (`src/entrypoints/sdk/coreSchemas.ts`, `src/types/logs.ts`). The hook payload shape and the `gitBranch` message field are stable contract surfaces in the current release; both were load-bearing APIs we weren't using.

## [4.18.1] - 2026-04-21

### Changed
- **Dev-diary pipeline gated behind `PDS_DIARY` env var, off by default.** Shipped as experimental in 4.18.0 but enabled unconditionally, which meant every `/pds:finish` would attempt the branch-name parse and (for legacy branches) prompt for an issue rename. Now Steps 7e and 7f in `/pds:finish` early-return unless `PDS_DIARY` is set to `1`/`on`/`true`/`yes`. `scripts/assemble-diary.sh` has the same guard as a safety net for direct invocations. Enable per-invocation with `PDS_DIARY=1 /pds:finish ...`, or export in your shell rc to opt in permanently.

## [4.18.0] - 2026-04-21

### Added
- **Dev-diary posting in `/pds:finish`** — New Step 7f invokes `scripts/assemble-diary.sh` to assemble a structured dev diary (Summary / Timeline / What went well / What went wrong) and post it as a canonical comment on the branch's tracking issue. Re-ships edit the existing comment in place, keyed off a stable `<!-- pds:diary -->` marker, so each issue ends up with exactly one diary comment. The full session transcript (from `export-session.sh`) is appended inside a collapsed `<details>` block. Signal sources: `.claude/instincts.md` deltas, auto-memory files mtime'd inside the session window, and ★ Insight blocks parsed from the transcript. `gh` failures fall back to a path under `$TMPDIR` — never silent.
- **Branch↔issue convention enforced in `/pds:worktree`** — New "Issue-tied creation" section at the top describes the canonical `/pds:worktree <issue-number> [type]` flow: fetch the issue via `gh issue view`, slugify the title, create a worktree on branch `<type>/<issue>-<slug>` (e.g., `feat/89-cg-receive`). Fails fast if the issue doesn't exist. Free-form creation remains a documented fallback for spikes and PR review.
- **`scripts/assemble-diary.sh`** — Bash + python3 + jq + `gh`. Inputs via env (`BRANCH`, `ISSUE`, `SINCE`, `MODE=post|post-dry`). Honors the portability contract (no compiled artifacts, no new runtime toolchains).
- **Pipeline note in `/pds:export`** — Makes the new caller (`assemble-diary.sh`) discoverable from the export skill.

### Changed
- **`/pds:finish` Step 7** — New Step 7e (parse issue from branch; prompt-and-rename for legacy branches) and Step 7f (post/edit diary) land after the existing 7d push+PR. Legacy branches that don't match `<type>/<issue>-<slug>` trigger an interactive rename rather than silently skipping the diary. Users can still answer `skip` to proceed without posting.

### Migration
- Existing branches without the `<type>/<issue>-<slug>` naming will not be forced through the new convention retroactively. At the next `/pds:finish`, the prompt-and-rename flow offers a one-shot migration. Answer `skip` if the branch genuinely has no tracking issue.

## [4.17.1] - 2026-04-20T21:04:40-04:00

### Added
- **Portability contract assertions in `install.sh --test`** — expanded the regression guard from a single `assert_not_dir crates` into a full ten-assertion block checking for root-level toolchain manifests and build outputs: `Cargo.toml`, `Cargo.lock`, `go.mod`, `go.sum`, `package.json`, `pyproject.toml`, and directories `crates/`, `node_modules/`, `target/`, `dist/`. The prose in `docs/philosophy.md` is the "why"; this block is the enforcement. Motivated by the cg incident where a Rust crate lived in PDS for weeks without being installed or flagged (recorded as instinct).

### Removed
- **`check_gitleaks` auto-install from `install.sh`** — install previously attempted to install gitleaks via `brew` (macOS) or `go install` (Linux) when missing, dragging Homebrew or the Go toolchain into the story despite PDS's portability contract. Runtime scrubbers (`hooks/scripts/secret-scrub.sh`, `hooks/scripts/mcp-secret-scrub.sh`) are regex-only and have no gitleaks dependency — confirmed by a codebase sweep with zero matches under `hooks/`. Users who want gitleaks can install it independently; PDS no longer nudges. `.gitleaks.toml` is retained as repo-local dev tooling (not shipped to user installs).

## [4.17.0] - 2026-04-20T20:12:24-04:00

### Added
- **`/pds:explore` skill (skill #19)** — Agent-side consumer of the `codebase-memory-mcp` SQLite index. Detects `~/.cache/codebase-memory-mcp/<project>.db`; if present, the agent prefers structural SQL queries (callers, callees, module tree, FTS5 fuzzy symbol search, high-complexity triage) over blind Grep. Falls back to Grep cleanly with a one-line hint when no index exists. Zero new runtime dependencies — pure markdown.
- **Portability contract paragraph in `docs/philosophy.md`** — Makes the "markdown + bash + python3 + jq, no compiled artifacts" rule explicit and discoverable. References `/pds:explore` as the pattern: consume external index data via a skill; don't bundle the indexer.

### Removed
- **`crates/cg/` (Code Graph Browser TUI)** — Violated the portability contract: required a Rust toolchain, depended on undeclared `codebase-memory-mcp`, and `install.sh` never copied it to user installs (so it never reached anyone through supported paths). Preserved with full authorship history at `amok-labs/federation` (issue [#89](https://github.com/amok-labs/federation/issues/89)). The agent-side capability ships as `/pds:explore`.
- **`docs/tui-architecture.md`** — Moved with the crate. Lives at `cg/docs/architecture.md` in federation.
- **`build-cg` Makefile target** — Removed alongside the crate.

### Changed
- **`install.sh` smoke tests** — Added `assert_not_dir "crates"` regression guard to prevent future contributions from re-introducing the toolchain dependency without an explicit decision.
- **README.md, CLAUDE.md, docs/architecture.md** — Plugin Structure / Project Structure / Plugin Layout diagrams updated to drop the `crates/` entry. Skills counts incremented (README 14→15, CLAUDE.md 18→19).

## [4.16.0] - 2026-04-20T16:09:35-04:00

### Added
- **ADR 0005: Release Profiles** — Design for declarative per-project release methodology: a `## Release` section in each project's CLAUDE.md names a profile, and a profile registry at `docs/release-profiles/` defines reusable methodologies (claude-plugin-marketplace, npm-package, vercel-auto-deploy, etc.). Motivated by recurring `marketplace.json` drift — fixed manually in 4.11.1, 4.13.1, and again this release — without systemic prevention. Six-phase rollout plan deferred pending design review.
- **`Bash(claude plugins:*)` in project permissions** — Surfaced during `/pds:finish` permission audit. Eliminates per-session approval for plugin management commands.

### Changed
- **Activity-based session health check** — `hooks/scripts/health-check.sh` rewritten to track *continuous* activity rather than wall-clock from session start. Idle gaps between prompts (default 20m, `PDS_IDLE_RESET_MIN`) reset the session clock. Silent below 3h; single factual state line at 3h and 5h thresholds; fires once per tier crossing (no per-prompt spam). New env vars: `PDS_HEALTH_SERIOUS_MIN` (default 180), `PDS_HEALTH_VERY_SERIOUS_MIN` (default 300). Old env vars (`PDS_BREAK_GENTLE`, `PDS_BREAK_FIRM`, `PDS_BREAK_URGENT`) silently ignored. Marker renamed `pds-session-start` → `pds-session-activity`. Supersedes the session-start.sh reset fix from 4.15.0 (#128) — activity-based tracking handles session boundaries via idle detection, so external resets are redundant.
- **Spinner tips reworked** — Prescriptive health reminders ("Take a walk", "Your health matters more than this commit") replaced with factual workflow hints referencing surviving skills. Health context surfaces exclusively via the activity-aware health-check hook, where it can be threshold-gated and activity-based rather than firing interruptively.
- **`/pds:finish` step reorder** — "Extract Knowledge" moves from Step 0 to Step 6 (post-audit, pre-ship), with its own atomic `chore: archive swarm artifacts` commit. Previous placement mixed archived swarm artifacts with code-cleanliness steps (verify/rebase/clean), creating tree-state surprises. Ship renumbered Step 6 → Step 7 with subsections 7a-7d.

### Fixed
- **Marketplace version drift (third occurrence)** — `.claude-plugin/marketplace.json` was at 4.14.0 while `VERSION` had advanced to 4.15.0. Synced to 4.16.0. ADR 0005 (this release) proposes the systemic fix.

### Philosophy
- **Inform, don't legislate** — The health-check refactor, spinner tips rework, and Step 0 reorder in `/pds:finish` all apply the same principle: the system's job is to surface state and capabilities; the human's job is to act on them. Prescriptive reminders get ignored when they matter most and erode trust; factual state lines are harder to dismiss. Complements the human-factors draft added in 4.15.0 (`docs/human-factors.md`).

## [4.15.0] - 2026-04-13

### Changed
- **Skill consolidation: 28 → 14** — Pruned 11 skills (permission-router, telemetry, inspect, instinct, trim, export, allow, sandbox, audit-config, preflight) and consolidated 3 (merge→swarm, dispatch→team, bcp→finish). Ethos moved to `docs/ethos.md`. Net reduction: -1,940 lines.
- **Agent definitions updated** — Removed references to pruned skills from auditor, scout, and validator agent definitions. Validator now references `pds:swarm` for merge coordination.
- **Doc references updated** — Whitepaper, teams.md, migration-v4.md, auto-claude-research.md updated to point to consolidated skill locations.

### Added
- **`docs/human-factors.md`** — Draft whitepaper section on AI psychosis, reinforcement loops, healthy human-in-the-loop practices, and PDS's role as guardrail. Includes author integration placeholders. (Closes #117)
- **`/pds:swarm` Branch Merging section** — Absorbed `/merge` protocol: single branch, N-branch ordered merge, conflict ownership, command reference.
- **`/pds:team` Dispatch Modes section** — Absorbed `/dispatch` protocol: teammate vs fork subagent vs headless, decision flowchart.
- **`/pds:finish` Quick Ship mode** — Absorbed `/bcp` protocol: bump, commit, push, protected branch check, PR creation.
- **tmux socket in sandbox allowlist** — Added `/private/tmp/tmux-*` to `additionalWritePaths` to fix tmux-dependent shell aliases. (Closes #132)

### Fixed
- **Session timer accumulation** — `session-start.sh` now resets `$TMPDIR/pds-session-start` on SessionStart, preventing health-check.sh from reporting inflated hours across sessions. (Closes #128)

## [4.14.0] - 2026-04-13

### Added
- **`gh` added to `excludedCommands`** — Fixes TLS and Keychain failures for `gh` by excluding it from the sandbox. Go-based CLIs use Security.framework for TLS verification, which requires Mach access to `com.apple.trustd` and `com.apple.securityd`. Without sandbox exclusion, `gh` fails with misleading `x509` and "invalid token" errors.
- **Sandbox escalation model** — Three-tier escalation path documented in `/sandbox`: `dangerouslyDisableSandbox` → `!` prefix terminal bypass → `/pds:allow` persistent allowlisting
- **Go-based CLI troubleshooting** — Documented root cause of sandbox failures for Go binaries (Security.framework + Seatbelt interaction) in `/sandbox`

### Fixed
- **`/pds:allow` broken** — Skill used wrong config key (`sandbox.write.allowOnly` → `sandbox.filesystem.allowWrite`) and couldn't write to `~/.claude/settings.json` (sandboxed out). Now uses `dangerouslyDisableSandbox` with `!` prefix fallback.

### Changed
- **Audit checklist** — Replaced non-verifiable Mach lookup check with CLI tools exclusion check (`gh` and `git` in `excludedCommands`)
- **Security layer model** — Reconciled whitepaper (was 8 layers) and sandbox skill (was 6) to a consistent 6-layer enforcement model. Merged overlapping PreToolUse hook layers, moved observability out of defense-in-depth stack (monitoring, not enforcement)
- **Removed non-enforceable config** — Stripped `allowMachLookup` and `allowUnixSockets` from settings and documentation. Neither key is honored by the Claude Code runtime; keeping them implied enforcement that didn't exist.

## [4.13.1] - 2026-04-10T03:28:52-04:00

### Changed
- Rewrite telemetry hooks to use ledger daemon — replace JSONL file writes with `ledger hook` one-liners, remove ~140 lines of shell telemetry logic
- Sync marketplace.json version with project version

## [4.13.0] - 2026-04-07

### Added
- **Worktree permission sync** — New `sync-worktree-permissions.sh` hook symlinks `settings.local.json` from repo root into worktrees on SessionStart and WorktreeCreate, so runtime permission approvals propagate across all worktrees (#125)
- **Pre-approved git/gh patterns** — 16 common `Bash(git *:*)` and `Bash(gh *:*)` patterns added to project-level `settings.json` allow list, eliminating per-session re-approval
- **Permission audit in `/finish`** — New step 5 reviews `settings.local.json` for glob-style patterns that should be promoted to project settings before shipping
- **Permission audit in Phase 6 Knowledge** — Scout now reads both settings files and reports promotion candidates in `### Permission Promotions` section of scout report

## [4.12.0] - 2026-04-03

### Added
- **`/pds:triage` skill** — Reads Claude Code `/insights` output (report.html + facets + session-meta), analyzes each section systematically, and creates GitHub issues across repos with interactive confirmation. Six phases: Load, Parse, Analyze, Walk-Through, Create, Persist. Saves snapshots to `~/.config/pds/insights/` with fingerprint-based deduplication across runs. Includes EVAL.md with 6 test scenarios.
- **Skill table sync** — CLAUDE.md, README.md, and docs/skills.md now list all 28 skills (added missing: pause, allow, export, dispatch)

## [4.11.1] - 2026-04-02

### Fixed
- **Marketplace version drift** — `marketplace.json` was stuck at `4.1.0` while project was at `4.11.0`. Synced all co-located version files.

## [4.11.0] - 2026-04-03

### Added
- **Session health monitoring** — `hooks/scripts/health-check.sh` UserPromptSubmit hook tracks session duration and injects break reminders at configurable thresholds (30m gentle, 60m firm, 120m urgent). Opt-out via `PDS_HEALTH_REMINDERS=0` (#114)
- **Health-aware spinner tips** — Replaced PDS usage tips with health-focused messages: hydration checks, stretch reminders, break encouragement (#115)
- **`/pds:pause` skill** — Structured session pausing: auto-commits WIP, saves state to `.claude/swarm/pause.json` (phase, tier, branch, note), suggests agent shutdown (#116)
- **`/pds:bcp` auto-bump** — Bump type now optional. Auto-detects from conventional commits since last tag (fix→patch, feat→minor, BREAKING→major). Defaults to patch. Post-ship /pds:pause nudge (#118)
- **`/pds:allow` skill** — Sandbox write allowlist management. Expands paths, warns on sensitive directories (~/.ssh, ~/.aws), wraps `claude config set` (#121)
- **Research: bash mode** — Analysis of Claude Code bash mode vs separate terminal. Recommendation: unified for most work, terminal for TUIs/watchers/auth (#119)
- **Research: secret scanners** — Evaluation of sentinel-ai and detect-secrets. Recommendation: sentinel-ai for PostToolUse hooks, detect-secrets for CI (#120)

### Fixed
- **Git push deny rules** — Confirmed duplication between project/user settings is benign (Claude Code deduplicates). Won't-fix (#123)

## [4.10.1] - 2026-04-02

### Added
- **Hook unit test framework** — `scripts/test-hooks.sh` with 12 test cases for secret-scrub and mcp-secret-scrub hooks. `make test-hooks` target (#122)
- **Secret scrub EVAL.md** — 3 agent-level eval scenarios for secret scrubbing hooks (#122)
- **Whitepaper: Testing and Resilience** — New section documenting three testing layers (unit, eval, integration), hook testing rationale, and the proven improvement cycle (#122)

## [4.10.0] - 2026-04-02

### Added
- **Secret scrubbing (scrub-don't-block)** — PreToolUse hook rewrites Bash commands to pipe output through sed scrubber, redacting 12 secret patterns (sk-*, ghp_*, AKIA*, xoxb-*, JWT, .env KEY=value, etc.) before output enters AI context. PostToolUse hook scrubs MCP tool responses via `updatedMCPToolOutput`. Secrets never reach Claude's context window (#113)
- **Encrypted scrub telemetry** — Scrub events logged with `age` encryption (full command detail) to `~/.config/pds/scrub-telemetry.age`. Metadata-only fallback when age unavailable
- **gitleaks integration** — `install.sh` auto-installs gitleaks (brew/go) and age. Ships `.gitleaks.toml` with PDS-specific patterns and allowlists for docs/hooks directories
- **Static deny rules** — `/proc/*/environ` and `/proc/self/environ` blocked (no legitimate PDS use case)

## [4.9.0] - 2026-04-02

### Added
- **SDLC Phase 1: Parallel grill + research** — Grill (sync, human-facing) and researcher (async, codebase exploration) now run concurrently, converging before Phase 2 (#101)
- **SDLC Phase 2: Decomposition conventions** — Structured acceptance criteria (checklist format), DAG cycle/orphan validation, Agent Zone formalization (#102)
- **SDLC Phase 3: Backpressure** — TeammateIdle triggers orchestrator review, configurable health timeouts, TaskStop for runaway workers, health reporting in shared-rules (#103)
- **SDLC Phase 4: Pipeline validation** — Validator starts on first task completion (not last), structured JSON-checkable report fields (#104)
- **SDLC Phase 5: Parallel /finish** — Concurrent branch finalization across worktrees, structured human approval gate via ExitPlanMode (#105)
- **SDLC Phase 6: Cleanup sub-phase** — Scout before shutdown, instinct feedback to Phase 1, worktree deletion, artifact archival to `docs/swarm-reports/`, state validation, branch cleanup (#106)
- **Checkpoint protocol** — Orchestrator writes `.claude/swarm/checkpoint.json` at phase transitions for failure recovery (#108)
- **Claude Code primitive integration** — TaskStop, ExitWorktree, TeammateIdle remediation, TaskCompleted triggers wired into SDLC phases (#107)
- **Research: auto-claude** — Analysis of cloud/desktop/loop scheduling tiers and PDS relevance (`docs/auto-claude-research.md`) (#80)
- **Research: model-agnostic strategy** — Proxy paths, community gateways, PDS portability recommendations (`docs/model-agnostic-research.md`) (#94)
- **Research: orchestrator redesign** — Dedicated orchestrator agent architecture, DAG visualization, heartbeat protocol (`docs/orchestrator-redesign-research.md`) (#111)

### Changed
- **Hook: teammate-idle-gate.sh** — Emits structured JSON alert for orchestrator backpressure (#103)
- **Hook: orchestrator-teardown-gate.sh** — Verifies worktree cleanup and artifact archival before TeamDelete (#106)
- **Whitepaper** — All 6 phase Known Gap sections updated to Implemented status, removed stale PermissionRequest references (#93)
- **CLAUDE.md** — Project structure updated with `docs/swarm-reports/` and `.claude/swarm/` (#92)
- **README.md** — Hook event table expanded from 7 to 11 entries (#92)

### Fixed
- **Status line settings** — Added missing `statusLine` key to `.claude/settings.json` (#97)

## [4.8.1] - 2026-04-02

### Added
- **`/pds:export` skill** — Export Claude Code session JSONL to human-readable markdown with role markers (👤 Human, 🔵 Claude, 🤖 Agent, ⚙️ System), timestamps, and compact tool call summaries. Supports `--list`, `--session`, `--repo`, `-o` flags.
- **7 instincts recorded** — First lexicon entries: context loss as transport waste, orchestrator idle time, squash-before-push, source analysis compound returns, user-level telemetry, plugin.json sync, stale cache cleanup.

## [4.8.0] - 2026-04-02

### Added
- **Context protocol** — Orchestrator writes `.claude/swarm/context.md` before worker dispatch, containing plan summary, research findings, acceptance criteria, and key decisions. Workers read it on init to recover orchestrator context without fork-level inheritance. Documented in whitepaper (Known Gap + Path Forward), swarm skill (Phase 2), orchestrator agent, worker agent, and shared-rules.
- **Dual-dispatch model** — Orchestrator chooses fork subagent (quick/invisible/context-inheriting) vs team teammate (long-running/visible/role-specialized) at runtime based on task characteristics. Documented in whitepaper Native Agent Teams section, swarm skill Phase 3, and orchestrator agent.
- **Headless agents** — New whitepaper subsection documenting three dispatch modes (teammate, fork, headless) with use cases for background/scheduled agent execution via CronCreate, run_in_background, and SessionStart/Stop hooks. Adoption Path Phase 3 updated as partially achievable today.
- **`/pds:dispatch` skill** — New skill for agent dispatch mode selection. Decision flowchart for teammate vs fork vs headless. Documents when to use each mode with concrete examples.
- **Efficiency measurement** — New whitepaper section grounding waste analysis in Value Stream Mapping (Ohno 1988), XP (Beck 2004), and Lean Software Development (Poppendieck 2003). Maps TPS seven wastes to agentic SDLC equivalents. Defines efficiency ratio (n) and binary efficiency chart.
- **`scripts/efficiency-chart.sh`** — Color-coded ASCII value stream visualization per agent. Classifies waste by TPS category (waiting=red, transport=yellow, over-processing=magenta, defects=bright-red, motion=cyan). Supports `--user` (user-level telemetry), `--session <id>`, `--repo <name>`, `--last <N>` filters.
- **User-level telemetry persistence** — Hooks now write to both `.claude/telemetry.jsonl` (project, may be lost with worktrees) and `~/.claude/telemetry/sessions.jsonl` (user-level, survives worktree cleanup). User-level events include `repo` field for cross-project analysis. Enables retrospective session analysis.
- **3 new whitepaper references** — Ohno (TPS) [13], Beck (XP) [14], Poppendieck (Lean Software Dev) [15] in Appendix C
- **5 new glossary terms** — Efficiency Ratio, Headless Agent, Dual-Dispatch, Context Protocol

### Changed
- **Whitepaper Known Gap (Native Agent Teams)** — Replaced "complementary" hand-wave about fork subagents with proper Known Gap documenting three-system disconnect. Cites 5 community issues (anthropics/claude-code#24316 and 4 related). Path Forward describes dual-dispatch + context protocol.
- **Swarm skill Phase 2** — New step 6: write context file before dispatch
- **Swarm skill Phase 3** — Dual-dispatch guidance (when to fork vs spawn teammate)
- **Swarm skill Phase 6** — Scout prompt includes `scripts/efficiency-chart.sh` alongside detect-patterns
- **Swarm artifacts table** — Added `context.md` (Phase 2, orchestrator, worker init)
- **Orchestrator agent** — Phase 2 writes context.md; Phase 3 documents dual-dispatch
- **Worker agent** — Process step 1: read `.claude/swarm/context.md` if it exists
- **Shared-rules** — Context file reading in Context Efficiency section; new Efficiency section with phase transition logging guidance
- **Scout agent** — New step 7b: efficiency analysis via efficiency-chart.sh; new Efficiency section in output format
- **Adoption Path Phase 3** — Updated from "Vision-forward" to "Partially achievable today" with headless agent primitives

## [4.7.0] - 2026-04-02

### Added
- **Whitepaper v3.0** — Merged update-wp branch content: Plugin Architecture, Hook Lifecycle, LLM Independence sections, 6 Known Gap analyses with Path Forward for each phase, Appendix D (Platform Architecture), fork-subagent trade-off analysis, enterprise readiness section
- **Source analysis deepening** — 10 new insights from `docs/claude-code-source-analysis.md` woven into whitepaper main body: streaming tool parallelism (Phase 3), tool result storage (Phase 4), tool deferral alignment (Instruction Architecture), fork-subagent vs specialized-agent trade-offs (Native Agent Teams), 5-mode compaction detail (Context Compression), hook response capabilities (Hook Lifecycle), per-agent cache economics (Cost Considerations), enterprise lockdown controls (Governance), shared-rules cache optimization (Agent Isolation), platform positioning section
- **Platform Positioning section** — New whitepaper section documenting where PDS leads vs. where Anthropic leads, based on source analysis competitive framing
- **Prompt Cache Economics** — New cost section documenting per-agent cache warming tax and shared-rules optimization strategy
- **Enterprise Readiness** — New governance subsection covering `strictPluginOnlyCustomization`, `strictKnownMarketplaces`, `allowManagedHooksOnly` impact on PDS deployment
- **5 new glossary terms** — Plugin, Hook, Settings Hierarchy, Prompt Cache, Compact (from update-wp)
- **2 new resolved questions** — "How does PDS plug into Claude Code?" and "What does PDS own vs. Claude Code?"

### Changed
- **Defense layers: 7 → 8** — Restored Layer 3 (Permission hooks / LLM-as-judge) and added Layer 8 (Observability) from main
- **Compact glossary** — Updated from 3 modes to 5 modes (added reactive compact, context collapse, history snip)
- **Competitive analysis** — April 2026 date, source analysis references, unique competitive advantage section, cloud opportunity
- **Philosophy** — Platform Understanding section, ethos reference for principles
- **Proposal** — v2.1, achievable/vision-forward status column, prose improvements
- **Teams** — New Concepts section (Plugin, Skill, Agent, Hook), expanded Hook Events table, Task(agent_type) docs, 4-layer settings hierarchy
- **README** — Hook Events table, Competitive Analysis doc link, restructured docs table

## [4.6.2] - 2026-04-01

### Fixed
- **Telemetry + inspect skills** — rewritten from descriptive stubs to procedural skills with concrete tool calls (`Read`, `Bash`, `Edit`, `TaskList`)
- **detect-patterns.sh** — fixed subshell variable bug where `PATTERNS_FOUND` incremented inside piped `while` loop never propagated; replaced with temp file + `grep -c`
- **Inline hooks extracted** — WorktreeCreate/InstructionsLoaded 200+ char inline commands extracted to `hooks/scripts/worktree-telemetry.sh` and `instructions-telemetry.sh`
- **python3 dependency** — added `check_python3()` to install.sh alongside `check_jq()`, documented in README requirements section
- **Extension catalog** — restructured from flat table to Active (12) / Unused (16) split; fixed skill count 20→23
- **Stale PermissionRequest refs** — removed from CLAUDE.md and README hooks list

### Added
- **trim/EVAL.md** — 4 test scenarios (baseline comparison, cross-ref validation, style rules, no-op)
- **Trim interactive Q&A** — rewritten to follow grill's pattern: enter plan mode, present findings step-by-step, wait for human approval before editing

### Changed
- **Trim baseline** — updated from ~1,442 to ~3,180 with version history table documenting growth justification

## [4.6.1] - 2026-03-31

### Added
- **Shared behavioral rules** — `agents/shared-rules.md` with `inherits: shared-rules` in all 8 agents. Common rules for polling guardrails, task claiming, error escalation, and completion protocol (#78, #71, #74)
- **3 new skills** — `/pds:rebase` (focused rebase + autonomous `--fix` mode), `/pds:pr-review` (systematic PR comment resolution), `/pds:preflight` (environment validation). Skill count: 18 → 21 (#70, #72, #75)
- **EVAL.md for new skills** — 2 scenarios each for rebase, pr-review, and preflight
- **3 ADRs** — Hooks enforcement for skills (#77), stricter research mode (#62), PDS metrics tracking (#32)
- **Autonomous rebase-fix loop** — `/pds:rebase --fix` with 3-cycle conflict resolution and test-fix iteration (#73)
- **Auto mode compatibility** — `autoMode` config restructured for Claude Code's auto permission mode. Expanded `allow` with swarm operations (subagent spawning, team management, task coordination, worktree ops). Expanded `environment` to ~15 entries with comment-style placeholder hints for org-specific customization.
- **Auto mode interaction docs** — `/pds:sandbox` documents how auto mode interacts with each PDS security layer, autoMode config guidance, and denial thresholds.
- **CI/CD and headless guidance** — `/pds:sandbox` and whitepaper document Anthropic's recommended permission modes for CI/CD (`dontAsk` or `acceptEdits` + `--allowedTools`, not auto mode).
- **`dontAsk` and `auto` permission modes** — documented in whitepaper permission tiers and `/pds:team` skill.
- **Auto mode notes in agents** — researcher, reviewer, auditor document that `plan` mode is overridden in auto mode.
- **autoMode deep-merge** — `install.sh` preserves user customizations (org-specific environment entries) across PDS upgrades via array union + deduplication.

### Changed
- **Grill skill rewritten as interactive Q&A** — Each step proposes analysis and asks clarifying questions. Mermaid diagrams for architecture boundaries and failure flows. Plan mode enforced via `EnterPlanMode` (#69)
- **Grill error-state interrogation** — Step 6 (Risks) now requires partial-state, rollback, and recovery analysis. Eval improved from 20% → 70% (#64)
- **Grill scope enumeration** — New step 9 requires full blast radius search before implementation. Swarm decision moved to step 10 (#76)
- **Two-phase orchestrator delegation** — Fixes agent lifecycle bug where orchestrator terminated after plan presentation. Phase 1 returns plan, parent handles approval, Phase 2+ executes (#69)
- **Non-interactive git operations** — Replaced `git rebase -i` with `--autosquash` and `reset --soft` in finish and merge skills
- **Stop hook improved** — Recognizes orchestration/review sessions as non-code and passes them through
- **Security model: 7 layers → 6** — removed Layer 3 (PermissionRequest hook / LLM-as-judge). Remaining layers renumbered. Whitepaper, `/pds:sandbox`, and `/pds:audit-config` updated.
- **install.sh** — `autoMode` arrays deep-merged instead of overwritten. Project-level installs (`--project`) skip `autoMode` since the classifier reads user/local settings only. Cleanup now removes stale `autoMode` from project settings.
- **Force push via permission prompt** — Force push (`--force`, `--force-with-lease`) moved from unconditional deny to normal permission flow. User is prompted in interactive modes; classifier evaluates in auto mode. Protected branch pushes remain unconditionally blocked.

### Fixed
- **pr-review `{owner}/{repo}` placeholders** — Now resolves dynamically via `gh repo view`
- **Stale grill step references** — Updated "step 9" → "step 10" in swarm, team, and teams docs
- **Gate script jq dependency** — PR and teardown gates now check for jq availability, fail open gracefully

### Removed
- **`autoMode.soft_deny`** — removed from PDS config. Claude Code's built-in defaults apply unmodified. PDS static deny rules cover the critical cases.
- **PermissionRequest hook** — removed from `hooks/hooks.json`. Its deny patterns were 100% duplicated by static deny rules. Auto mode classifier replaces its dynamic evaluation with broader context.

### Deprecated
- **`/pds:permission-router` skill** — marked deprecated (not deleted). Redirects to `/pds:sandbox` for current security model.

### Eval Results
- Grill eval (N=10, sonnet/sonnet): 60% overall [46%-72%]
- Error-state scenario: 20% → 70% (target ≥60% met)
- Core refactor scenario: 100% [72%-99%]
- Manual baselines documented for bugfix, verify, finish (#65, #66, #67)

## [4.5.1] - 2026-03-23

### Fixed
- **Stop hook false positives** — Hook now detects session type and only verifies completion for implementation sessions. Q&A, planning, config, and doc-only sessions pass through cleanly.

### Added
- **Personal workflow rules in CLAUDE.md** — General Rules, Frontend/CSS, Development Workflow, and Troubleshooting sections for cross-project preferences.

## [4.5.0] - 2026-03-22

### Added
- **Swarm tiers (lite/med/heavy)** — Three cost/capability levels controlling model selection and specialist inclusion per swarm. Lite uses haiku workers for routine tasks (~10-20x cheaper). Med matches current defaults. Heavy uses opus for reasoning-heavy roles with full specialist roster.
- **Grill tier recommendation** — `/pds:grill` step 9 now recommends a tier alongside the swarm/no-swarm decision, with criteria for each tier based on problem complexity
- **Tier override syntax** — `/pds:swarm lite`, `/pds:swarm med`, `/pds:swarm heavy` to force a specific tier; without argument, tier auto-selected via grill
- **Tier state file** — `.claude/swarm/tier` tracks the active tier alongside `.claude/swarm/phase`
- **Grill eval scenarios** — Tier selection test cases in `skills/grill/EVAL.md` (routine task → lite, complex refactor → heavy)
- **Automated eval runner** — `scripts/run-eval.sh` runs EVAL.md scenarios N times via `claude -p`, grades with LLM-as-judge, reports pass rates with Wilson score 95% confidence intervals
- **Eval Makefile target** — `make eval SKILL=grill RUNS=10` for statistical skill testing
- **Whitepaper testing bibliography** — 3 new citations: Anthropic "Demystifying Evals" [8], AgentAssay probabilistic regression [9], Agent-as-a-Judge [10]
- **Eval calibration citations** — Shankar "Who Validates the Validators" [11] on criteria drift, Husain "Your AI Product Needs Evals" [12] on observation-first criteria

### Changed
- **Grill tier criteria sharpened** — Boundaries based on module/boundary count instead of file count; heavy tier defined by core abstraction refactors and new interfaces, not subjective "new patterns"
- **Grill eval scenarios recalibrated** — Replaced ambiguous scenarios with clear boundary-crossing setups; test reasoning quality not predetermined tier answers (per Anthropic guidance: "grade what the agent produced, not the path it took")
- **Eval baseline recorded** — `.claude/eval-results.md` with v4.5.0 definitive baseline: 80% overall [70%-87%] (sonnet execution + grading, N=20). Three scenarios at 100%, one real gap at 20% (#64)
- **Eval "closing the loop" workflow** — `/pds:eval` skill documents how to diagnose failures, compare against baseline, and act on results
- **Eval grader default changed** — Sonnet grading instead of haiku. Haiku produced false positives (80% → actual 20%) and false negatives (60% → actual 100%) when grading sonnet output
- **Swarm delegation** — Orchestrator spawn now includes `model` override for lite tier (sonnet instead of opus) and tier in prompt
- **Swarm Phase 1** — Tier initialization; grill mandatory before dispatch; researcher skipped at lite tier
- **Swarm Phase 3** — Tier-aware dispatch with per-agent model overrides via `model` parameter
- **Swarm Phase 5** — Lite tier: orchestrator self-reviews (no reviewer spawn); med/heavy: reviewer spawned with tier model
- **Swarm Phase 6** — Heavy tier: auditor spawned alongside scout; scout model upgraded to sonnet at heavy tier
- **Team skill** — New "Swarm Tiers" reference table with model mapping per tier
- **Whitepaper bibliography** — New Appendix C: References with 7 cited sources including Anthropic multi-agent research, Vercel agent evals, Fowler context engineering; inline citations [N] throughout
- **Whitepaper** — Tier system in Phase 1 description, Cost Considerations section, and Glossary
- **Team setup docs** — Tier table added to Agent Teams section

## [4.4.1] - 2026-03-10T17:57:25-04:00

### Fixed
- Remove `disable-model-invocation` from bcp, bump, finish, merge skills — all are procedural workflows that should be invocable via the Skill tool
- Add delegation preamble to swarm skill — main conversation now spawns an orchestrator instead of trying to execute TeamCreate/Task(worker) directly
- Add `.agent/` to `.gitignore` and install script to prevent stale legacy files from being recommitted (#60)

## [4.4.0] - 2026-03-10

### Added
- **Phase state machine** — `.claude/swarm/phase` tracks forward-only phase transitions (plan → decompose → dispatch → validate → consolidate → knowledge); enforced by PR and teardown gates as defense-in-depth alongside artifact checks
- **Team coordination tools in agent frontmatter** — all 8 agents now declare the Claude Code team tools they need (TeamCreate, TaskCreate, TaskUpdate, TaskList, TaskGet, TaskStop, SendMessage) in their `tools:` field
- **Self-service task claiming (pull model)** — workers check `TaskList` after completing tasks and self-claim next unblocked task (prefer lowest ID), reducing orchestrator bottleneck
- **Phase validation in gate scripts** — `orchestrator-pr-gate.sh` and `orchestrator-teardown-gate.sh` now validate phase state, empty phase files, and unrecognized phase names with clear error messages

### Changed
- **Trimmed ~70 lines of native Claude Code restatements** — removed Coordination Protocols section (shutdown, plan approval, team discovery, idle state, messaging) from `/team`, removed Plan Approval/Shutdown Protocol/Idle State/Swarm Tools sections from orchestrator agent, removed Monitoring section and per-phase `echo` commands from `/swarm`. Claude Code's built-in tool documentation covers these natively.
- **Team skill** — replaced tool tables and coordination protocols with concise PDS-specific patterns (pull model, artifact delivery, task discovery, blocker escalation); removed "New Agent Capabilities" section (now standard features)
- **Whitepaper** — added phase state machine to SDLC model and defense-in-depth layer 4; Phase 3 documents pull model for task claiming; fixed `delegate` → `default` permission mode
- **README** — fixed orchestrator mode from `delegate` to `default`

## [4.3.0] - 2026-03-09

### Added
- **`/pds:bcp` skill** — single exit path for shipping: bump version, commit, push, create PR. `/finish` handles preparation, `/bcp` handles delivery.
- **Native worktree isolation** — worker agent declares `isolation: worktree` in frontmatter; Claude Code (2.1.50) provisions worktrees automatically, replacing manual setup
- **Typed agent spawning** — swarm uses `Task(agent_type)` syntax throughout (e.g., `Task(worker)`, `Task(validator)`) to enforce spawn restrictions
- **WorktreeCreate hook** — logs worktree provisioning events to `.claude/swarm/worktree-events.log` for lifecycle auditing
- **InstructionsLoaded hook** — logs rule file loading to `.claude/swarm/audit.log` for compliance auditing
- **Pytest support in TaskCompleted gate** — detects `pytest.ini`, `conftest.py`, or `pyproject.toml` pytest config; resolves pytest binary automatically

### Changed
- **Orchestrator phases** — reviewer moved from Phase 4 (Validate) to Phase 5 (Consolidate), matching the SDLC phase model
- **TeammateIdle gate** — now catches both staged and unstaged uncommitted changes (was staged-only)
- **Scout write constraint** — added `.claude/eval-results.md` to allowed write paths (needed for eval execution)
- **Reviewer agent** — explicit SendMessage step to deliver review report to orchestrator
- **Worker agent** — explicit `/pds:verify` before declaring done; removed manual worktree instructions (now declarative)
- **`/finish` skill** — step 5 explicitly forwards bump type to `/bcp`; added "When to Use" comparison table
- **Whitepaper defense-in-depth** — "six" → "seven" enforcement mechanisms; layers 3/4/6 expanded with `agent_id`/`agent_type` in hooks, `WorktreeCreate`/`InstructionsLoaded` events, HTTP hooks, `Task(agent_type)` restrictions
- **Whitepaper Phase 3** — documents native `isolation: worktree` replacing manual worktree setup
- **Whitepaper Phase 5** — clarifies reviewer spawns after validation completes
- **Hook descriptions** — CLAUDE.md, README.md updated from "2 event types" to full list of 6+ hook events
- **Scout mode** — fixed stale `plan` → `acceptEdits` in README.md and docs/teams.md
- **Session-start tips** — added `/pds:bcp` and `/pds:finish` to key skills
- **Sandbox skill** — new Hook Events section documenting all lifecycle events; HTTP hooks noted
- **Team skill** — new Agent Capabilities section documenting `isolation: worktree`, `Task(agent_type)`, `agent_id`/`agent_type` in hooks

## [4.2.0] - 2026-03-04

### Added
- **SDLC phase gates** — Mechanical enforcement of phase transitions via PreToolUse hooks on the orchestrator agent:
  - `orchestrator-pr-gate.sh` — blocks `gh pr create` unless `.claude/swarm/validation-report.md` and `review-report.md` exist
  - `orchestrator-teardown-gate.sh` — blocks `TeamDelete` unless all 3 phase reports exist (validation, review, scout)
- **Swarm artifact directory** — `.claude/swarm/` stores phase artifacts (plan, contracts, validation/review/scout reports); added to `.gitignore`
- **Validator LLM evaluator** — prompt-based Stop hook replaces command-based `validator-stop-gate.sh`; evaluates report completeness semantically
- **Scout write access** — scout agent upgraded from `plan` to `acceptEdits` mode with Write tool; writes scoped to `.claude/swarm/scout-report.md` and `.claude/instincts.md`
- **Scout claude-mem integration** — scout can access cross-session memory via `smart_search`, `timeline`, `get_observations` MCP tools (graceful skip if unavailable)
- **Grill swarm decision** — `/pds:grill` step 9 evaluates swarm vs. no-swarm with explicit criteria and rationale
- **Phase gates reference table** — `/pds:swarm` documents all mechanical enforcement points and swarm artifact inventory
- **Skill evaluation framework** — new `/pds:eval` skill defines how to write, run, and report skill evals. Skills now have testable acceptance criteria via companion `EVAL.md` files.
- **EVAL.md files** — evaluation scenarios for `/verify`, `/grill`, `/bugfix`, and `/finish` skills. Each defines structured scenarios with expected behaviors, anti-patterns, and baseline comparisons.
- **Scout eval responsibilities** — scout agent now runs skill evals during Phase 6 (Knowledge), grading observed agent behavior against EVAL.md rubrics and recording results.

### Changed
- **Orchestrator dispatch** — Phase 3 now runs `mkdir -p .claude/swarm`; Phase 5 writes reviewer report to `.claude/swarm/review-report.md`
- **Validator process** — step 5 now writes report to `.claude/swarm/validation-report.md`
- **Scout process** — step 9 now writes report to `.claude/swarm/scout-report.md`
- **Swarm Phase 2** — contracts and plans written to `.claude/swarm/` instead of `.swarm/`
- **Team skill** — scout row updated (permissionMode: acceptEdits, scoped write access documented)
- **Whitepaper** — Phase 4/5/6 descriptions updated with artifact requirements; defense-in-depth model gains PreToolUse phase gates (layer 4); glossary adds Phase Gate and Swarm Artifacts entries
- **install.sh** — `install_project()` adds `.claude/swarm/` to `.gitignore`; `cleanup_project()` removes `.claude/swarm/`; test assertions updated for new hook scripts and orchestrator frontmatter
- **Scout agent** — added `pds:eval` to skills list, new eval step in process, `Evals` section in output format
- **Swarm Phase 6** — scout prompt now includes eval execution for exercised skills
- **Contribute checklist** — step 4 (cross-references) now includes `EVAL.md` maintenance when modifying skills

### Removed
- **`hooks/scripts/validator-stop-gate.sh`** — replaced by prompt-based LLM evaluator in validator agent frontmatter

## [4.1.0] - 2026-02-27

### Added
- **Quality gate hooks** — `Stop` (prompt), `TaskCompleted` (command), `TeammateIdle` (command) in `hooks/hooks.json` — programmatic enforcement replacing instruction-only quality gates (#49)
- **Default orchestrator agent** — `settings.json` at plugin root sets `{"agent": "orchestrator"}` so PDS-enabled sessions use the orchestrator persona by default (#50)
- **Agent frontmatter hooks** — `worker.md` gets `PostToolUse` hook (lint/format after Write|Edit), `validator.md` gets `Stop` hook (auto-converts to SubagentStop, enforces test pass before finishing) (#51)
- **SessionStart `additionalContext`** — `hooks/scripts/session-start.sh` injects PDS version, key skills, and worktree info into Claude's context; writes `PDS_VERSION` and `PDS_PLUGIN_ROOT` to `CLAUDE_ENV_FILE` (#52)
- **Spinner tips** — `spinnerTipsOverride` in PDS settings surfaces key skills (/pds:swarm, /pds:grill, /pds:verify, /pds:bugfix, /pds:team) during Claude's thinking spinner (#53)
- **PR attribution** — `attribution.pr` appends PDS credit line to pull request descriptions (#53)
- **Hook scripts** — `hooks/scripts/` directory with 5 executable scripts: `session-start.sh`, `task-completed-gate.sh`, `teammate-idle-gate.sh`, `post-write-check.sh`, `validator-stop-gate.sh`

### Changed
- **`cleanup_hooks()` expanded** — now removes `Stop`, `TaskCompleted`, `TeammateIdle` hook events plus `spinnerTipsOverride` and `attribution` keys from settings.json
- **`install_security_settings()` merge expanded** — now merges `spinnerTipsOverride` and `attribution` alongside `sandbox` and `permissions`
- **SessionStart hook** — replaced inline Linux dep-check command with `session-start.sh` script (dep check preserved inside script)
- **Skill namespace test** — fixed false positive when agent frontmatter has `hooks:` section after `skills:` (uses `sed` range instead of `grep -A`)

## [4.0.2] - 2026-02-27T15:22:28-05:00

### Fixed
- **`install_security_settings()` no longer overwrites user settings** — merges PDS security keys (`sandbox`, `permissions`) into existing `settings.json`, preserving user-specific config (`env`, `enabledPlugins`, custom keys)

## [4.0.1] - 2026-02-27

### Added
- **`cleanup_claude_md()`** — strips `<!-- PDS:START -->` / `<!-- PDS:END -->` markers from CLAUDE.md, restores `.pre-pds` backup if file was entirely PDS-managed (#45)
- **`cleanup_hooks()`** — surgically removes PDS-managed hooks (`SessionStart`, `PostToolUse`, `PermissionRequest`) from settings.json while preserving custom hooks (#46)
- **`--cleanup --user`** — new mode to remove user-level PDS artifacts (plugin, settings hooks, CLAUDE.md markers)
- **`--cleanup --all`** — removes both project and user-level PDS artifacts in one command
- **Cleanup tests** — 17 new test cases for CLAUDE.md stripping (4 scenarios) and hooks removal (3 scenarios)

### Fixed
- **BSD sed `1,/pattern/` range bug** — `install_claude_md()` marker replacement now uses explicit line numbers via `_pds_before()` / `_pds_after()` helpers, fixing silent data loss on macOS when PDS markers appear on line 1
- **Test brittleness** — agent/skill count assertions now use `> 0` instead of hardcoded values; marker test uses self-contained fixture instead of repo's CLAUDE.md

## [4.0.0] - 2026-02-25

### Added
- **Claude Code plugin architecture** — PDS is now a native plugin at `~/.claude/plugins/pds/`
  - `.claude-plugin/plugin.json` — plugin manifest with name, version, description
  - `agents/` — 8 agent definitions at plugin root (moved from `.claude/agents/`)
  - `skills/` — 16 skills in directory format (`skills/X/SKILL.md`, was `.claude/skills/X.md`)
  - `hooks/hooks.json` — SessionStart + PermissionRequest hooks (extracted from settings.json)
- **Skill namespace** — all skills now prefixed: `/pds:swarm`, `/pds:grill`, `/pds:verify`, etc.
- **`install.sh --plugin-dir`** — dev mode: symlinks local checkout as the plugin
- **`install.sh --project`** — project-level settings only (team overrides, no plugin copy)

### Changed
- **Default install mode** — installs plugin to `~/.claude/plugins/pds/` (was project-level `.claude/`)
- **Settings.json slimmed** — hooks extracted to plugin `hooks/hooks.json`; settings.json now contains only security config (sandbox, permissions, deny rules)
- **Agent skill references** — all 8 agents updated to `pds:` prefixed skills
- **Makefile** — `make install` now runs `./install.sh --plugin-dir .` for dev workflow

### Removed
- **`/test` skill** — 100% standard testing knowledge, zero behavioral delta over Claude's built-in capabilities
- **`/commit` skill** — conventional commit format folded into `/pds:finish` (pre-push rebase step, commit format section)
- **`/debug` skill** — "write hypothesis before investigating" folded into `/pds:grill` and `/pds:bugfix`
- **`/design` skill** — ADR convention folded into `/pds:contribute` as a 3-line note
- **`/quickref` skill** — agent roster already in `/pds:team`, skill table in CLAUDE.md
- **`/review` skill** — anti-sycophancy note folded into reviewer agent body, review integrity section in `/pds:finish`
- **`/merge-main` skill** — worktree-context check folded into `/pds:merge` "Merge to Main" section
- **`.claude/skills/` directory** — skills now live at plugin root `skills/`
- **`.claude/agents/` directory** — agents now live at plugin root `agents/`

### Migration
See `docs/migration-v4.md` for step-by-step migration from v3.x.

## [3.0.1] - 2026-02-25

### Fixed
- **SessionStart hook semver comparison** — no longer warns to "downgrade" when local version is ahead of published remote (uses `sort -V` for proper semver ordering)
- **Permission flow: removed `Bash(*)` from allow list** — was making the PermissionRequest hook unreachable for git/docker commands. Sandbox handles routine Bash via `autoAllowBashIfSandboxed`; git/docker now properly flow through the PermissionRequest hook
- **Removed PostToolUse test reminder hook** — fired on every Edit/Write creating noise; agents have `/test` and `/verify` skills instead

### Changed
- **`/swarm` rewritten** — each of the 6 phases now shows concrete tool calls (TeamCreate, TaskCreate, Task, SendMessage, TaskUpdate, TaskList) instead of one-sentence summaries. Self-contained enough to execute the full Agentic SDLC without reading other files
- **`/sandbox` adds Permission Flow section** — documents the full decision tree for how Bash commands flow through deny rules → sandbox → PermissionRequest hook
- **`/permission-router` updated** — reflects `Bash(*)` removal and documents why; the hook now actively gates git/docker commands
- **Orchestrator agent adds Swarm Tools section** — lists TeamCreate, TaskCreate, Task, SendMessage for quick reference

## [3.0.0] - 2026-02-20T11:04:15-05:00

### Added
- **Native OS-level sandbox** — Claude Code sandbox (Seatbelt on macOS, bubblewrap on Linux) enabled by default for all Bash commands
  - Filesystem writes confined to current working directory
  - Network restricted to allowlist: GitHub, npm, PyPI
  - `git` and `docker` excluded from sandbox (guarded by deny rules instead)
  - `autoAllowBashIfSandboxed: true` — sandboxed Bash runs without permission prompts
- **`/sandbox` skill** — documents the 6-layer security model, default configuration, customization guide, platform support, and troubleshooting
- **Sandbox sections in all 8 agents** — each agent documents how the sandbox interacts with its role
- **Linux dependency detection** — SessionStart hook and `install.sh` warn when `bwrap`/`socat` are missing on Linux
- **Sandbox audit section** — `/audit-config` gains Section 6 (10 bonus points) for sandbox verification, A+ grade for 100+

### Changed
- **`additionalDirectories: [".."]` removed** — parent directory write access no longer granted; sandbox confines writes to CWD, cross-worktree reads use absolute paths via Bash
- **Whitepaper updated** — "Agent Isolation" section rewritten with 6-layer defense-in-depth model; "Isolation Boundaries" section updated with sandbox as first boundary; Permission Tiers table gains "Sandbox" column
- **`/permission-router` updated** — documents sandbox interaction: `autoAllowBashIfSandboxed` bypasses the hook for sandboxed Bash, excluded commands and unsandboxed commands still go through the hook
- **`docs/teams.md` updated** — new "Sandbox" section, "What's Auto-Allowed" notes sandboxed Bash, `mcp__*` risk documented

## [2.9.0] - 2026-02-23T18:41:52-05:00

### Changed
- **Migrate worktree management to Claude Code native support** — remove ~225 lines of custom plumbing (REPO_ROOT resolution, `.worktrees/` convention, `.agent/` file protocol) in favor of native `isolation: "worktree"` and `--worktree` flag
- **Remove `/worktree` skill** — entirely replaced by native worktree management
- **Remove file protocol** (`.agent/task.md`, `status.md`, `output.md`) — agents now coordinate via TaskCreate/TaskUpdate for status and SendMessage for communication
- **Simplify CLAUDE.md rules** — worktree-specific rules consolidated into one native-delegation rule
- **Update all agent definitions** — orchestrator dispatch uses Task tool with worktree isolation; workers use TaskUpdate/SendMessage instead of .agent/ files
- **Update `/swarm` workflow** — phases 2-4 use TaskCreate/TaskList instead of manual worktree creation and file polling
- **Update `/merge` skill** — branch-name-based references replace REPO_ROOT path patterns
- **Remove `.agent/` from .gitignore and install.sh** — no longer needed

## [2.8.1] - 2026-02-19

### Changed
- CLAUDE.md: add Project Structure section, agent roster reference, copy-paste update command
- CLAUDE.md: consolidate 3 worktree rules into single Worktree Hygiene section
- CLAUDE.md: remove tmux operational config (not a dev principle)
- CLAUDE.md: 29% size reduction (5.2KB → 3.7KB)

## [2.8.0] - 2026-02-19T04:11:56-05:00

### Added
- `/verify` skill — completion self-check before declaring done
- `/finish` skill — branch completion protocol for merge readiness
- `/bugfix` skill — test-first bug fix loop with minimal blast radius

### Changed
- All 19 skill descriptions rewritten to Anthropic "what + when" trigger format
- `/merge-main` upgraded from ad-hoc note to proper skill with frontmatter and structure
- `/test` TDD section expanded with discipline guidance and test-first vs test-after comparison
- `/debug` adds investigation discipline paragraph
- `/review` adds review integrity section
- `/merge` heading formatting fixed (missing space after `##`)
- `/swarm` Phase 2 adds zone-based decomposition and contract-first guidance
- `/quickref` updated with all missing skill entries
- `docs/whitepaper.md` updated with `/verify` in Phase 4 and `/finish` in Phase 5
- `.claude/.pds-version` synced (was 2.7.0, now matches VERSION)

