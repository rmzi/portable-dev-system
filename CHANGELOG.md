# Changelog

All notable changes to this project will be documented in this file.

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
