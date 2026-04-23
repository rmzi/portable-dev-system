#!/usr/bin/env bash
# PDS MCP Secret Scrub — PostToolUse hook for MCP tools
# Scrubs secret patterns from MCP tool output before it reaches AI context.
# Philosophy: scrub don't block.

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

# Only process MCP tools
case "$TOOL_NAME" in
  mcp__*) ;;
  *) exit 0 ;;
esac

# Get tool output as compact JSON
TOOL_OUTPUT=$(echo "$INPUT" | jq -c '.tool_output // empty' 2>/dev/null)
[ -z "$TOOL_OUTPUT" ] && exit 0

# Apply secret scrubbing to the serialized JSON representation.
# Patterns match token values whether they appear as JSON string contents,
# plain text, or env-style KEY=value lines.
scrub() {
  echo "$1" | sed -E \
    -e 's/sk-[a-zA-Z0-9]{20,}/[REDACTED]/g' \
    -e 's/ghp_[a-zA-Z0-9]{36}/[REDACTED]/g' \
    -e 's/gho_[a-zA-Z0-9]{36}/[REDACTED]/g' \
    -e 's/github_pat_[a-zA-Z0-9_]{82}/[REDACTED]/g' \
    -e 's/AKIA[A-Z0-9]{16}/[REDACTED]/g' \
    -e 's/xoxb-[a-zA-Z0-9-]+/[REDACTED]/g' \
    -e 's/xoxp-[a-zA-Z0-9-]+/[REDACTED]/g' \
    -e 's/eyJ[a-zA-Z0-9_-]+\.eyJ[a-zA-Z0-9_-]+/[REDACTED]/g' \
    -e 's/SG\.[a-zA-Z0-9_-]+/[REDACTED]/g' \
    -e 's/sk_live_[a-zA-Z0-9]+/[REDACTED]/g' \
    -e 's/rk_live_[a-zA-Z0-9]+/[REDACTED]/g' \
    -e 's/([A-Z_]*(SECRET|TOKEN|KEY|PASSWORD|CREDENTIAL)[A-Z_]*=)[^"\\]+/\1[REDACTED]/g'
}

SCRUBBED=$(scrub "$TOOL_OUTPUT")

# Pass through if nothing changed
[ "$SCRUBBED" = "$TOOL_OUTPUT" ] && exit 0

# Parse back as JSON; fall back to string if the scrubbing broke JSON structure
SCRUBBED_JSON=$(echo "$SCRUBBED" | jq '.' 2>/dev/null || echo "$SCRUBBED" | jq -Rs '.')

jq -n --argjson output "$SCRUBBED_JSON" \
  '{"hookSpecificOutput":{"hookEventName":"PostToolUse","updatedMCPToolOutput":$output}}'
