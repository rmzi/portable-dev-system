# Changelog

All notable changes to this project will be documented in this file.

## [2.1.0] - 2026-02-12T03:15:43-05:00

### Added
- Terminal feedback loop: `tmux capture-pane` rule for reading terminal state after sending denied commands
- Rewrite `/quickref` as PDS-native skill reference (was Zaku cheatsheet)

### Changed
- Remove `/eod` skill (depends on Zaku `wtc` helper)
- Rewrite `/worktree` skill with raw git commands, add Cleanup section
- Standardize all worktree paths to `.worktrees/` convention across skills and agents
- Update `/swarm` description from "Tmux-native" to "file-based coordination"
- Revert skill scan instruction to `Scan .claude/skills/` (inclusive of subdirectory layouts)

### Removed
- All references to Zaku shell aliases (`wt`, `wtr`, `wtc`) from `.claude/`
- All `../project-*` sibling-format worktree paths from `.claude/`

## [2.0.0] - 2026-02-11

PDS is now **"Software for Claude"** — a pure Claude Code configuration package. Tool-layer files (shell helpers, tmux, terminal configs) have moved to [Zaku](https://github.com/rmzi/zaku).

### Added
- **Agent team system** — 8 specialized agents for multi-agent orchestration:
  - **orchestrator** (opus, delegate) — team lead, 6-phase Agentic SDLC coordinator
  - **researcher** (sonnet, plan) — read-only codebase exploration
  - **worker** (sonnet, acceptEdits) — implementation in isolated worktrees
  - **validator** (sonnet, acceptEdits) — merge branches, run tests, produce reports
  - **reviewer** (sonnet, plan) — code review with severity categories
  - **documenter** (sonnet, acceptEdits) — documentation updates
  - **scout** (haiku, plan) — PDS meta-improvement suggestions
  - **auditor** (sonnet, plan) — codebase quality analysis → GitHub issues
- **Agent frontmatter** — `name`, `description`, `model`, `permissionMode`, `maxTurns`, `memory`, `tools`, `skills`, `color` for all agents
- **File-based agent coordination** — `.agent/task.md`, `status.md`, `output.md` protocol
- **`/team` skill** — agent roster, permissions, file protocol reference
- **`/swarm` skill** — multi-agent workflow with file-based coordination
- **Agentic SDLC documentation** — whitepaper, proposal, agent tooling patterns (from agent-sandbox)
- **Permission hardening** — `additionalDirectories` for worktree access, hooks in `settings.json`
- **Agent memory** — `memory: project` for researcher, reviewer, scout, auditor

### Changed
- **Scoped to configuration only** — PDS is editor-agnostic, no tool dependencies
- **Orchestrator uses `delegate` mode** — cannot implement directly, must dispatch agents
- **Read-only agents use `plan` mode** — researcher, reviewer, scout, auditor cannot modify files

### Removed
- `shell-helpers.sh` — moved to Zaku
- `tmux.conf` — moved to Zaku
- `starship.toml` — moved to Zaku
- `install.sh` — moved to Zaku
- `ghostty.config` — moved to Zaku
- `claude-statusline.sh` — moved to Zaku
- `yazi-keymap.toml`, `yazi-theme.toml` — moved to Zaku
- `docs/commands.md`, `docs/install.md` — moved to Zaku
- `.claude/hooks.json` — hooks moved into `settings.json` (dead file, Claude Code doesn't read standalone hooks)

## [1.2.1] - 2026-02-11

### Added
- **Window title for Mission Control** — tmux sets the terminal window title to `repo / branch`, making each session identifiable in macOS Mission Control and app switchers

## [1.2.0] - 2026-02-10T00:00:00-05:00

### Added
- **PermissionRequest prompt hook** — subagent permission requests auto-resolved via built-in LLM-as-judge hook in `settings.json` (no external API key needed)
- **`/permission-router` skill** — documents the prompt hook policy and configuration
- **`pds-machine` command** — first-class command for updating system shell helpers (replaces `pds-update -s`)

### Fixed
- **branch-tone repo detection** — use `git rev-parse --git-common-dir` instead of `--show-toplevel` so worktrees of the same repo produce consistent tones and different repos on the same branch sound distinct

## [1.1.0] - 2026-02-10T00:00:00-05:00

### Added
- **Contained worktrees** — `wt` now creates worktrees inside `project/.worktrees/` instead of sibling directories, reducing clutter in `~/dev/`
- **`wtc --all` end-of-day cleanup** — scan all repos, surface outstanding work, interactive resolution menu, batch remove merged worktrees
- **`/eod` skill** — documents the end-of-day cleanup workflow and configuration
- **Sibling worktree migration** — `wtc` and `wtc --all` detect old `../project-branch/` format and offer `git worktree move` migration
- **Auto `.gitignore`** — `.worktrees/` automatically added to `.gitignore` on first worktree creation and during `pds-init`
- **Configurable scan dirs** — `~/.pds/eod.conf` with `SCAN_DIRS` for cross-repo discovery

### Removed
- **`clauder` alias** — `claude --continue` is easy enough to type directly

### Changed
- **Worktree path convention** — from `../project-branch/` (sibling) to `project/.worktrees/branch/` (contained)
- **tmux session naming** — derives repo name from main worktree via `git worktree list` instead of `git rev-parse --show-toplevel` (fixes naming inside `.worktrees/`)
- **`wtc` refactored** — cleanup logic extracted into `__pds_repo_cleanup` for reuse by `wtc --all`

## [1.0.1] - 2026-02-09T00:00:00-05:00

### Added
- **Lazygit pane** in tmux layout — full-width bottom pane (30% of total height)
- **remain-on-exit** — accidentally closed panes stay visible instead of breaking the layout
- **`Ctrl-a R` keybinding** — respawn a dead pane with its original command
- **`wtc` command** — clean up stale worktrees and orphaned tmux sessions

### Changed
- **Consolidated `wt` and `wty`** into single `wt` command (`wt`, `wt branch`, `wt -b branch`)
- **`wtr` is now directory-aware** — removes the current worktree instead of fuzzy picking

### Removed
- **`wty`** — merged into `wt`
- **`wta`** — `wt` and `wt -b` cover the same functionality with tmux
- **`wtl`** — `wt` with no args shows all worktrees via fuzzy picker
- **`ts`, `tsk`, `twt`, `tl`, `td`** — unused tmux session helpers (`wts` covers session management)

## [1.0.0] - 2026-02-05T00:00:00-05:00

**Stable release.** Terminal-first, AI-assisted development with worktrees and skills.

### Highlights
- Tmux layouts for isolated worktree sessions (Claude + terminal + yazi)
- Skills system for consistent team workflows
- Velocity-focused permissions with security guardrails
- Optional audio feedback via branch-tone addon

### Added
- Branch-tone audio feedback on session switch via `wts`

### Fixed
- Tmux session names with dots now properly escaped
- Pane selection uses explicit `:0` window targeting for reliability

### Removed
- Dynamic terminal theming - users manage their own themes

## [0.7.3] - 2026-02-05T00:00:00-05:00

### Added
- `/bump` skill for version and changelog updates

## [0.7.2] - 2026-02-04T00:00:00-05:00

### Fixed
- **Permissions bypass vulnerabilities** (reported by Cursor Bugbot):
  - Force push via `+` refspec (`git push origin +main`) now blocked
  - Protected branch push via refspec (`git push origin HEAD:main`) now blocked
  - Branch deletion via colon refspec (`git push origin :main`) now blocked
  - Credential paths via `$HOME` now blocked (was only blocking `~`)
  - AWS `--profile=prod` syntax now blocked (was only blocking `--profile prod`)
  - Added `sftp` to remote access deny list
  - Added write protection for credential files

## [0.7.1] - 2026-02-04T00:00:00-05:00

### Added
- **Permissive permissions model** - velocity-focused settings.json:
  - Auto-allow: all tools, bash, MCP, web fetches
  - Block: credential paths (~/.aws, ~/.ssh, etc.)
  - Block: git push to main/master/dev/develop
  - Block: force push, ssh/scp to remote hosts
  - Block: prod-related patterns (PROD, prod.*, --profile prod)
- **User-level Claude settings** - `install.sh` now installs `~/.claude/settings.json` as default for all projects
- **`wtr` kills tmux session** - removing a worktree also kills its associated tmux session
- **Permissions documentation** in docs/teams.md

## [0.7.0] - 2026-02-04T00:00:00-05:00

### Added
- **`wts` command** - global session picker, jump to any tmux session from anywhere
- **Timestamp in prompt** - see when each command was run (`HH:MM:SS`)
- **Modern theming** with color palettes:
  - tmux: `%hidden` color variables, true color RGB support
  - Starship: `palette` feature for consistent colors
  - Yazi: full v26.x theme format with all sections
- **Rules in CLAUDE.md**:
  - Never clone repos (use worktrees instead)
  - Never use /tmp for code or worktrees

### Changed
- **`wt` now opens tmux layout** - same behavior as `wty` (claude + terminal + yazi)
- **Visual distinction** between tools:
  - Terminal/tmux: GREEN accent
  - Yazi: BLUE accent
- **Yazi pane size** - now 70% of right column (was 50%)

### Fixed
- `wty -b` / `wta -b` argument order for `git worktree add`
- Yazi theme format for v26.x (was using deprecated section names)
- macOS compatibility for `wts` (removed `head -n -1`)

## [0.6.1] - 2026-02-04T00:00:00-05:00

### Removed
- `/bootstrap` skill - redundant with `pds-init` and README quick start

## [0.6.0] - 2026-02-04T00:00:00-05:00

### Added
- **Yazi keymap** now installed by default with PDS keybinds:
  - `gi` - open lazygit
  - `gw` - fuzzy pick worktree
  - `gh/gd/gc` - go to home/dev/config
- **pds-addon** command for optional addons:
  - `pds-addon branch-tone install` - install audio feedback
  - `pds-addon branch-tone update` - update to latest
  - `pds-addon branch-tone remove` - uninstall

### Changed
- Installer now backs up and installs yazi keymap.toml

## [0.5.1] - 2026-02-04T00:00:00-05:00

### Added
- **lazygit** added to dependencies
- **Auto-update workflow** - Claude checks `.pds-version` at session start and updates if outdated
- **gi keybind** for yazi - opens lazygit (requires `~/.config/yazi/keymap.toml` config)
- **branch-tone-hook.sh** wrapper script for Claude Code stop hooks

### Fixed
- Branch-tone hook subshell issues in Claude Code

## [0.5.0] - 2026-02-04T00:00:00-05:00

### Added
- **Optional branch-tone integration** - terminal bell plays branch-specific sound
- **Skills catalog** (`docs/skills.md`) - descriptions and usage for all skills

### Removed
- **wtyg command** - use `wty` instead (no backwards compat needed)

### Changed
- **wty navigates to existing worktree** if branch is already checked out

### Fixed
- **Nested tmux sessions** - wty uses `switch-client` when inside tmux, `attach` when outside
- **Pane targeting** - explicit pane selection for reliable split layout
- **branch-tone repo detection** - works correctly in worktree directories
- **branch-tone subshell** - runs in background without blocking

## [0.4.0] - 2026-02-04T00:00:00-05:00

### Added
- **pds-update** - update PDS to latest version
  - `pds-update` updates project skills (`.claude/skills/*.md`)
  - `pds-update -s` updates system shell helpers (`~/.pds`)
  - Version tracking via `.claude/.pds-version`
- **MECE principle** added to `/ethos` skill
- **Mandatory skill consultation** section in CLAUDE.md template
- **docs/** directory with focused documentation:
  - `install.md` - installation, updating, uninstalling
  - `commands.md` - full command reference
  - `teams.md` - team setup guide
  - `philosophy.md` - principles

### Changed
- **README restructured** - short and focused, links to docs/ for details
- **wty/wtyg** start fresh Claude sessions (use `clauder` to resume)
- **wta/wty/wtyg -b** falls back to existing branch if it already exists
- Improved collision handling merge prompt

### Fixed
- Branch already exists error when using `-b` flag

## [0.3.0] - 2026-02-04T00:00:00-05:00

### Added
- **pds-init** - install Claude skills to any project from the repo
  - Network connectivity check before downloading
  - Collision detection: existing `.claude/` or `CLAUDE.md` triggers merge flow
  - Places PDS files in `.pds-incoming/` with instructions to ask Claude to merge
  - Error tracking and retry guidance for failed downloads
- **pds-uninstall** - fully remove PDS and restore backups
  - Restores shell rc from backup (or removes lines manually)
  - Offers to restore tmux.conf and starship.toml
  - Leaves project-level files untouched
- Shell rc backup before modification (`~/.zshrc.pds-backup`)
- Version display in installer
- Backup summary shown after install

### Changed
- Install location: `~/.config/portable-dev-system` → `~/.pds` (shorter path)
- Updated README with "What the Installer Does" and "Uninstall / Revert" sections
- Improved "For Teams" section with Quick Start guide
- `pds-init` downloads `hooks.json` (was missing in manual copy instructions)

## [0.2.0] - 2026-02-04T00:00:00-05:00

### Added
- **wty tmux layout** - opens worktree in tmux with claude (left), terminal (top-right), yazi (bottom-right)
- **Tmux session helpers** - `ts`, `tsk`, `twt`, `tl`, `td`
- **Git aliases** - `gst`, `gco`, `gcb`, `gp`, `gl`, `ga`, `gc`, `gd`, `gds`, `glog`
- **Fuzzy git helpers** - `gco-fzf`, `glog-fzf`, `gadd-fzf`, `gstash-fzf`
- **tmux.conf** - Ctrl-a prefix, vim navigation, mouse support, git branch in status bar
- **starship.toml** - folder name, git branch/status, command duration, error indicator
- **Claude hooks** - lint and test reminders on file changes
- **Claude permission presets** - allow common tools, deny secrets and dangerous commands
- Installer now handles tmux.conf and starship.toml with automatic backups

### Changed
- Installer checks for `tmux` and `starship` dependencies
- Improved installer output with command reference

## [0.1.0] - 2026-01-27T00:00:00-05:00

### Added
- Initial release
- **Yazi integration** - `y` function to cd on exit
- **Worktree helpers** - `wt`, `wty`, `wta`, `wtl`, `wtr`
- **Zoxide integration** - smart cd
- Basic installer script
- Claude Code settings template
