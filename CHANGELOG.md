# Changelog

All notable changes to this project will be documented in this file.

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
