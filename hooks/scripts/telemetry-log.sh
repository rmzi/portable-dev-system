#!/bin/sh
# PDS PostToolUse (Skill|Agent) hook — logs skill invocations and agent spawns
# to .claude/telemetry.jsonl. Opt-in via PDS_TELEMETRY=1 (disabled by default).

[ "${PDS_TELEMETRY:-0}" = "0" ] && exit 0

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

[ -z "$TOOL_NAME" ] && exit 0

TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
SESSION=${CLAUDE_SESSION_ID:-unknown}

case "$TOOL_NAME" in
  Skill)
    SKILL=$(echo "$INPUT" | jq -r '.tool_input.skill // empty')
    [ -z "$SKILL" ] && exit 0
    EVENT="skill_invoked"
    NAME="$SKILL"
    ;;
  Agent)
    AGENT_TYPE=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // .tool_input.description // empty')
    [ -z "$AGENT_TYPE" ] && exit 0
    EVENT="agent_spawned"
    NAME="$AGENT_TYPE"
    ;;
  *)
    exit 0
    ;;
esac

AGENT=${CLAUDE_AGENT_TYPE:-main}

# Project-level telemetry (may be lost with worktrees)
mkdir -p .claude
printf '{"ts":"%s","event":"%s","name":"%s","agent":"%s","session":"%s"}\n' "$TS" "$EVENT" "$NAME" "$AGENT" "$SESSION" >> .claude/telemetry.jsonl

# User-level telemetry (survives worktree cleanup)
USER_TELEM_DIR="${HOME}/.claude/telemetry"
mkdir -p "$USER_TELEM_DIR"
REPO=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || echo unknown)")
printf '{"ts":"%s","event":"%s","name":"%s","agent":"%s","session":"%s","repo":"%s"}\n' "$TS" "$EVENT" "$NAME" "$AGENT" "$SESSION" "$REPO" >> "$USER_TELEM_DIR/sessions.jsonl"

exit 0
