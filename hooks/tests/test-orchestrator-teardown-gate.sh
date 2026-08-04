#!/usr/bin/env bash
# Unit tests for orchestrator-teardown-gate.sh (the Stop-hook teardown gate).
# Exercises the phase-based pass-through fix (Stop fires on every orchestrator
# turn-end, not just intended teardown — see docs/adr/0007) with real fixture
# directories, no live Claude Code session required.
# Usage: bash hooks/tests/test-orchestrator-teardown-gate.sh
# Exit 0 = all pass, exit 1 = any fail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
GATE="$SCRIPT_DIR/../scripts/orchestrator-teardown-gate.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
RESET='\033[0m'

PASS=0
FAIL=0

pass() { printf "${GREEN}PASS${RESET} %s\n" "$1"; PASS=$((PASS + 1)); }
fail() { printf "${RED}FAIL${RESET} %s\n" "$1"; FAIL=$((FAIL + 1)); }

# Build a fresh fixture dir with .claude/swarm/, return its path via stdout.
new_fixture() {
  local dir
  dir=$(mktemp -d)
  mkdir -p "$dir/.claude/swarm"
  echo "$dir"
}

run_gate() {
  local cwd="$1"
  GATE_ERR=$(printf '{"cwd": "%s"}' "$cwd" | bash "$GATE" 2>&1 1>/dev/null)
  GATE_RC=$?
}

assert_allow() {
  local name="$1" cwd="$2"
  run_gate "$cwd"
  if [ "$GATE_RC" -eq 0 ]; then
    pass "$name"
  else
    fail "$name — expected exit 0 (allow), got rc=$GATE_RC stderr='$GATE_ERR'"
  fi
}

assert_block() {
  local name="$1" cwd="$2" expect_substr="$3"
  run_gate "$cwd"
  if [ "$GATE_RC" -eq 2 ] && echo "$GATE_ERR" | grep -qF "$expect_substr"; then
    pass "$name"
  else
    fail "$name — expected exit 2 (block) containing '$expect_substr', got rc=$GATE_RC stderr='$GATE_ERR'"
  fi
}

satisfy_artifacts() {
  local dir="$1"
  touch "$dir/.claude/swarm/validation-report.md"
  touch "$dir/.claude/swarm/review-report.md"
  touch "$dir/.claude/swarm/scout-report.md"
  mkdir -p "$dir/docs/swarm-reports"
}

# --- No swarm active ---

FIXTURE=$(mktemp -d)
assert_allow "no .claude/swarm/ dir — always allow" "$FIXTURE"
rm -rf "$FIXTURE"

# --- Phase pass-through (the core regression fix — Stop fires every turn-end) ---

for PHASE in plan decompose dispatch validate consolidate; do
  FIXTURE=$(new_fixture)
  echo "$PHASE" > "$FIXTURE/.claude/swarm/phase"
  assert_allow "phase=$PHASE with no artifacts — allow (not a teardown attempt)" "$FIXTURE"
  rm -rf "$FIXTURE"
done

# --- Phase = knowledge: full artifact/worktree/archive enforcement ---

FIXTURE=$(new_fixture)
echo "knowledge" > "$FIXTURE/.claude/swarm/phase"
assert_block "phase=knowledge, no reports — block" "$FIXTURE" "missing required phase artifacts"
rm -rf "$FIXTURE"

FIXTURE=$(new_fixture)
echo "knowledge" > "$FIXTURE/.claude/swarm/phase"
touch "$FIXTURE/.claude/swarm/validation-report.md"
assert_block "phase=knowledge, 1 of 3 reports — block" "$FIXTURE" "missing required phase artifacts"
rm -rf "$FIXTURE"

FIXTURE=$(new_fixture)
echo "knowledge" > "$FIXTURE/.claude/swarm/phase"
satisfy_artifacts "$FIXTURE"
mkdir -p "$FIXTURE/.worktrees/leftover-worker"
assert_block "phase=knowledge, reports ok, dirty .worktrees/ — block" "$FIXTURE" "worktrees still exist"
rm -rf "$FIXTURE"

FIXTURE=$(new_fixture)
echo "knowledge" > "$FIXTURE/.claude/swarm/phase"
touch "$FIXTURE/.claude/swarm/validation-report.md"
touch "$FIXTURE/.claude/swarm/review-report.md"
touch "$FIXTURE/.claude/swarm/scout-report.md"
# docs/swarm-reports/ deliberately absent
assert_block "phase=knowledge, reports+worktrees ok, no archive dir — block" "$FIXTURE" "docs/swarm-reports/ does not exist"
rm -rf "$FIXTURE"

FIXTURE=$(new_fixture)
echo "knowledge" > "$FIXTURE/.claude/swarm/phase"
satisfy_artifacts "$FIXTURE"
assert_allow "phase=knowledge, everything satisfied — allow" "$FIXTURE"
rm -rf "$FIXTURE"

# --- Defense-in-depth: phase file missing or malformed ---

FIXTURE=$(new_fixture)
# no phase file at all — falls through to artifact checks (WARNING path)
assert_block "phase file missing, no reports — falls through to block" "$FIXTURE" "missing required phase artifacts"
rm -rf "$FIXTURE"

FIXTURE=$(new_fixture)
touch "$FIXTURE/.claude/swarm/phase"  # empty file
assert_block "phase file empty — block" "$FIXTURE" "is empty"
rm -rf "$FIXTURE"

FIXTURE=$(new_fixture)
echo "not-a-real-phase" > "$FIXTURE/.claude/swarm/phase"
assert_block "phase file unrecognized value — block" "$FIXTURE" "Unrecognized phase"
rm -rf "$FIXTURE"

# --- Summary ---

echo
echo "orchestrator-teardown-gate.sh: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
