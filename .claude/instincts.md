# Instincts

Persistent engineering patterns observed during work. Lighter than skills — observations with context that accumulate confidence through validation.

## Format

```markdown
### [title]
- **Observed**: [YYYY-MM-DD]
- **Times seen**: [N]
- **Confidence**: low | medium | high
- **Context**: [where/when this was observed]
- **Pattern**: [what happens]
- **Action**: [what to do about it]
- **Status**: active | promoted | retired
```

## Lifecycle

1. **Capture**: Any agent or human records a pattern here
2. **Validate**: Scout reviews post-swarm, bumps count, adjusts confidence
3. **Promote**: At `high` confidence (3+ validations), scout proposes a new skill draft. Human approves.
4. **Retire**: If proven wrong or irrelevant, scout marks `retired`

## Instincts

### Context loss on agent spawn is the dominant waste category
- **Observed**: 2026-04-02
- **Times seen**: 1
- **Confidence**: low
- **Context**: Heavy swarm for whitepaper merge — orchestrator spawned workers that re-discovered plan/research/decisions from scratch
- **Pattern**: Workers spend first 2-3 turns reading files and rebuilding context the orchestrator already had. TPS "transport waste" — moving information between agents instead of creating value.
- **Action**: Write `.claude/swarm/context.md` before dispatching workers. Implemented in v4.8.0.
- **Status**: active

### Orchestrator idle time during worker execution is significant
- **Observed**: 2026-04-02
- **Times seen**: 1
- **Confidence**: low
- **Context**: Heavy swarm — orchestrator idle ~15 minutes while workers executed
- **Pattern**: Orchestrator creates plan, dispatches workers, then waits until validation. TPS "waiting waste" — a capable agent (opus) creating no value during the longest phase.
- **Action**: Use idle time for monitoring, pre-writing review criteria, preparing consolidation, or running headless background tasks.
- **Status**: active

### Squash before push to avoid force-push complications
- **Observed**: 2026-04-02
- **Times seen**: 1
- **Confidence**: low
- **Context**: Two sequential swarm commits on main needed squashing, requiring force-push-with-lease which triggered permission denials
- **Pattern**: Multiple swarm runs create sequential commits. Squashing after push requires force-push (risky). Squashing before push is clean.
- **Action**: When running multiple swarms targeting main, accumulate changes and commit once at the end.
- **Status**: active

### Source analysis of the host platform pays compound returns
- **Observed**: 2026-04-02
- **Times seen**: 1
- **Confidence**: low
- **Context**: Claude Code source analysis (692 lines) informed whitepaper v3.0, identified three-system disconnect, revealed 5 compaction modes, grounded efficiency measurement
- **Pattern**: Deep platform understanding enables architecture decisions based on actual behavior, not documented API surface. Findings compound — fork-subagent analysis, dual-dispatch, context protocol, efficiency framework.
- **Action**: Maintain `docs/claude-code-source-analysis.md` as a strategic asset. Update as Claude Code evolves.
- **Status**: active

### User-level telemetry is essential for methodology improvement
- **Observed**: 2026-04-02
- **Times seen**: 1
- **Confidence**: low
- **Context**: Project-level telemetry destroyed when worktrees cleaned up, losing worker agent measurement data
- **Pattern**: Without persistent telemetry, PDS cannot measure efficiency across sessions. Instinct system, scout reports, and efficiency charts depend on data that may not survive the session.
- **Action**: Dual-write to project-level AND `~/.claude/telemetry/sessions.jsonl`. Implemented in v4.8.0.
- **Status**: active

### plugin.json version must stay in sync with VERSION
- **Observed**: 2026-04-02
- **Times seen**: 1
- **Confidence**: low
- **Context**: After bumping VERSION to 4.8.0, marketplace still showed 4.6.2 because plugin.json was stale
- **Pattern**: The marketplace reads version from `.claude-plugin/plugin.json`, not from `VERSION`. Both files must be updated atomically during version bumps. `/pds:bump` updates VERSION but not plugin.json.
- **Action**: Fix `/pds:bump` skill to update both `VERSION` and `.claude-plugin/plugin.json` in the same step.
- **Status**: active

### Stale plugin caches and broken symlinks accumulate silently
- **Observed**: 2026-04-02
- **Times seen**: 1
- **Confidence**: low
- **Context**: Found old marketplace cache versions (4.5.0, 4.6.1), a stale temp git clone, and a broken branch-tone symlink in ~/.claude/plugins/
- **Pattern**: Plugin installs, marketplace updates, and dev symlinks leave artifacts behind. No cleanup runs automatically. Over time, the plugin directory accumulates stale versions, temp clones, and broken symlinks.
- **Action**: Add periodic plugin cache pruning to session start or a scheduled task.
- **Status**: active

