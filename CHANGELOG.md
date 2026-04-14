# Changelog

All notable changes to this project will be documented in this file.

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

