#!/bin/bash
# PDS orchestrator teardown gate — verifies swarm completion before cleanup.
#
# ⚠ v5.0.0 RETROFIT — CURRENTLY UNWIRED. TODO(#159, Zone 1).
# This gate previously fired as a PreToolUse hook on the `TeamDelete` tool.
# Claude Code removed TeamCreate/TeamDelete at v2.1.178 — teams are now implicit
# per-session and dissolve at SessionEnd, which cannot block. There is no longer
# a blockable teardown moment to intercept, so orchestrator.md no longer wires
# this script to any matcher.
#
# The CHECK LOGIC below is intact and worth preserving — it must be re-homed onto
# a blockable event. Two candidates (decision deferred, see #159):
#   1. Stop-based gate — enforce only when swarm active AND phase == knowledge.
#   2. Fold into the PR gate — enforcement moves earlier (no consolidate/PR
#      without the reports); SessionEnd becomes advisory/warn-only.
# Until then this file is dormant: it is not invoked by any hook.
#
# Contract (unchanged): reads hook JSON on stdin. Exit 0 = allow, Exit 2 = block.
# Only enforces when .claude/swarm/ exists (swarm is active).

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

# Worktree cleanup check (#106) — all swarm worktrees must be removed before teardown
if [ -d "$CWD/.worktrees" ] && [ -n "$(ls -A "$CWD/.worktrees" 2>/dev/null)" ]; then
  printf "BLOCKED: Cannot tear down team — worktrees still exist in .worktrees/:\n" >&2
  ls "$CWD/.worktrees" | sed 's/^/  - /' >&2
  printf "Remove each worktree with: git worktree remove .worktrees/<name>" >&2
  exit 2
fi

# Artifact archival check (#106) — docs/swarm-reports/ must exist before teardown
if [ ! -d "$CWD/docs/swarm-reports" ]; then
  printf "BLOCKED: Cannot tear down team — docs/swarm-reports/ does not exist.\nArchive phase artifacts there before cleanup." >&2
  exit 2
fi

exit 0
