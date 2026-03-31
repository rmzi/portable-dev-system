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

mkdir -p .claude
printf '{"ts":"%s","event":"%s","name":"%s","session":"%s"}\n' "$TS" "$EVENT" "$NAME" "$SESSION" >> .claude/telemetry.jsonl

exit 0
