#!/bin/bash
# =============================================================================
# Portable Dev System - Installer
# =============================================================================

set -e

REPO_URL="https://raw.githubusercontent.com/rmzi/portable-dev-system/main"

echo "🚀 Installing Portable Dev System..."
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
echo ""
echo "📝 Adding shell helpers to $SHELL_RC..."

if grep -q "Portable Dev System" "$SHELL_RC" 2>/dev/null; then
  echo "✅ Shell helpers already installed. Skipping."
else
  echo "" >> "$SHELL_RC"
  echo "# =============================================================================" >> "$SHELL_RC"
  echo "# Portable Dev System - Shell Helpers" >> "$SHELL_RC"
  echo "# https://github.com/rmzi/portable-dev-system" >> "$SHELL_RC"
  echo "# =============================================================================" >> "$SHELL_RC"
  curl -fsSL "$REPO_URL/shell-helpers.sh" >> "$SHELL_RC"
  echo "✅ Shell helpers added."
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
# Done
# -----------------------------------------------------------------------------
echo ""
echo "🎉 Done!"
echo ""
echo "Next steps:"
echo "  1. Restart your terminal or run: source $SHELL_RC"
echo "  2. Copy .claude/ to your projects for Claude Code settings"
echo "  3. Try the commands below!"
echo ""
echo "Commands:"
echo "  wt       - fuzzy pick worktree and cd"
echo "  wty      - fuzzy pick worktree → tmux (claude + terminal + yazi)"
echo "  ts       - list/attach tmux sessions"
echo "  twt      - tmux session for current directory"
echo "  gco-fzf  - fuzzy checkout git branch"
echo "  glog-fzf - fuzzy browse commits"
echo "  gadd-fzf - fuzzy stage files"
echo ""
echo "Tmux prefix is Ctrl-a (not Ctrl-b)"
echo ""
echo "Docs: https://github.com/rmzi/portable-dev-system"
