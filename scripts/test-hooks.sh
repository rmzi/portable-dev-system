#!/usr/bin/env bash
# PDS Hook Unit Tests
# Tests secret-scrub.sh (PreToolUse) and mcp-secret-scrub.sh (PostToolUse)
# Usage: bash scripts/test-hooks.sh
# Exit 0 = all pass, exit 1 = any fail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
HOOK_DIR="$SCRIPT_DIR/../hooks/scripts"
SECRET_SCRUB="$HOOK_DIR/secret-scrub.sh"
MCP_SCRUB="$HOOK_DIR/mcp-secret-scrub.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
RESET='\033[0m'

PASS=0
FAIL=0

pass() { printf "${GREEN}PASS${RESET} %s\n" "$1"; PASS=$((PASS + 1)); }
fail() { printf "${RED}FAIL${RESET} %s\n" "$1"; FAIL=$((FAIL + 1)); }

# Run hook script with JSON from stdin, capture stdout + exit code
# Sets globals: HOOK_OUT, HOOK_RC
run_hook() {
  local script="$1" input="$2"
  HOOK_RC=0
  HOOK_OUT=$(echo "$input" | bash "$script" 2>/dev/null) || HOOK_RC=$?
}

# Assert hook passes through: exit 0, no stdout
assert_passthrough() {
  local name="$1" script="$2" input="$3"
  run_hook "$script" "$input"
  if [ "$HOOK_RC" -eq 0 ] && [ -z "$HOOK_OUT" ]; then
    pass "$name"
  else
    fail "$name — expected pass-through (no stdout, exit 0), got rc=$HOOK_RC out='$HOOK_OUT'"
  fi
}

# Assert hook rewrites command: exit 0, stdout contains updatedInput
assert_rewritten() {
  local name="$1" script="$2" input="$3"
  run_hook "$script" "$input"
  if [ "$HOOK_RC" -eq 0 ] && echo "$HOOK_OUT" | grep -q 'updatedInput'; then
    pass "$name"
  else
    fail "$name — expected updatedInput in stdout, got rc=$HOOK_RC out='$HOOK_OUT'"
  fi
}

# Assert MCP hook scrubs output: exit 0, stdout contains updatedMCPToolOutput
assert_scrubbed() {
  local name="$1" script="$2" input="$3"
  run_hook "$script" "$input"
  if [ "$HOOK_RC" -eq 0 ] && echo "$HOOK_OUT" | grep -q 'updatedMCPToolOutput'; then
    pass "$name"
  else
    fail "$name — expected updatedMCPToolOutput in stdout, got rc=$HOOK_RC out='$HOOK_OUT'"
  fi
}

SECRET_GUARD="$HOOK_DIR/secret-guard.sh"

# Assert hook blocks: exit 2
assert_blocked() {
  local name="$1" script="$2" input="$3"
  HOOK_RC=0
  HOOK_OUT=$(echo "$input" | bash "$script" 2>/dev/null) || HOOK_RC=$?
  if [ "$HOOK_RC" -eq 2 ]; then
    pass "$name"
  else
    fail "$name — expected exit 2 (blocked), got rc=$HOOK_RC"
  fi
}

# ─────────────────────────────────────────────────────────────
# secret-scrub.sh — PreToolUse Bash hook
# ─────────────────────────────────────────────────────────────
printf "${BOLD}secret-scrub.sh${RESET}\n"

# Pass-through: benign commands must not be rewritten
assert_passthrough "ls → pass through" "$SECRET_SCRUB" \
  '{"tool_input": {"command": "ls"}}'

assert_passthrough "git status → pass through" "$SECRET_SCRUB" \
  '{"tool_input": {"command": "git status"}}'

assert_passthrough "npm install → pass through" "$SECRET_SCRUB" \
  '{"tool_input": {"command": "npm install"}}'

# Rewrite: sensitive commands must be wrapped in scrubbing pipeline
assert_rewritten "env → rewritten" "$SECRET_SCRUB" \
  '{"tool_input": {"command": "env"}}'

assert_rewritten "printenv → rewritten" "$SECRET_SCRUB" \
  '{"tool_input": {"command": "printenv"}}'

assert_rewritten "cat .env → rewritten" "$SECRET_SCRUB" \
  '{"tool_input": {"command": "cat .env"}}'

# Note: pattern is `\$\{?(SECRET|TOKEN|KEY|ACCESS_KEY|...)`
# Variable name must start with a recognized keyword after $
assert_rewritten "echo \$SECRET_KEY → rewritten" "$SECRET_SCRUB" \
  '{"tool_input": {"command": "echo $SECRET_KEY"}}'

assert_rewritten "curl → rewritten" "$SECRET_SCRUB" \
  '{"tool_input": {"command": "curl -s https://api.example.com"}}'

