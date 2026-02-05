# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2026-02-05

### Added
- Branch-tone audio feedback on session switch via `wts`

### Fixed
- Tmux session names with dots now properly escaped
- Pane selection uses explicit `:0` window targeting for reliability

### Removed
- Dynamic terminal theming (branch-theme) - users manage their own themes

## [0.7.3] - 2026-02-05

### Added
- `/bump` skill for version and changelog updates

## [0.7.2] - 2026-02-04

### Fixed
- **Permissions bypass vulnerabilities** (reported by Cursor Bugbot):
  - Force push via `+` refspec (`git push origin +main`) now blocked
  - Protected branch push via refspec (`git push origin HEAD:main`) now blocked
  - Branch deletion via colon refspec (`git push origin :main`) now blocked
  - Credential paths via `$HOME` now blocked (was only blocking `~`)
  - AWS `--profile=prod` syntax now blocked (was only blocking `--profile prod`)
  - Added `sftp` to remote access deny list
  - Added write protection for credential files

## [0.7.1] - 2026-02-04

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

## [0.7.0] - 2026-02-04

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

## [0.6.1] - 2026-02-04

### Removed
- `/bootstrap` skill - redundant with `pds-init` and README quick start

## [0.6.0] - 2026-02-04

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

## [0.5.1] - 2026-02-04

### Added
- **lazygit** added to dependencies
- **Auto-update workflow** - Claude checks `.pds-version` at session start and updates if outdated
- **gi keybind** for yazi - opens lazygit (requires `~/.config/yazi/keymap.toml` config)
- **branch-tone-hook.sh** wrapper script for Claude Code stop hooks

### Fixed
- Branch-tone hook subshell issues in Claude Code

## [0.5.0] - 2026-02-04

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

## [0.4.0] - 2026-02-04

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

## [0.3.0] - 2026-02-04

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

## [0.2.0] - 2026-02-04

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

## [0.1.0] - 2026-01-27

### Added
- Initial release
- **Yazi integration** - `y` function to cd on exit
- **Worktree helpers** - `wt`, `wty`, `wta`, `wtl`, `wtr`
- **Zoxide integration** - smart cd
- Basic installer script
- Claude Code settings template
