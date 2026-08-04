#!/bin/bash
# PDS Stop gate for orchestrator — blocks the orchestrator from stopping while
# .claude/swarm/phase reads "knowledge" unless all 3 phase reports, a clean
# .worktrees/, and docs/swarm-reports/ all exist. This is the teardown-equivalent
# replacement for the old PreToolUse(TeamDelete) gate — TeamCreate/TeamDelete were
# removed as Claude Code tools in v2.1.178; team formation and cleanup are now
# automatic, so there is no tool call left to gate. See docs/adr/0007.
# Defined in orchestrator.md frontmatter as a Stop hook; fires on every orchestrator
# turn-end, not just intended teardown — see the phase check below for why that's safe.
# Exit 0 = allow stop, Exit 2 = block with reason (orchestrator's turn continues).

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

# Phase check. Only phase "knowledge" is teardown-shaped — every earlier phase is a
# normal mid-swarm handoff (e.g. a Phase-1-only orchestrator returning a plan for
# human approval, or an orchestrator instance ending after a checkpoint write) and
# must be allowed to stop unconditionally. Blocking those would be a regression
# introduced by Stop firing on every turn-end, unlike the old PreToolUse(TeamDelete)
# gate which only ever fired at the one call site that meant "tear down now."
KNOWN_PHASES="plan decompose dispatch validate consolidate knowledge"
if [ -f "$SWARM_DIR/phase" ]; then
  PHASE=$(tr -d '[:space:]' < "$SWARM_DIR/phase" 2>/dev/null) || {
    printf "[PDS GATE] BLOCKED: Cannot read .claude/swarm/phase — check file permissions." >&2
    exit 2
  }
  if [ -z "$PHASE" ]; then
    printf "[PDS GATE] BLOCKED: .claude/swarm/phase is empty. Write the current phase name and retry." >&2
    exit 2
  fi
  if ! echo "$KNOWN_PHASES" | grep -qw "$PHASE"; then
    printf "[PDS GATE] BLOCKED: Unrecognized phase '%s' in .claude/swarm/phase.\nValid phases: %s" "$PHASE" "$KNOWN_PHASES" >&2
    exit 2
  fi
  if [[ "$PHASE" != "knowledge" ]]; then
    exit 0
  fi
else
  printf "[PDS GATE] WARNING: .claude/swarm/phase missing — phase gate bypassed, falling through to artifact checks.\n" >&2
fi

# From here on, phase is "knowledge" (or the phase file is missing entirely) — this
# stop is teardown-shaped. Enforce the same artifact/worktree/archive checks the old
# TeamDelete gate enforced.
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
  printf "[PDS GATE] BLOCKED: Cannot end swarm — missing required phase artifacts:\n%b\nComplete all phases before stopping." "$MISSING" >&2
  exit 2
fi

# Worktree cleanup check (#106) — all swarm worktrees must be removed before teardown
if [ -d "$CWD/.worktrees" ] && [ -n "$(ls -A "$CWD/.worktrees" 2>/dev/null)" ]; then
  printf "[PDS GATE] BLOCKED: Cannot end swarm — worktrees still exist in .worktrees/:\n" >&2
  ls "$CWD/.worktrees" | sed 's/^/  - /' >&2
  printf "Remove each worktree with: git worktree remove .worktrees/<name>" >&2
  exit 2
fi

# Artifact archival check (#106) — docs/swarm-reports/ must exist before teardown
if [ ! -d "$CWD/docs/swarm-reports" ]; then
  printf "[PDS GATE] BLOCKED: Cannot end swarm — docs/swarm-reports/ does not exist.\nArchive phase artifacts there before cleanup." >&2
  exit 2
fi

exit 0
