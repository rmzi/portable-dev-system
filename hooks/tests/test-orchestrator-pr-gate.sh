#!/usr/bin/env bash
# Unit tests for orchestrator-pr-gate.sh, including the #172 fix: a block
# must warn explicitly when the blocked command chained other work (e.g. a
# heredoc PR-body write) that was discarded along with the block.
# Usage: bash hooks/tests/test-orchestrator-pr-gate.sh
# Exit 0 = all pass, exit 1 = any fail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
GATE="$SCRIPT_DIR/../scripts/orchestrator-pr-gate.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
RESET='\033[0m'

PASS=0
FAIL=0

pass() { printf "${GREEN}PASS${RESET} %s\n" "$1"; PASS=$((PASS + 1)); }
fail() { printf "${RED}FAIL${RESET} %s\n" "$1"; FAIL=$((FAIL + 1)); }

new_fixture() {
  local dir
  dir=$(mktemp -d)
  mkdir -p "$dir/.claude/swarm"
  echo "$dir"
}

satisfy_artifacts() {
  touch "$1/.claude/swarm/validation-report.md"
  touch "$1/.claude/swarm/review-report.md"
}

run_gate() {
  local cwd="$1" command="$2"
  local input
  input=$(python3 -c "import json,sys; print(json.dumps({'cwd': sys.argv[1], 'tool_input': {'command': sys.argv[2]}}))" "$cwd" "$command")
  GATE_ERR=$(printf '%s' "$input" | bash "$GATE" 2>&1 1>/dev/null)
  GATE_RC=$?
}

assert_allow() {
  local name="$1" cwd="$2" command="$3"
  run_gate "$cwd" "$command"
  if [ "$GATE_RC" -eq 0 ]; then
    pass "$name"
  else
    fail "$name — expected exit 0 (allow), got rc=$GATE_RC stderr='$GATE_ERR'"
  fi
}

assert_block() {
  local name="$1" cwd="$2" command="$3" expect_substr="$4"
  run_gate "$cwd" "$command"
  if [ "$GATE_RC" -eq 2 ] && echo "$GATE_ERR" | grep -qF "$expect_substr"; then
    pass "$name"
  else
    fail "$name — expected exit 2 containing '$expect_substr', got rc=$GATE_RC stderr='$GATE_ERR'"
  fi
}

assert_block_missing() {
  local name="$1" cwd="$2" command="$3" missing_substr="$4"
  run_gate "$cwd" "$command"
  if [ "$GATE_RC" -eq 2 ] && ! echo "$GATE_ERR" | grep -qF "$missing_substr"; then
    pass "$name"
  else
    fail "$name — expected exit 2 NOT containing '$missing_substr', got rc=$GATE_RC stderr='$GATE_ERR'"
  fi
}

# --- Pass-through: not a gh pr create command ---

FIXTURE=$(new_fixture)
assert_allow "non-'gh pr create' command — always allow" "$FIXTURE" "git status"
rm -rf "$FIXTURE"

# --- Pass-through: no swarm active ---

FIXTURE=$(mktemp -d)
assert_allow "no .claude/swarm/ dir — always allow" "$FIXTURE" "gh pr create --title x"
rm -rf "$FIXTURE"

# --- Phase gate ---

FIXTURE=$(new_fixture)
echo "dispatch" > "$FIXTURE/.claude/swarm/phase"
assert_block "phase=dispatch — block, too early" "$FIXTURE" "gh pr create --title x" "[PDS GATE] BLOCKED: Cannot create PR in phase"
rm -rf "$FIXTURE"

# --- Artifact gate ---

FIXTURE=$(new_fixture)
echo "consolidate" > "$FIXTURE/.claude/swarm/phase"
assert_block "phase=consolidate, no reports — block" "$FIXTURE" "gh pr create --title x" "[PDS GATE] BLOCKED: Cannot create PR — missing required phase artifacts"
rm -rf "$FIXTURE"

FIXTURE=$(new_fixture)
echo "consolidate" > "$FIXTURE/.claude/swarm/phase"
satisfy_artifacts "$FIXTURE"
assert_allow "phase=consolidate, reports present — allow" "$FIXTURE" "gh pr create --title x"
rm -rf "$FIXTURE"

# --- #172: lost-write note on chained commands ---

FIXTURE=$(new_fixture)
echo "consolidate" > "$FIXTURE/.claude/swarm/phase"
assert_block "heredoc-chained command, blocked — warns about lost write" "$FIXTURE" \
  'cat <<EOF > /tmp/body.md
body text
EOF
gh pr create --body-file /tmp/body.md' \
  "did NOT run either"
rm -rf "$FIXTURE"

FIXTURE=$(new_fixture)
echo "consolidate" > "$FIXTURE/.claude/swarm/phase"
assert_block_missing "single, unchained command, blocked — no lost-write note" "$FIXTURE" \
  "gh pr create --title x" \
  "did NOT run either"
rm -rf "$FIXTURE"

FIXTURE=$(new_fixture)
echo "dispatch" > "$FIXTURE/.claude/swarm/phase"
assert_block "heredoc-chained command, blocked at phase gate — also warns" "$FIXTURE" \
  'cat <<EOF > /tmp/body.md
body text
EOF
gh pr create --body-file /tmp/body.md' \
  "did NOT run either"
rm -rf "$FIXTURE"

# --- Summary ---

echo
echo "orchestrator-pr-gate.sh: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
