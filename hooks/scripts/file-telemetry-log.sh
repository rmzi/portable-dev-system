#!/bin/sh
# PDS PostToolUse (Write|Edit) hook — logs file modification events to .claude/telemetry.jsonl.
# Opt-in via PDS_TELEMETRY=1 (disabled by default).

[ "${PDS_TELEMETRY:-0}" = "0" ] && exit 0

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty')

[ -z "$FILE_PATH" ] && exit 0

EXT=$(echo "$FILE_PATH" | sed 's/.*\.//' | tr '[:upper:]' '[:lower:]')
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
AGENT=${CLAUDE_AGENT_TYPE:-unknown}
SESSION=${CLAUDE_SESSION_ID:-unknown}

mkdir -p .claude
printf '{"ts":"%s","event":"file_modified","path":"%s","ext":"%s","agent":"%s","session":"%s"}\n' "$TS" "$FILE_PATH" "$EXT" "$AGENT" "$SESSION" >> .claude/telemetry.jsonl

exit 0
