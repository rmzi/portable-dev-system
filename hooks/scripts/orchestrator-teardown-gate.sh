#!/bin/bash
# PDS PreToolUse gate for orchestrator — blocks TeamDelete without all 3 phase reports.
# Defined in orchestrator.md frontmatter; activates on TeamDelete tool use.
# Only enforces when .claude/swarm/ exists (swarm is active).
# Exit 0 = allow, Exit 2 = block with reason.

INPUT=$(cat)
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

if [ ! -f "$SWARM_DIR/scout-report.md" ]; then
  MISSING="${MISSING}  - .claude/swarm/scout-report.md (Phase 6: scout)\n"
fi

if [ -n "$MISSING" ]; then
  printf "BLOCKED: Cannot tear down team — missing required phase artifacts:\n%b\nComplete all phases before cleanup." "$MISSING" >&2
  exit 2
fi

exit 0
