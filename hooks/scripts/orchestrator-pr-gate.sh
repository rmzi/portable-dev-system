#!/bin/bash
# PDS PreToolUse gate for orchestrator — blocks `gh pr create` without required phase reports.
# Defined in orchestrator.md frontmatter; activates on Bash tool use.
# Only enforces when .claude/swarm/ exists (swarm is active).
# Exit 0 = allow, Exit 2 = block with reason.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only gate on `gh pr create`
case "$COMMAND" in
  *"gh pr create"*) ;;
  *) exit 0 ;;
esac

CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
if [ -z "$CWD" ]; then
  exit 0
fi

SWARM_DIR="$CWD/.claude/swarm"

# No swarm active — no enforcement
if [ ! -d "$SWARM_DIR" ]; then
  exit 0
fi

MISSING=""

if [ ! -f "$SWARM_DIR/validation-report.md" ]; then
  MISSING="${MISSING}  - .claude/swarm/validation-report.md (Phase 4: validator)\n"
fi

if [ ! -f "$SWARM_DIR/review-report.md" ]; then
  MISSING="${MISSING}  - .claude/swarm/review-report.md (Phase 5: reviewer)\n"
fi

if [ -n "$MISSING" ]; then
  printf "BLOCKED: Cannot create PR — missing required phase artifacts:\n%b\nComplete Phase 4 (validation) and Phase 5 (review) before creating a PR." "$MISSING" >&2
  exit 2
fi

exit 0
