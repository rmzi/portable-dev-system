#!/usr/bin/env bash
# PDS SessionEnd hook — auto-fire dev-diary assembly at session close.
#
# Gated behind PDS_DIARY=1. Reads session_id, transcript_path, cwd from the
# hook JSON payload on stdin (schema: SessionEndHookInputSchema in Claude Code).
# Exits 0 always — must never block session shutdown.

set -u

# Non-blocking: any failure path exits 0.
trap 'exit 0' ERR

# Feature gate
case "${PDS_DIARY:-}" in
  1|on|true|yes) ;;
  *) exit 0 ;;
esac

# Parse hook input
INPUT="$(cat)"
if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

TRANSCRIPT_PATH="$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)"
HOOK_CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)"

[ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ] && exit 0
[ -z "$HOOK_CWD" ] && exit 0

cd "$HOOK_CWD" 2>/dev/null || exit 0

# Only act inside a git repo
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

BRANCH="$(git branch --show-current 2>/dev/null)"
[ -z "$BRANCH" ] && exit 0

# Parse issue number from <type>/<issue>-<slug>. No issue → no diary.
ISSUE="$(printf '%s' "$BRANCH" | sed -nE 's|^[a-z]+/([0-9]+)-.*|\1|p')"
[ -z "$ISSUE" ] && exit 0

# Locate assemble-diary.sh
ASSEMBLE=""
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -x "$CLAUDE_PLUGIN_ROOT/scripts/assemble-diary.sh" ]; then
  ASSEMBLE="$CLAUDE_PLUGIN_ROOT/scripts/assemble-diary.sh"
elif [ -x "scripts/assemble-diary.sh" ]; then
  ASSEMBLE="scripts/assemble-diary.sh"
fi
[ -z "$ASSEMBLE" ] && exit 0

# Fire the diary. Pass TRANSCRIPT_PATH so export-session.sh skips CWD-hash discovery.
# Run in background — do not block shutdown on gh/network latency.
(
  BRANCH="$BRANCH" ISSUE="$ISSUE" TRANSCRIPT_PATH="$TRANSCRIPT_PATH" \
    MODE=post PDS_DIARY=1 \
    bash "$ASSEMBLE" >/dev/null 2>&1 || true
) &

exit 0
