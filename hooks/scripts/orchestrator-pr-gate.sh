#!/bin/bash
# PDS PreToolUse gate for orchestrator — blocks `gh pr create` without required phase reports.
# Defined in orchestrator.md frontmatter; activates on Bash tool use.
# Only enforces when .claude/swarm/ exists (swarm is active).
# Exit 0 = allow, Exit 2 = block with reason.

command -v jq >/dev/null 2>&1 || exit 0  # jq required for gate enforcement

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
  if [[ "$PHASE" != "consolidate" && "$PHASE" != "knowledge" ]]; then
    printf "BLOCKED: Cannot create PR in phase '%s' — advance to 'consolidate' first." "$PHASE" >&2
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

if [ -n "$MISSING" ]; then
  printf "BLOCKED: Cannot create PR — missing required phase artifacts:\n%b\nComplete Phase 4 (validation) and Phase 5 (review) before creating a PR." "$MISSING" >&2
  exit 2
fi

exit 0
