# Installation Guide

## What Gets Installed

### System-level files

| File | Action | Backup |
|------|--------|--------|
| `~/.pds/shell-helpers.sh` | Created | — |
| `~/.zshrc` (or `.bashrc`) | Appends 2 lines | `~/.zshrc.pds-backup` |
| `~/.tmux.conf` | Replaced | `~/.tmux.conf.backup` |
| `~/.config/starship.toml` | Replaced | `~/.config/starship.toml.backup` |

### Project-level files (via `pds-init`)

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Project context for Claude Code |
| `.claude/settings.json` | Claude Code settings |
| `.claude/hooks.json` | Pre-configured hooks |
| `.claude/skills/*.md` | Workflow skills |
| `.claude/.pds-version` | Version marker for updates |

---

## Collision Handling

If your project already has `CLAUDE.md` or `.claude/`, `pds-init` detects this and:

1. Places PDS files in `.pds-incoming/` instead of overwriting
2. Prompts you to ask Claude to merge them

**Example merge prompt:**
```
Merge the PDS skills from .pds-incoming/ with my existing .claude/ config.
Add the Skills System section from .pds-incoming/CLAUDE.md to my CLAUDE.md,
copy any new skills, and remove .pds-incoming/
```

---

## Updating

### Update project skills

```bash
cd ~/your-project
pds-update
```

Updates `.claude/skills/*.md` to latest version. Project-specific skills (in subdirectories) are untouched.

### Update system shell helpers

```bash
pds-update -s
source ~/.pds/shell-helpers.sh
```

### Version tracking

PDS tracks installed version in `.claude/.pds-version`. Run `pds-update` to check for updates.

---

## Uninstalling

### Full uninstall

```bash
pds-uninstall
```

Removes `~/.pds/`, restores shell rc from backup, offers to restore tmux/starship configs.

### Manual revert

| What | Command |
|------|---------|
| Shell helpers | `rm -rf ~/.pds && mv ~/.zshrc.pds-backup ~/.zshrc` |
| Tmux config | `mv ~/.tmux.conf.backup ~/.tmux.conf` |
| Starship config | `mv ~/.config/starship.toml.backup ~/.config/starship.toml` |
| Project skills | `rm -rf .claude CLAUDE.md` |

---

## Optional Configs

### Ghostty

```bash
mkdir -p ~/.config/ghostty && cp ghostty.config ~/.config/ghostty/config
```

| Action | macOS | Linux |
|--------|-------|-------|
| Split right | `Cmd+D` | `Ctrl+Shift+D` |
| Split down | `Cmd+Shift+D` | `Ctrl+Shift+S` |
| Navigate | `Alt+H/J/K/L` | `Alt+H/J/K/L` |
| Zoom | `Cmd+Shift+Z` | `Ctrl+Shift+Z` |
| Quick terminal | `` Cmd+` `` | `` Super+` `` |

**When to use Ghostty vs tmux:**
- **Ghostty**: Local dev, quick sessions, lighter weight
- **tmux**: Remote SSH, persistent sessions, detach/reattach

### Yazi Theme

For consistent file manager styling with blue accents:

```bash
mkdir -p ~/.config/yazi && cp yazi-theme.toml ~/.config/yazi/theme.toml
```

### Claude Status Line

For the red-accented Claude status line:

```bash
cp claude-statusline.sh ~/.pds/
chmod +x ~/.pds/claude-statusline.sh
```

Then update your `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.pds/claude-statusline.sh"
  }
}
```

---

## Visual Context Colors

PDS uses subtle RGB accents to distinguish contexts at a glance:

| Context | Color | Where |
|---------|-------|-------|
| Terminal/tmux | Green | Status bar accent |
| Yazi | Blue | Mode indicator, borders |
| Claude | Red | Status line marker |

Branch names are hashed to create subtle color variations within each family, so different branches have slightly different hues.
