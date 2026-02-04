#!/bin/bash
# =============================================================================
# Portable Dev System - Installer
# =============================================================================

set -e

REPO_URL="https://raw.githubusercontent.com/rmzi/portable-dev-system/main"
SHELL_HELPERS_URL="$REPO_URL/shell-helpers.sh"

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
for cmd in fzf yazi git tmux; do
  if ! command -v $cmd &> /dev/null; then
    MISSING="$MISSING $cmd"
  fi
done

if [[ -n "$MISSING" ]]; then
  echo ""
  echo "⚠️  Missing required tools:$MISSING"
  echo ""
  echo "Install with:"
  echo "  brew install yazi zoxide fzf tmux ripgrep fd bat"
  echo ""
  read -p "Continue anyway? (y/n) " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

# Download and append shell helpers
echo ""
echo "📝 Adding shell helpers to $SHELL_RC..."

# Check if already installed
if grep -q "Portable Dev System" "$SHELL_RC" 2>/dev/null; then
  echo "✅ Shell helpers already installed. Skipping."
else
  echo "" >> "$SHELL_RC"
  echo "# =============================================================================" >> "$SHELL_RC"
  echo "# Portable Dev System - Shell Helpers" >> "$SHELL_RC"
  echo "# https://github.com/rmzi/portable-dev-system" >> "$SHELL_RC"
  echo "# =============================================================================" >> "$SHELL_RC"
  curl -fsSL "$SHELL_HELPERS_URL" >> "$SHELL_RC"
  echo "✅ Shell helpers added."
fi

echo ""
echo "🎉 Done!"
echo ""
echo "Next steps:"
echo "  1. Restart your terminal or run: source $SHELL_RC"
echo "  2. Copy .claude/ to your projects for Claude Code skills"
echo "  3. Try: wt, wty, y, ts, twt"
echo ""
echo "Commands:"
echo "  wt   - fuzzy pick worktree and cd"
echo "  wty  - fuzzy pick worktree and open tmux (claude + terminal + yazi)"
echo "  ts   - list/attach tmux sessions"
echo "  twt  - tmux session for current directory"
echo ""
echo "Docs: https://github.com/rmzi/portable-dev-system"
