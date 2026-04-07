#!/bin/sh
# PDS — Symlink settings.local.json from repo root into worktree .claude/
# Ensures runtime permission approvals propagate across all worktrees.
# Safe to run from main repo (no-op) or any worktree.

set -e

# Detect if we're inside a worktree
GIT_DIR=$(git rev-parse --git-dir 2>/dev/null) || exit 0
echo "$GIT_DIR" | grep -q "worktrees" || exit 0

# Resolve repo root (works from both main repo and worktrees)
REPO_ROOT="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | sed 's|/.git$||')"
WT_ROOT="$(pwd)"

ROOT_LOCAL="$REPO_ROOT/.claude/settings.local.json"
WT_CLAUDE="$WT_ROOT/.claude"
WT_LOCAL="$WT_CLAUDE/settings.local.json"

# Nothing to link if root has no settings.local.json
[ -f "$ROOT_LOCAL" ] || exit 0

# Already a symlink pointing to the right place — done
if [ -L "$WT_LOCAL" ]; then
  LINK_TARGET=$(readlink "$WT_LOCAL" 2>/dev/null || true)
  [ "$LINK_TARGET" = "$ROOT_LOCAL" ] && exit 0
fi

# If worktree has its own regular file, back it up (shouldn't happen often)
if [ -f "$WT_LOCAL" ] && [ ! -L "$WT_LOCAL" ]; then
  mv "$WT_LOCAL" "$WT_LOCAL.bak"
fi

# Ensure .claude/ dir exists
mkdir -p "$WT_CLAUDE"

# Create symlink
ln -sf "$ROOT_LOCAL" "$WT_LOCAL"
