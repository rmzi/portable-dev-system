#!/bin/sh
# PDS — WorktreeCreate hook. Creates the agent's git worktree, symlinks
# settings.local.json into it, and prints the worktree path to stdout.
#
# CONTRACT (verified empirically against Claude Code 2.1.221, see #182):
#
#   Registering a WorktreeCreate hook REPLACES Claude Code's native worktree
#   creation. The hook is not a notification that a worktree was made — it is
#   the thing that makes it. Claude Code fires this hook with CWD set to the
#   MAIN REPO (no worktree exists yet), passes a JSON payload on stdin, and
#   reads the created worktree's absolute path from stdout on exit 0.
#
#   stdin payload:
#     {"session_id":"...","transcript_path":"...","cwd":"<main repo>",
#      "prompt_id":"...","agent_type":"pds:worker",
#      "hook_event_name":"WorktreeCreate","name":"agent-<id>"}
#
#   `name` is the worktree/branch name Claude Code expects. `cwd` is the repo
#   the agent was spawned from.
#
# HISTORY: #170 reported "hook succeeded but returned no worktree path" and
# was closed in v5.0.0 by printing `pwd`, on the assumption that Claude Code
# creates the worktree and chdirs into it before firing. It does not — CWD is
# the main repo, so the old guard (`git rev-parse --git-dir` must contain
# "worktrees") never matched, the script exited 0 silently, and every
# `pds:worker` spawn failed. That made the entire worker tier unspawnable and
# `/pds:swarm` unable to dispatch. Reopened and fixed properly here.
#
# Worktrees are created inside the repo at .worktrees/<name>, per the worktree
# hygiene rule in CLAUDE.md — never /tmp, never a ../ sibling.

set -e

PAYLOAD=$(cat 2>/dev/null || true)

# No payload means this isn't a real WorktreeCreate firing (e.g. someone ran
# the script by hand). Stay silent and exit clean.
[ -n "$PAYLOAD" ] || exit 0

read_field() {
  printf '%s' "$PAYLOAD" | python3 -c "
import json, sys
try:
    print(json.load(sys.stdin).get('$1', '') or '')
except Exception:
    print('')
" 2>/dev/null || printf ''
}

WT_NAME=$(read_field name)
SPAWN_CWD=$(read_field cwd)

[ -n "$WT_NAME" ] || exit 0
[ -n "$SPAWN_CWD" ] && cd "$SPAWN_CWD" 2>/dev/null || true

# Resolve the true repo root. --git-common-dir (not --show-toplevel) so this
# still resolves correctly if the spawning agent is itself inside a worktree.
REPO_ROOT="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | sed 's|/\.git$||')"

# Not a git repo — we cannot create a worktree. Exit non-zero so Claude Code
# reports a real failure rather than the confusing "returned no path" message.
if [ -z "$REPO_ROOT" ] || [ ! -d "$REPO_ROOT" ]; then
  echo "[PDS] WorktreeCreate: not a git repository (cwd=$SPAWN_CWD)" >&2
  exit 1
fi

WT_ROOT="$REPO_ROOT/.worktrees/$WT_NAME"

if [ ! -d "$WT_ROOT" ]; then
  mkdir -p "$REPO_ROOT/.worktrees"
  # Prefer a named branch so the agent's commits are addressable. Fall back to
  # a detached checkout if the branch name is already taken.
  if ! git -C "$REPO_ROOT" worktree add --quiet -b "$WT_NAME" "$WT_ROOT" HEAD 2>/dev/null; then
    if ! git -C "$REPO_ROOT" worktree add --quiet --detach "$WT_ROOT" HEAD 2>/dev/null; then
      echo "[PDS] WorktreeCreate: git worktree add failed for $WT_ROOT" >&2
      exit 1
    fi
  fi
fi

# --- Report the path. Must happen before any optional work below can exit. ---
echo "$WT_ROOT"

# --- Optional: mirror the repo's local permission overrides into the worktree.
# Best-effort only; never fail the spawn over a symlink.
ROOT_LOCAL="$REPO_ROOT/.claude/settings.local.json"
WT_CLAUDE="$WT_ROOT/.claude"
WT_LOCAL="$WT_CLAUDE/settings.local.json"

[ -f "$ROOT_LOCAL" ] || exit 0

if [ -L "$WT_LOCAL" ]; then
  LINK_TARGET=$(readlink "$WT_LOCAL" 2>/dev/null || true)
  [ "$LINK_TARGET" = "$ROOT_LOCAL" ] && exit 0
fi

if [ -f "$WT_LOCAL" ] && [ ! -L "$WT_LOCAL" ]; then
  mv "$WT_LOCAL" "$WT_LOCAL.bak" 2>/dev/null || true
fi

mkdir -p "$WT_CLAUDE" 2>/dev/null || exit 0
ln -sf "$ROOT_LOCAL" "$WT_LOCAL" 2>/dev/null || true

exit 0
