# Changelog

All notable changes to this project will be documented in this file.

## [4.2.0] - 2026-03-04

### Added
- **Skill evaluation framework** — new `/pds:eval` skill defines how to write, run, and report skill evals. Skills now have testable acceptance criteria via companion `EVAL.md` files.
- **EVAL.md files** — evaluation scenarios for `/verify`, `/grill`, `/bugfix`, and `/finish` skills. Each defines structured scenarios with expected behaviors, anti-patterns, and baseline comparisons.
- **Scout eval responsibilities** — scout agent now runs skill evals during Phase 6 (Knowledge), grading observed agent behavior against EVAL.md rubrics and recording results.

### Changed
- **Scout agent** — added `pds:eval` to skills list, new eval step in process, `Evals` section in output format
- **Swarm Phase 6** — scout prompt now includes eval execution for exercised skills
- **Contribute checklist** — step 4 (cross-references) now includes `EVAL.md` maintenance when modifying skills

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

