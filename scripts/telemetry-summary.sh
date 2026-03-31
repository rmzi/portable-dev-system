#!/bin/sh
# telemetry-summary.sh — PDS telemetry report generator
#
# Usage:
#   ./scripts/telemetry-summary.sh [telemetry_file]
#
# Reads JSONL telemetry data and produces a formatted usage report.
# Requires: jq

set -e

TELEMETRY_FILE="${1:-.claude/telemetry.jsonl}"
SKILLS_DIR="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$0")")}/skills"

# Check if telemetry file exists and has content
if [ ! -f "$TELEMETRY_FILE" ] || [ ! -s "$TELEMETRY_FILE" ]; then
  echo "No telemetry data found."
  exit 0
fi

# Check jq is available
if ! command -v jq >/dev/null 2>&1; then
  echo "jq required for telemetry summary. Install: brew install jq (macOS) or apt install jq (Linux)"
  exit 1
fi

TOTAL=$(wc -l < "$TELEMETRY_FILE" | tr -d ' ')
FIRST_DATE=$(head -1 "$TELEMETRY_FILE" | jq -r '.ts // empty' 2>/dev/null)
LAST_DATE=$(tail -1 "$TELEMETRY_FILE" | jq -r '.ts // empty' 2>/dev/null)

echo "=== PDS Telemetry Report ==="
echo "Period: ${FIRST_DATE:-unknown} to ${LAST_DATE:-unknown}"
echo "Total events: $TOTAL"
echo ""

# Top skills by invocation count
echo "Top Skills:"
jq -r 'select(.event == "skill_invoked") | .name' "$TELEMETRY_FILE" 2>/dev/null \
  | sort | uniq -c | sort -rn | head -10 \
  | while read -r count name; do
      printf "  %-20s %s\n" "$name" "$count"
    done
echo ""

# Top agents by spawn count
echo "Top Agents:"
jq -r 'select(.event == "agent_spawned") | .name' "$TELEMETRY_FILE" 2>/dev/null \
  | sort | uniq -c | sort -rn \
  | while read -r count name; do
      printf "  %-20s %s\n" "$name" "$count"
    done
echo ""

# File modifications by extension
echo "File Modifications by Extension:"
jq -r 'select(.event == "file_modified") | .name' "$TELEMETRY_FILE" 2>/dev/null \
  | sed 's/.*\./\./' | sort | uniq -c | sort -rn \
  | while read -r count ext; do
      printf "  %-20s %s\n" "$ext" "$count"
    done
echo ""

# Zero-usage skills
if [ -d "$SKILLS_DIR" ]; then
  USED_SKILLS=$(jq -r 'select(.event == "skill_invoked") | .name' "$TELEMETRY_FILE" 2>/dev/null | sort -u)
  ZERO_SKILLS=""
  for skill_dir in "$SKILLS_DIR"/*/; do
    skill_name=$(basename "$skill_dir")
    [ -f "$skill_dir/SKILL.md" ] || continue
    if ! echo "$USED_SKILLS" | grep -qx "$skill_name"; then
      if [ -n "$ZERO_SKILLS" ]; then
        ZERO_SKILLS="$ZERO_SKILLS, $skill_name"
      else
        ZERO_SKILLS="$skill_name"
      fi
    fi
  done
  if [ -n "$ZERO_SKILLS" ]; then
    echo "Zero-Usage Skills:"
    echo "  $ZERO_SKILLS"
  fi
fi

exit 0