### Portability contract violations land silently without structural invariants in install.sh
- **Observed**: 2026-04-20
- **Times seen**: 1
- **Confidence**: low
- **Context**: `crates/cg/` (Rust TUI requiring Rust toolchain + undeclared `codebase-memory-mcp` dependency) lived in PDS for weeks. `install.sh` never copied it to user installs — so it was inert to users — but it was also never flagged as a contract violation. Author's own machine did not have `cg` installed, confirming the dead-weight nature. Removed in 4.17.0; added `assert_not_dir "crates"` as regression guard.
- **Pattern**: PDS has a portability contract ("markdown + bash + python3 + jq, no compiled artifacts, no toolchains") but relies on human review to enforce it. A contribution that violates the contract but also doesn't wire itself into `install.sh` is especially easy to miss — no user-visible failure, nothing runs, nothing breaks, but the repo accumulates dead weight and an implicit signal that the contract is negotiable.
- **Action**: For every structural contract (portability, file layout, naming), add a `bash install.sh --test` assertion that enforces it. The contract in prose (`docs/philosophy.md`) is the "why"; the assertion in `install.sh` is the "enforcement." Prose alone is not enforcement. When introducing a new artifact class, ask: "What assertion would catch this being done wrong?"
- **Status**: active

### Filing an issue in a diverged fork beats pushing reconstructed history
- **Observed**: 2026-04-20
- **Times seen**: 1
- **Confidence**: low
- **Context**: During cg migration from PDS to federation, completed the work locally against `~/dev/tools/universe/` (4 commits, branch `feat/cg-receive`, authorship preserved via `git format-patch` → sed path-rewrite → `git am`). Then learned federation had diverged significantly from local universe (org migration). Rather than attempt to rebase or reconcile, filed issue amok-labs/federation#89 with reproducible patch-generation commands and discarded the local branch. No conflict fighting, no force-pushes, no lost work — source commits live in PDS and patches are regeneratable on demand.
- **Pattern**: When a code-move target repo has diverged from the source you're working against, the cost of replicating the work as a PR (rebase, conflict resolution, testing in the new environment) can exceed the cost of documenting the work as an issue that someone familiar with the diverged target can execute. This especially holds when the source repo retains the original commits (so regenerating patches is trivial) and the work is small enough to describe precisely.
- **Action**: Before attempting a cross-repo migration push, check divergence with `git fetch && git log HEAD..target/main --oneline | wc -l`. If divergence is non-trivial and the source commits are still reachable in their origin repo, write an issue with: (1) the goal, (2) the source commit SHAs, (3) a reproducible patch-generation block (`git format-patch` + sed + `git am`), (4) acceptance criteria. Discard local reconstruction work rather than fight the merge.
- **Status**: active

### Install scripts that auto-install optional tools expand the dependency surface invisibly
- **Observed**: 2026-04-20
- **Times seen**: 2
- **Confidence**: medium
- **Context**: While auditing PDS's portability story, found two `check_X` functions in `install.sh` (`check_gitleaks`, `check_age`) that on missing-tool path attempted `brew install X` (macOS) or `go install X@latest` (Linux), with soft `warn` fallback. Neither tool is required by PDS runtime — `secret-scrub.sh` and `mcp-secret-scrub.sh` are regex-only with zero gitleaks references, and `age` is only used for opt-in telemetry encryption. Both functions had been in `install.sh` for many versions without anyone questioning the implicit Homebrew/Go dependency they introduced. Removed `check_gitleaks` in 4.17.1; left `check_age` for separate user decision.
- **Pattern**: An install script that auto-installs "recommended" tools via package managers silently widens the dependency surface beyond what the project's stated contract advertises. The failure mode is asymmetric: if the user already has the tool, nothing is logged; if the user lacks it AND lacks the package manager, a warn fires but install continues — so the cost is invisible in normal operation. Distinct from instinct "Portability contract violations land silently without structural invariants in install.sh" — that one is about source artifacts (a Rust crate in the tree); this one is about install-script *behavior* (a function that calls brew/go for the user).
- **Action**: At every install.sh review and at every new "optional tool integration" proposal, audit for `command -v X || (brew install X | go install X)` patterns. The portability rule: PDS uses tool X if present; PDS does not install tool X. Users who want tool X install it themselves through their preferred method. Document optional tools in README under "Optional integrations" with install hints, but never invoke a package manager from `install.sh`.
- **Status**: active

### Mirror, don't invent
- **Observed**: 2026-04-20
- **Times seen**: 3
- **Confidence**: medium
- **Context**: Triaged from `/insights` 2026-04-20 (issue #149) — three independent sessions (courted-dbx MLS providers, federation branch-tone x2) where Claude invented a new pattern (test scaffolding, PR workflow, provider grouping) instead of mirroring an existing one already present in the repo, requiring the user to redirect each time.
- **Pattern**: When a codebase already has a pattern for something, Claude often invents a new one anyway — missing nearby examples, creating abstractions that don't match the repo's shape. This applies to test style, config files, migration scripts, provider/handler registrations, CLI subcommands, hook scripts, notebook cells.
- **Action**: Before writing new code for something that plausibly already exists in this repo: (1) grep for 2-3 existing examples of the nearest pattern (similar file shape, similar goal), (2) show the user the examples found and what's planned to mirror, (3) change only what must change to fit the new case — don't introduce a new abstraction unless the existing pattern demonstrably cannot express the new case, and in that situation propose the abstraction explicitly before writing it.
- **Status**: active
