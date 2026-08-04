#!/usr/bin/env bash
# Tests for the SubagentStart roster-check hook.
#
# The hook must recognise namespaced spawns (`pds:worker`), because that is what
# Claude Code actually reports for plugin-provided agents. Matching bare names
# only inverts the signal: it warns on every real spawn and stays quiet on
# genuinely unknown types. See #181.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/../scripts/roster-check.sh"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

RED=$'\033[1;31m'; GREEN=$'\033[1;32m'; NC=$'\033[0m'
pass=0; fail=0

ok()  { echo "  ${GREEN}✓${NC} PASS: $1"; pass=$((pass+1)); }
bad() { echo "  ${RED}✗${NC} FAIL: $1"; fail=$((fail+1)); }

# Runs the hook with a given agent_type; echoes "quiet" or "warn".
run_hook() {
  local agent_type="$1"
  local plugin_root="${2:-}"
  local err
  err="$(printf '{"agent_type":"%s","hook_event_name":"SubagentStart"}' "$agent_type" \
        | CLAUDE_PLUGIN_ROOT="$plugin_root" sh "$HOOK" 2>&1 >/dev/null)"
  if [ -z "$err" ]; then echo "quiet"; else echo "warn"; fi
}

expect() {
  local label="$1" got="$2" want="$3"
  if [ "$got" = "$want" ]; then ok "$label"; else bad "$label (want $want, got $got)"; fi
}

command -v jq >/dev/null 2>&1 || { echo "jq required"; exit 1; }

echo ""
echo "Test: roster-check hook (SubagentStart)"

# --- namespaced roster, derived from agents/ on disk ---
for a in orchestrator worker validator researcher reviewer documenter scout auditor shepherd; do
  expect "pds:$a recognised (derived roster)" "$(run_hook "pds:$a" "$PLUGIN_ROOT")" "quiet"
done

# --- namespaced roster, static fallback (no CLAUDE_PLUGIN_ROOT) ---
expect "pds:worker recognised (fallback list)"   "$(run_hook 'pds:worker')"   "quiet"
expect "pds:shepherd recognised (fallback list)" "$(run_hook 'pds:shepherd')" "quiet"

# --- #181 regression: the namespaced form is the one that actually occurs ---
expect "#181 guard: pds:orchestrator does not warn" "$(run_hook 'pds:orchestrator' "$PLUGIN_ROOT")" "quiet"

# --- bare names still accepted (project-scope agents resolve unprefixed) ---
expect "bare worker still recognised" "$(run_hook 'worker' "$PLUGIN_ROOT")" "quiet"

# --- built-ins ---
expect "general-purpose recognised" "$(run_hook 'general-purpose' "$PLUGIN_ROOT")" "quiet"
expect "Explore recognised"         "$(run_hook 'Explore' "$PLUGIN_ROOT")"         "quiet"

# --- genuinely unknown types must still warn ---
expect "unknown type warns"        "$(run_hook 'definitely-not-an-agent' "$PLUGIN_ROOT")" "warn"
expect "unknown pds: type warns"   "$(run_hook 'pds:not-an-agent' "$PLUGIN_ROOT")"        "warn"
expect "empty type warns"          "$(run_hook '' "$PLUGIN_ROOT")"                        "warn"

# --- shared-rules is a mixin, never spawnable ---
expect "shared-rules warns (not an agent)" "$(run_hook 'pds:shared-rules' "$PLUGIN_ROOT")" "warn"

# --- never blocks, whatever happens ---
printf '{"agent_type":"nonsense"}' | CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" sh "$HOOK" >/dev/null 2>&1
if [ $? -eq 0 ]; then ok "always exits 0 (never blocks a spawn)"; else bad "hook exited non-zero"; fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$fail" -eq 0 ]; then
  echo "  ${GREEN}✓${NC} All $pass roster-check tests passed"
  exit 0
fi
echo "  ${RED}✗${NC} $fail of $((pass+fail)) roster-check tests failed"
exit 1
