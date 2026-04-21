#!/usr/bin/env bash
# PDS SubagentStop hook — finalizes the shepherd journal on graceful exit
# AND abort paths (captures failure-mode data on abort).
#
# Scoped to the `shepherd` subagent via hook matcher and defensive self-check.
# Exits 0 on all paths — hooks must not block termination.
#
# Contract (see .claude/swarm/contracts.md, Contract 3 during build):
#   - If journal absent: create with header.
#   - On graceful stop: append `**Status**: graceful` to current swarm section.
#   - On abort stop: append `**Status**: abort` + `### Failure mode` subsection.
#   - Idempotent: running twice must not corrupt the journal.
#   - Silent on stdout; diagnostics to stderr only.

set -u

# ---------------------------------------------------------------------------
# Identify whether this invocation is for the shepherd subagent.
# Different Claude Code hook environments expose slightly different env vars;
# check multiple candidates. If none identifies us as shepherd, exit silently.
# ---------------------------------------------------------------------------
SUBAGENT_NAME="${CLAUDE_SUBAGENT_NAME:-${CLAUDE_AGENT_NAME:-${CLAUDE_AGENT_TYPE:-}}}"

# Also check JSON on stdin (Claude Code often delivers hook payload via stdin).
STDIN_JSON=""
if [ ! -t 0 ]; then
  STDIN_JSON=$(cat 2>/dev/null || echo "")
fi

# Extract subagent identifiers from stdin JSON if env vars are empty.
if [ -z "$SUBAGENT_NAME" ] && [ -n "$STDIN_JSON" ] && command -v jq >/dev/null 2>&1; then
  SUBAGENT_NAME=$(printf '%s' "$STDIN_JSON" | jq -r '
      .subagent_name // .agent_name // .agent_type //
      .subagent // .name // empty' 2>/dev/null || echo "")
fi

# Filter: only fire for shepherd. Any other subagent (worker, validator, ...)
# exits silently — this prevents other subagents from accidentally touching
# the journal if the matcher at the hook-definition layer is too broad.
case "$SUBAGENT_NAME" in
  shepherd|pds-shepherd|pds:shepherd)
    : # fall through
    ;;
  "")
    # Empty string: treat as shepherd only if journal already exists
    # (best-effort — avoids false positives for other subagents in envs
    # where the matcher in hooks.json is already scoping for us).
    PROJ_DIR_PROBE="${CLAUDE_PROJECT_DIR:-${PROJECT_DIR:-$(pwd)}}"
    if [ ! -f "$PROJ_DIR_PROBE/.claude/shepherd-journal.md" ]; then
      exit 0
    fi
    ;;
  *)
    exit 0
    ;;
esac

# ---------------------------------------------------------------------------
# Identify graceful vs abort.
# ---------------------------------------------------------------------------
STOP_REASON="${CLAUDE_STOP_REASON:-${CLAUDE_SUBAGENT_STOP_REASON:-}}"
if [ -z "$STOP_REASON" ] && [ -n "$STDIN_JSON" ] && command -v jq >/dev/null 2>&1; then
  STOP_REASON=$(printf '%s' "$STDIN_JSON" | jq -r '
      .stop_reason // .reason // .status // empty' 2>/dev/null || echo "")
fi

# Default to graceful if we cannot identify a failure signal.
STATUS="graceful"
case "$STOP_REASON" in
  abort|aborted|error|failure|failed|timeout|crash|canceled|cancelled)
    STATUS="abort"
    ;;
esac

# ---------------------------------------------------------------------------
# Locate the project directory and journal path.
# ---------------------------------------------------------------------------
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-${PROJECT_DIR:-$(pwd)}}"
JOURNAL="$PROJECT_DIR/.claude/shepherd-journal.md"
mkdir -p "$(dirname "$JOURNAL")" 2>/dev/null || true

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)

