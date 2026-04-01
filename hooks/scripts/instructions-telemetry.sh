#!/bin/sh
# PDS InstructionsLoaded hook — logs instruction loading to telemetry
# Opt-in via PDS_TELEMETRY=1 (disabled by default).

if [ "${PDS_TELEMETRY:-0}" = "1" ]; then
  mkdir -p .claude 2>/dev/null
  printf '{"ts":"%s","event":"instructions_loaded","session":"%s"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${CLAUDE_SESSION_ID:-unknown}" \
    >> .claude/telemetry.jsonl 2>/dev/null
fi

exit 0
