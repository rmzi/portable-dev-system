#!/bin/bash
# PDS TeammateIdle hook — checks for uncommitted work before allowing idle.
# Exit 0 = allow idle, Exit 2 = keep working (stderr fed back to agent).
# Input: JSON on stdin with teammate_name, team_name, cwd.

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

if [ -z "$CWD" ] || [ ! -d "$CWD/.git" ] && ! git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1; then
  exit 0
fi

# Check for staged or unstaged uncommitted changes
STAGED_CLEAN=true
UNSTAGED_CLEAN=true

(cd "$CWD" && git diff --cached --quiet 2>/dev/null) || STAGED_CLEAN=false
(cd "$CWD" && git diff --quiet 2>/dev/null) || UNSTAGED_CLEAN=false

if $STAGED_CLEAN && $UNSTAGED_CLEAN; then
  exit 0
else
  TEAMMATE=$(echo "$INPUT" | jq -r '.teammate_name // "agent"')
  if ! $STAGED_CLEAN && ! $UNSTAGED_CLEAN; then
    echo "$TEAMMATE has staged and unstaged uncommitted changes. Commit before going idle." >&2
  elif ! $STAGED_CLEAN; then
    echo "$TEAMMATE has staged uncommitted changes. Commit before going idle." >&2
  else
    echo "$TEAMMATE has unstaged uncommitted changes. Commit before going idle." >&2
  fi
  exit 2
fi
