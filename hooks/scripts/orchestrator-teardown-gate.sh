#!/bin/bash
# PDS PreToolUse gate for orchestrator — blocks TeamDelete without all 3 phase reports.
# Defined in orchestrator.md frontmatter; activates on TeamDelete tool use.
# Only enforces when .claude/swarm/ exists (swarm is active).
# Exit 0 = allow, Exit 2 = block with reason.

command -v jq >/dev/null 2>&1 || exit 0  # jq required for gate enforcement

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

# Phase check (defense-in-depth — warns if phase file missing, blocks if wrong phase)
KNOWN_PHASES="plan decompose dispatch validate consolidate knowledge"
if [ -f "$SWARM_DIR/phase" ]; then
  PHASE=$(tr -d '[:space:]' < "$SWARM_DIR/phase" 2>/dev/null) || {
    printf "BLOCKED: Cannot read .claude/swarm/phase — check file permissions." >&2
    exit 2
  }
  if [ -z "$PHASE" ]; then
    printf "BLOCKED: .claude/swarm/phase is empty. Write the current phase name and retry." >&2
    exit 2
  fi
  if ! echo "$KNOWN_PHASES" | grep -qw "$PHASE"; then
    printf "BLOCKED: Unrecognized phase '%s' in .claude/swarm/phase.\nValid phases: %s" "$PHASE" "$KNOWN_PHASES" >&2
    exit 2
  fi
  if [[ "$PHASE" != "knowledge" ]]; then
    printf "BLOCKED: Cannot tear down team in phase '%s' — advance to 'knowledge' first." "$PHASE" >&2
    exit 2
  fi
else
  printf "WARNING: .claude/swarm/phase missing — phase gate bypassed, falling through to artifact checks.\n" >&2
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
