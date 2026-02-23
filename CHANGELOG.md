# Changelog

All notable changes to this project will be documented in this file.

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

