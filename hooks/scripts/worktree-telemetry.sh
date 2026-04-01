#!/bin/sh
# PDS WorktreeCreate hook — logs worktree creation to telemetry
# Opt-in via PDS_TELEMETRY=1 (disabled by default).

INPUT=$(cat)
NAME=$(echo "$INPUT" | jq -r '.name // "unknown"' 2>/dev/null || echo unknown)

if [ "${PDS_TELEMETRY:-0}" = "1" ]; then
  mkdir -p .claude 2>/dev/null
  printf '{"ts":"%s","event":"worktree_created","name":"%s","session":"%s"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$NAME" "${CLAUDE_SESSION_ID:-unknown}" \
    >> .claude/telemetry.jsonl 2>/dev/null
fi

echo ok
