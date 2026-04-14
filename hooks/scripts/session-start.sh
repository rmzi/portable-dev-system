#!/bin/bash
# PDS SessionStart hook — injects PDS context and sets env vars.
# Outputs JSON with additionalContext for Claude's context window.
# Writes PDS_VERSION and PDS_PLUGIN_ROOT to CLAUDE_ENV_FILE.

# --- Reset session health timer (prevents accumulation across sessions) ---
rm -f "${TMPDIR:-/tmp}/pds-session-start"

# --- Linux sandbox dependency check (preserved from inline hook) ---
if [ "$(uname)" = "Linux" ]; then
  for dep in bwrap socat; do
    command -v "$dep" >/dev/null 2>&1 || echo "Sandbox dep missing: $dep. Install: sudo apt install bubblewrap socat" >&2
  done
fi

# --- Resolve PDS version ---
PDS_VERSION="unknown"
if [ -n "$CLAUDE_PLUGIN_ROOT" ] && [ -f "$CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json" ]; then
  PDS_VERSION=$(python3 -c "import json; print(json.load(open('$CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json')).get('version', 'unknown'))" 2>/dev/null || echo "unknown")
fi

# --- Require ledger daemon ---
LEDGER_SOCK="$HOME/.ledger/ledger.sock"
if [ ! -S "$LEDGER_SOCK" ]; then
  echo "Ledger daemon not running. Install: ~/dev/ledger/install/install.sh" >&2
  exit 2
fi
LEDGER_STATUS=" Ledger: running."

# --- Detect worktree ---
WORKTREE_INFO=""
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  GIT_DIR=$(git rev-parse --git-dir 2>/dev/null)
  if echo "$GIT_DIR" | grep -q "worktrees"; then
    WT_NAME=$(basename "$(pwd)")
    MAIN_REPO=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | sed 's|/.git$||')
    WORKTREE_INFO=" Worktree: $WT_NAME (repo: $MAIN_REPO)."
  fi
fi

# --- Detect stale v3.x install artifacts ---
STALE_WARNING=""
if [ -f ".claude/.pds-version" ]; then
  STALE_WARNING=" STALE v3 ARTIFACTS: .pds-version found. PDS is a plugin now. Run install.sh --cleanup in this repo to remove old artifacts."
fi

# --- Detect stale worktrees ---
WORKTREE_WARNING=""
if [ -d ".worktrees" ] && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  _stale_count=0

  # Orphans: dirs in .worktrees/ not in git worktree list
  _git_worktrees=$(git worktree list --porcelain 2>/dev/null | grep '^worktree ' | sed 's|^worktree ||')
  for _d in .worktrees/*/; do
    [ -d "$_d" ] || continue
    _abs=$(cd "$_d" && pwd 2>/dev/null) || { _stale_count=$((_stale_count + 1)); continue; }
    echo "$_git_worktrees" | grep -qF "$_abs" || _stale_count=$((_stale_count + 1))
  done

  # Merged-branch worktrees: branch already merged to main/master
  _main=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
  [ -z "$_main" ] && _main="main"
  _merged=$(git branch --merged "$_main" 2>/dev/null | sed 's/^[* ]*//')
  while IFS= read -r _line; do
    case "$_line" in worktree\ *)
      _wt="${_line#worktree }"
      case "$_wt" in */.worktrees/*)
        _branch=$(git -C "$_wt" rev-parse --abbrev-ref HEAD 2>/dev/null)
        [ -n "$_branch" ] && echo "$_merged" | grep -qxF "$_branch" && _stale_count=$((_stale_count + 1))
      ;; esac
    ;; esac
  done < <(git worktree list --porcelain 2>/dev/null)

  [ "$_stale_count" -gt 0 ] && WORKTREE_WARNING=" STALE WORKTREES: $_stale_count stale worktree(s) in .worktrees/. Run /pds:worktree gc to clean up."
fi

# --- Write persistent env vars ---
if [ -n "$CLAUDE_ENV_FILE" ]; then
  echo "export PDS_VERSION=\"$PDS_VERSION\"" >> "$CLAUDE_ENV_FILE"
  if [ -n "$CLAUDE_PLUGIN_ROOT" ]; then
    echo "export PDS_PLUGIN_ROOT=\"$CLAUDE_PLUGIN_ROOT\"" >> "$CLAUDE_ENV_FILE"
  fi
fi

# --- Sync worktree permissions (symlink settings.local.json from repo root) ---
if [ -n "$CLAUDE_PLUGIN_ROOT" ] && [ -f "$CLAUDE_PLUGIN_ROOT/hooks/scripts/sync-worktree-permissions.sh" ]; then
  "$CLAUDE_PLUGIN_ROOT/hooks/scripts/sync-worktree-permissions.sh" 2>/dev/null || true
fi

# --- Codebase intelligence (optional, graceful degradation) ---
CODEBASE_CONTEXT=""
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/codebase-context.sh" ]; then
  CODEBASE_CONTEXT=$("$SCRIPT_DIR/codebase-context.sh" 2>/dev/null || true)
  [ -n "$CODEBASE_CONTEXT" ] && CODEBASE_CONTEXT=" $CODEBASE_CONTEXT"
fi

# --- Output additionalContext ---
CONTEXT="PDS v${PDS_VERSION} active. Key skills: /pds:swarm (parallel work), /pds:grill (requirements), /pds:verify (completion check), /pds:bugfix (test-first fixes), /pds:checkpoint (ship work), /pds:finish (formal branch completion).${WORKTREE_INFO}${STALE_WARNING}${WORKTREE_WARNING}${LEDGER_STATUS}${CODEBASE_CONTEXT}"

# Use python3 for safe JSON encoding
python3 -c "
import json, sys
ctx = sys.argv[1]
print(json.dumps({
    'hookSpecificOutput': {
        'hookEventName': 'SessionStart',
        'additionalContext': ctx
    }
}))
" "$CONTEXT" 2>/dev/null || exit 0