assert_rewritten "export -p → rewritten" "$SECRET_SCRUB" \
  '{"tool_input": {"command": "export -p"}}'

echo ""

# ─────────────────────────────────────────────────────────────
# mcp-secret-scrub.sh — PostToolUse MCP hook
# ─────────────────────────────────────────────────────────────
printf "${BOLD}mcp-secret-scrub.sh${RESET}\n"

# Pass-through: non-MCP tools are ignored entirely
assert_passthrough "Bash tool → pass through" "$MCP_SCRUB" \
  '{"tool_name": "Bash", "tool_output": "some output"}'

# Pass-through: MCP tool output with no secrets exits 0 silently
assert_passthrough "mcp__ tool with no secrets → pass through" "$MCP_SCRUB" \
  '{"tool_name": "mcp__github__list_repos", "tool_output": {"repos": ["foo", "bar"]}}'

# Scrub: MCP tool output containing a secret token must be redacted
# sk- token: prefix + 20+ alphanumeric chars
assert_scrubbed "mcp__ tool with sk- token → scrubbed" "$MCP_SCRUB" \
  '{"tool_name": "mcp__github__get_token", "tool_output": {"token": "sk-abc123def456ghi789jkl012mno345pqr"}}'

echo ""

# ─────────────────────────────────────────────────────────────
# secret-guard.sh — PreToolUse Bash hook (blocker)
# ─────────────────────────────────────────────────────────────
printf "${BOLD}secret-guard.sh${RESET}\n"

# Pass-through: benign commands
assert_passthrough "ls → allow" "$SECRET_GUARD" \
  '{"tool_input": {"command": "ls"}}'

assert_passthrough "git status → allow" "$SECRET_GUARD" \
  '{"tool_input": {"command": "git status"}}'

assert_passthrough "echo hello → allow" "$SECRET_GUARD" \
  '{"tool_input": {"command": "echo hello"}}'

# Block: full environment dumps
assert_blocked "env → blocked" "$SECRET_GUARD" \
  '{"tool_input": {"command": "env"}}'

assert_blocked "printenv → blocked" "$SECRET_GUARD" \
  '{"tool_input": {"command": "printenv"}}'

assert_blocked "export -p → blocked" "$SECRET_GUARD" \
  '{"tool_input": {"command": "export -p"}}'

# Block: echoing secret variables
assert_blocked "echo \$AWS_SECRET → blocked" "$SECRET_GUARD" \
  '{"tool_input": {"command": "echo $AWS_SECRET_ACCESS_KEY"}}'

# Block: process environ reads
assert_blocked "/proc/self/environ → blocked" "$SECRET_GUARD" \
  '{"tool_input": {"command": "cat /proc/self/environ"}}'

# Block: curl with secret header
assert_blocked "curl with Bearer token → blocked" "$SECRET_GUARD" \
  '{"tool_input": {"command": "curl -H \"Authorization: Bearer $AUTH_TOKEN\" https://api.example.com"}}'

echo ""

# ─────────────────────────────────────────────────────────────
# session-start.sh — stale artifact detection
# ─────────────────────────────────────────────────────────────
printf "${BOLD}session-start.sh (stale detection)${RESET}\n"

SESSION_START="$HOOK_DIR/session-start.sh"

# Test: .pds-version present → warning in output
TMPD=$(mktemp -d "${TMPDIR:-/tmp}/pds-test.XXXXXX")
mkdir -p "$TMPD/.claude"
echo "2.7.1" > "$TMPD/.claude/.pds-version"
OUT=$(cd "$TMPD" && CLAUDE_PLUGIN_ROOT="" CLAUDE_ENV_FILE="" bash "$SESSION_START" 2>/dev/null || true)
if echo "$OUT" | grep -q "STALE"; then
  pass ".pds-version present → stale warning"
else
  fail ".pds-version present → expected STALE in output, got: $OUT"
fi
rm -rf "$TMPD"

# Test: clean directory → no warning
TMPD=$(mktemp -d "${TMPDIR:-/tmp}/pds-test.XXXXXX")
OUT=$(cd "$TMPD" && CLAUDE_PLUGIN_ROOT="" CLAUDE_ENV_FILE="" bash "$SESSION_START" 2>/dev/null || true)
if echo "$OUT" | grep -q "STALE"; then
  fail "clean dir → unexpected STALE warning in: $OUT"
else
  pass "clean dir → no stale warning"
fi
rm -rf "$TMPD"

echo ""

# ─────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────
TOTAL=$((PASS + FAIL))
printf "─────────────────────────────\n"
printf "Results: %d/%d passed\n" "$PASS" "$TOTAL"
if [ "$FAIL" -gt 0 ]; then
  printf "${RED}%d test(s) failed${RESET}\n" "$FAIL"
  exit 1
else
  printf "${GREEN}All tests passed${RESET}\n"
  exit 0
fi