# ---------------------------------------------------------------------------
# Initialize journal if absent.
# ---------------------------------------------------------------------------
if [ ! -f "$JOURNAL" ]; then
  PROJECT_NAME=$(basename "$PROJECT_DIR")
  PDS_VERSION_STR="${PDS_VERSION:-unknown}"
  {
    echo "# Shepherd Journal — $PROJECT_NAME"
    echo ""
    echo "<Initialized $NOW by shepherd-finalize.sh (PDS v$PDS_VERSION_STR)>"
    echo ""
    echo "---"
    echo ""
  } > "$JOURNAL" 2>/dev/null || {
    echo "[shepherd-finalize] unable to create journal at $JOURNAL" >&2
    exit 0
  }
fi

# ---------------------------------------------------------------------------
# Identify the current swarm section, or open one if none exists.
# Idempotence: if the most recent "## Swarm" section already carries a
# **Status** marker of "graceful" or "abort", we've finalized before — do
# nothing (but leave exit 0 so the hook is safe to retry).
# ---------------------------------------------------------------------------
LAST_STATUS=$(awk '
  /^## Swarm / { section_line=NR }
  /^\*\*Status\*\*:/ && NR > section_line { last=$2 }
  END { gsub(/[^a-z]/, "", last); print last }
' "$JOURNAL" 2>/dev/null || echo "")

# If the last section is already finalized, exit quietly.
case "$LAST_STATUS" in
  graceful|abort)
    exit 0
    ;;
esac

# Count swarm sections defensively. `grep -c` exits 1 on no-match which
# would trigger `|| echo 0`, producing a two-line value on some shells;
# force a single numeric line.
if grep -q '^## Swarm ' "$JOURNAL" 2>/dev/null; then
  HAS_SWARM_SECTION=1
else
  HAS_SWARM_SECTION=0
fi

SWARM_TIER="${PDS_TIER:-}"
if [ -z "$SWARM_TIER" ] && [ -f "$PROJECT_DIR/.claude/swarm/tier" ]; then
  SWARM_TIER=$(head -n 1 "$PROJECT_DIR/.claude/swarm/tier" 2>/dev/null || echo "")
fi
[ -z "$SWARM_TIER" ] && SWARM_TIER="unknown"

SWARM_ID="${PDS_SWARM_ID:-$(date -u +%Y-%m-%d-%H%M 2>/dev/null || date +%Y-%m-%d-%H%M)}"

# Emit the swarm section opener if none exists.
if [ "$HAS_SWARM_SECTION" -eq 0 ]; then
  {
    echo ""
    echo "## Swarm $SWARM_ID — $(date -u +%Y-%m-%d 2>/dev/null || date +%Y-%m-%d)"
    echo ""
    echo "**Tier**: $SWARM_TIER"
    echo "**Status**: $STATUS"
    echo ""
  } >> "$JOURNAL" 2>/dev/null || {
    echo "[shepherd-finalize] unable to append swarm opener" >&2
    exit 0
  }
else
  # Append the status marker under the most recent swarm section.
  {
    echo ""
    echo "**Status**: $STATUS"
    echo ""
  } >> "$JOURNAL" 2>/dev/null || {
    echo "[shepherd-finalize] unable to append status" >&2
    exit 0
  }
fi

# ---------------------------------------------------------------------------
# On abort: capture any available failure-mode context.
# ---------------------------------------------------------------------------
if [ "$STATUS" = "abort" ]; then
  {
    echo "### Failure mode"
    echo ""
    echo "- Finalized by shepherd-finalize.sh at $NOW"
    if [ -n "$STOP_REASON" ]; then
      echo "- Stop reason: $STOP_REASON"
    fi
    if [ -n "$STDIN_JSON" ]; then
      # Emit a short head of the hook payload — bounded to 1KB to keep the
      # journal readable.
      echo "- Payload head:"
      echo '```'
      printf '%s' "$STDIN_JSON" | head -c 1024
      echo ""
      echo '```'
    fi
    echo ""
    echo "---"
    echo ""
  } >> "$JOURNAL" 2>/dev/null || {
    echo "[shepherd-finalize] unable to append failure mode" >&2
    exit 0
  }
fi

exit 0
