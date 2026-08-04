#!/bin/sh
# PDS — WorktreeCreate hook. Symlinks settings.local.json from repo root into
# the new worktree's .claude/, then reports the worktree path.
#
# Per Claude Code's documented WorktreeCreate contract, a command hook must
# print the worktree path to stdout on exit 0 — Claude Code reads this as the
# worktree's location, not just a notification that one was created. This
# hook previously exited silently on every path (no stdout), which satisfies
# no output at all — the exact shape of the "hook succeeded but returned no
# worktree path" failure reported in #170. Fixed by printing $WT_ROOT (the
# CWD Claude Code already switched into before firing this hook) on every
# code path that represents a genuine worktree context, not just the ones
# that also do symlink work.
#
# Safe to run from main repo (no-op, no path printed) or any worktree.

set -e

# Detect if we're inside a worktree — if not, this isn't a real
# WorktreeCreate firing; stay silent and exit clean.
GIT_DIR=$(git rev-parse --git-dir 2>/dev/null) || exit 0
echo "$GIT_DIR" | grep -q "worktrees" || exit 0

# From here on we're genuinely inside a worktree — report the path
# regardless of which branch below actually runs.
WT_ROOT="$(pwd)"
echo "$WT_ROOT"

# Resolve repo root (works from both main repo and worktrees)
REPO_ROOT="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | sed 's|/.git$||')"

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
