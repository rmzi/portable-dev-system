#!/bin/bash
# =============================================================================
# Portable Dev System - Installer
# =============================================================================

set -e

REPO_URL="https://raw.githubusercontent.com/rmzi/portable-dev-system/main"
VERSION=$(curl -fsSL "$REPO_URL/VERSION" 2>/dev/null || echo "unknown")

echo "🚀 Installing Portable Dev System v$VERSION"
echo ""

# Detect shell config file
if [[ "$SHELL" == *"zsh"* ]]; then
  SHELL_RC="$HOME/.zshrc"
elif [[ "$SHELL" == *"bash"* ]]; then
  SHELL_RC="$HOME/.bashrc"
else
  echo "⚠️  Unsupported shell. Please manually add shell-helpers.sh to your config."
  exit 1
fi

# Check for required dependencies
echo "📦 Checking dependencies..."
MISSING=""
for cmd in fzf yazi git tmux starship; do
  if ! command -v $cmd &> /dev/null; then
    MISSING="$MISSING $cmd"
  fi
done

if [[ -n "$MISSING" ]]; then
  echo ""
  echo "⚠️  Missing required tools:$MISSING"
  echo ""
  echo "Install with:"
  echo "  brew install yazi zoxide fzf tmux starship ripgrep fd bat"
  echo ""
  read -p "Continue anyway? (y/n) " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

# -----------------------------------------------------------------------------
# Shell Helpers
# -----------------------------------------------------------------------------
INSTALL_DIR="$HOME/.pds"
HELPERS_FILE="$INSTALL_DIR/shell-helpers.sh"

echo ""
echo "📝 Installing shell helpers to $INSTALL_DIR..."

mkdir -p "$INSTALL_DIR"
curl -fsSL "$REPO_URL/shell-helpers.sh" > "$HELPERS_FILE"
echo "✅ shell-helpers.sh installed."

# Add source line to shell config (if not already present)
SOURCE_LINE="source \"$HELPERS_FILE\""
if grep -q ".pds/shell-helpers.sh" "$SHELL_RC" 2>/dev/null; then
  echo "✅ Source line already in $SHELL_RC. Skipping."
else
  # Backup shell rc first
  cp "$SHELL_RC" "${SHELL_RC}.pds-backup"
  echo "📦 Backed up $SHELL_RC to ${SHELL_RC}.pds-backup"
  echo "" >> "$SHELL_RC"
  echo "# Portable Dev System" >> "$SHELL_RC"
  echo "$SOURCE_LINE" >> "$SHELL_RC"
  echo "✅ Added source line to $SHELL_RC"
fi

# -----------------------------------------------------------------------------
# Tmux Config
# -----------------------------------------------------------------------------
echo ""
echo "📝 Installing tmux.conf..."

if [[ -f "$HOME/.tmux.conf" ]]; then
  if grep -q "Portable Dev System" "$HOME/.tmux.conf" 2>/dev/null; then
    echo "✅ tmux.conf already installed. Skipping."
  else
    echo "⚠️  Existing ~/.tmux.conf found. Backing up to ~/.tmux.conf.backup"
    cp "$HOME/.tmux.conf" "$HOME/.tmux.conf.backup"
    curl -fsSL "$REPO_URL/tmux.conf" > "$HOME/.tmux.conf"
    echo "✅ tmux.conf installed."
  fi
else
  curl -fsSL "$REPO_URL/tmux.conf" > "$HOME/.tmux.conf"
  echo "✅ tmux.conf installed."
fi

# -----------------------------------------------------------------------------
# Starship Config
# -----------------------------------------------------------------------------
echo ""
echo "📝 Installing starship.toml..."

mkdir -p "$HOME/.config"
if [[ -f "$HOME/.config/starship.toml" ]]; then
  if grep -q "Portable Dev System" "$HOME/.config/starship.toml" 2>/dev/null; then
    echo "✅ starship.toml already installed. Skipping."
  else
    echo "⚠️  Existing starship.toml found. Backing up to starship.toml.backup"
    cp "$HOME/.config/starship.toml" "$HOME/.config/starship.toml.backup"
    curl -fsSL "$REPO_URL/starship.toml" > "$HOME/.config/starship.toml"
    echo "✅ starship.toml installed."
  fi
else
  curl -fsSL "$REPO_URL/starship.toml" > "$HOME/.config/starship.toml"
  echo "✅ starship.toml installed."
fi

# -----------------------------------------------------------------------------
# Yazi Keymap
# -----------------------------------------------------------------------------
echo ""
echo "📝 Installing yazi keymap..."

mkdir -p "$HOME/.config/yazi"
if [[ -f "$HOME/.config/yazi/keymap.toml" ]]; then
  if grep -q "Portable Dev System" "$HOME/.config/yazi/keymap.toml" 2>/dev/null; then
    echo "✅ yazi keymap already installed. Skipping."
  else
    echo "⚠️  Existing yazi keymap found. Backing up to keymap.toml.backup"
    cp "$HOME/.config/yazi/keymap.toml" "$HOME/.config/yazi/keymap.toml.backup"
    curl -fsSL "$REPO_URL/yazi-keymap.toml" > "$HOME/.config/yazi/keymap.toml"
    echo "✅ yazi keymap installed."
  fi
else
  curl -fsSL "$REPO_URL/yazi-keymap.toml" > "$HOME/.config/yazi/keymap.toml"
  echo "✅ yazi keymap installed."
fi

# -----------------------------------------------------------------------------
# Claude Code Settings
# -----------------------------------------------------------------------------
echo ""
echo "📝 Installing Claude Code settings..."

mkdir -p "$HOME/.claude"
if [[ -f "$HOME/.claude/settings.json" ]]; then
  if grep -q "mcp__" "$HOME/.claude/settings.json" 2>/dev/null; then
    echo "✅ Claude settings already installed. Skipping."
  else
    echo "⚠️  Existing Claude settings found. Backing up to settings.json.backup"
    cp "$HOME/.claude/settings.json" "$HOME/.claude/settings.json.backup"
    curl -fsSL "$REPO_URL/.claude/settings.json" > "$HOME/.claude/settings.json"
    echo "✅ Claude settings installed."
  fi
else
  curl -fsSL "$REPO_URL/.claude/settings.json" > "$HOME/.claude/settings.json"
  echo "✅ Claude settings installed."
fi

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------
echo ""
echo "🎉 Done!"
echo ""
echo "Backups created (for pds-uninstall):"
[[ -f "${SHELL_RC}.pds-backup" ]] && echo "  ${SHELL_RC}.pds-backup"
[[ -f "$HOME/.tmux.conf.backup" ]] && echo "  ~/.tmux.conf.backup"
[[ -f "$HOME/.config/starship.toml.backup" ]] && echo "  ~/.config/starship.toml.backup"
[[ -f "$HOME/.claude/settings.json.backup" ]] && echo "  ~/.claude/settings.json.backup"
echo ""
echo "Next steps:"
echo "  1. Restart your terminal or run: source $SHELL_RC"
echo "  2. In any project, run: pds-init (installs Claude skills)"
echo "  3. Try the commands below!"
echo ""
echo "Commands:"
echo "  pds-init      - install Claude skills to current project"
echo "  pds-update    - update PDS skills to latest version"
echo "  pds-uninstall - remove PDS and restore backups"
echo "  wt            - fuzzy pick worktree and cd"
echo "  wty           - fuzzy pick worktree → tmux layout"
echo "  clauder       - resume Claude session for current dir"
echo ""
echo "Tmux prefix: Ctrl-a (not Ctrl-b)"
echo ""
echo "Full docs: https://github.com/rmzi/portable-dev-system"
