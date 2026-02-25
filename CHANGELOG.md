# Changelog

All notable changes to this project will be documented in this file.

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

