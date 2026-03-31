#!/bin/sh
# detect-patterns.sh — Analyze telemetry for instinct-worthy patterns
# Reads .claude/telemetry.jsonl and outputs draft instinct entries to stdout.
# Never auto-writes to .claude/instincts.md.

set -e

TELEMETRY_FILE="${1:-.claude/telemetry.jsonl}"
SKILLS_DIR="${2:-${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/}skills}"
SKILLS_DIR="${SKILLS_DIR:-skills}"
TODAY=$(date +%Y-%m-%d)
PATTERNS_FOUND=0

# --- Preflight ---

if [ ! -f "$TELEMETRY_FILE" ] || [ ! -s "$TELEMETRY_FILE" ]; then
  echo "No telemetry data to analyze."
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq required. Install: brew install jq (macOS) or apt install jq (Linux)" >&2
  exit 1
fi

# --- Pattern 1: Repeated skill invocation (3+ times in one session) ---

repeated_skills=$(jq -r '
  select(.event == "skill_invoked") |
  "\(.session)|\(.name)"
' "$TELEMETRY_FILE" 2>/dev/null | sort | uniq -c | awk '$1 >= 3 { print $1, $2 }')

if [ -n "$repeated_skills" ]; then
  echo "$repeated_skills" | while IFS= read -r line; do
    count=$(echo "$line" | awk '{print $1}')
    session_skill=$(echo "$line" | awk '{print $2}')
    session=$(echo "$session_skill" | cut -d'|' -f1)
    skill=$(echo "$session_skill" | cut -d'|' -f2)
    PATTERNS_FOUND=$((PATTERNS_FOUND + 1))
    cat <<ENTRY

### Repeated Skill Invocation: $skill
- **Observed**: $TODAY
- **Times seen**: 1
- **Confidence**: low
- **Context**: [detected from telemetry analysis]
- **Pattern**: Skill "$skill" was invoked $count times in session $session
- **Action**: Investigate if this skill should be split, automated, or if a workflow shortcut is needed
- **Status**: draft
ENTRY
  done
fi

# --- Pattern 2: Agent spawned but no task completed ---

orphan_sessions=$(jq -r '
  select(.event == "agent_spawned") | .session
' "$TELEMETRY_FILE" 2>/dev/null | sort -u)

if [ -n "$orphan_sessions" ]; then
  echo "$orphan_sessions" | while IFS= read -r session; do
    has_file_mod=$(jq -r --arg s "$session" '
      select(.session == $s and .event == "file_modified") | .session
    ' "$TELEMETRY_FILE" 2>/dev/null | head -1)
    if [ -z "$has_file_mod" ]; then
      agent_types=$(jq -r --arg s "$session" '
        select(.session == $s and .event == "agent_spawned") | .name // .type // "unknown"
      ' "$TELEMETRY_FILE" 2>/dev/null | sort -u | tr '\n' ', ' | sed 's/,$//')
      cat <<ENTRY

### Agent Spawned Without Output: $session
- **Observed**: $TODAY
- **Times seen**: 1
- **Confidence**: low
- **Context**: [detected from telemetry analysis]
- **Pattern**: Agents ($agent_types) were spawned in session $session but no file modifications followed
- **Action**: Investigate if agents failed silently, were misconfigured, or the task was abandoned
- **Status**: draft
ENTRY
    fi
  done
fi

# --- Pattern 3: Dominant file extension (60%+) ---

extension_counts=$(jq -r '
  select(.event == "file_modified") | .path
' "$TELEMETRY_FILE" 2>/dev/null | sed 's/.*\.//' | sort | uniq -c | sort -rn)

if [ -n "$extension_counts" ]; then
  total=$(echo "$extension_counts" | awk '{s+=$1} END {print s}')
  if [ "$total" -gt 0 ] 2>/dev/null; then
    echo "$extension_counts" | while IFS= read -r line; do
      count=$(echo "$line" | awk '{print $1}')
      ext=$(echo "$line" | awk '{print $2}')
      pct=$((count * 100 / total))
      if [ "$pct" -ge 60 ]; then
        cat <<ENTRY

### Dominant File Extension: .$ext
- **Observed**: $TODAY
- **Times seen**: 1
- **Confidence**: low
- **Context**: [detected from telemetry analysis]
- **Pattern**: .$ext files account for ${pct}% ($count/$total) of all file modifications
- **Action**: Consider adding .$ext-specific tooling, linting rules, or skill specialization
- **Status**: draft
ENTRY
      fi
    done
  fi
fi

# --- Pattern 4: Zero-usage skills ---

if [ -d "$SKILLS_DIR" ]; then
  invoked_skills=$(jq -r '
    select(.event == "skill_invoked") | .name
  ' "$TELEMETRY_FILE" 2>/dev/null | sort -u)

  unused=""
  for skill_dir in "$SKILLS_DIR"/*/; do
    [ -d "$skill_dir" ] || continue
    [ -f "${skill_dir}SKILL.md" ] || continue
    skill_name=$(basename "$skill_dir")
    if ! echo "$invoked_skills" | grep -qx "$skill_name"; then
      unused="${unused}${unused:+, }$skill_name"
    fi
  done

  if [ -n "$unused" ]; then
    cat <<ENTRY

### Zero-Usage Skills
- **Observed**: $TODAY
- **Times seen**: 1
- **Confidence**: low
- **Context**: [detected from telemetry analysis]
- **Pattern**: The following skills have zero invocations in telemetry: $unused
- **Action**: Evaluate if these skills are discoverable, well-named, or candidates for retirement
- **Status**: draft
ENTRY
  fi
fi

# --- Summary ---

# Count pattern blocks in our output (each starts with ###)
# We use a simple heuristic: count the pattern headers we might have emitted
count=0
[ -n "$repeated_skills" ] && count=$((count + $(echo "$repeated_skills" | wc -l | tr -d ' ')))

if [ -n "$orphan_sessions" ]; then
  for session in $orphan_sessions; do
    has_file_mod=$(jq -r --arg s "$session" '
      select(.session == $s and .event == "file_modified") | .session
    ' "$TELEMETRY_FILE" 2>/dev/null | head -1)
    [ -z "$has_file_mod" ] && count=$((count + 1))
  done
fi

if [ -n "$extension_counts" ] && [ "$total" -gt 0 ] 2>/dev/null; then
  dominant=$(echo "$extension_counts" | awk -v t="$total" '$1 * 100 / t >= 60' | wc -l | tr -d ' ')
  count=$((count + dominant))
fi

if [ -d "$SKILLS_DIR" ] && [ -n "$unused" ]; then
  count=$((count + 1))
fi

echo ""
echo "---"
echo "Patterns detected: $count"
if [ "$count" -gt 0 ]; then
  echo "Review these draft instincts before adding to .claude/instincts.md"
fi

exit 0
