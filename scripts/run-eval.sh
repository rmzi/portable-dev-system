#!/usr/bin/env bash
# run-eval.sh — Statistical skill evaluation runner
#
# Runs EVAL.md scenarios N times via claude CLI, grades each with
# LLM-as-judge, reports pass rates with Wilson score confidence intervals.
#
# Usage:
#   ./scripts/run-eval.sh <skill> [--runs N] [--model MODEL]
#
# Examples:
#   ./scripts/run-eval.sh grill              # 5 runs, haiku
#   ./scripts/run-eval.sh grill --runs 10    # 10 runs
#   ./scripts/run-eval.sh grill --model sonnet  # sonnet for execution
#
# Requires: claude CLI, bc

set -euo pipefail

# --- Defaults ---
RUNS=5
EXEC_MODEL="haiku"
GRADE_MODEL="haiku"

# --- Parse args ---
SKILL="${1:?Usage: run-eval.sh <skill> [--runs N] [--model MODEL]}"
shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    --runs)  RUNS="$2"; shift 2 ;;
    --model) EXEC_MODEL="$2"; shift 2 ;;
    --grade-model) GRADE_MODEL="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

# --- Locate files ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_FILE="${REPO_ROOT}/skills/${SKILL}/SKILL.md"
EVAL_FILE="${REPO_ROOT}/skills/${SKILL}/EVAL.md"

[[ -f "$SKILL_FILE" ]] || { echo "Error: $SKILL_FILE not found"; exit 1; }
[[ -f "$EVAL_FILE" ]] || { echo "Error: $EVAL_FILE not found"; exit 1; }

command -v claude >/dev/null 2>&1 || { echo "Error: claude CLI not found"; exit 1; }
command -v bc >/dev/null 2>&1 || { echo "Error: bc not found"; exit 1; }

SKILL_CONTENT="$(cat "$SKILL_FILE")"

# --- Wilson score 95% CI ---
# Returns "lower%-upper%" for n trials with k successes
wilson_ci() {
  local n=$1 k=$2
  if [[ $n -eq 0 ]]; then echo "0%-0%"; return; fi
  bc -l <<CALC
    scale=4
    z = 1.96
    p = $k / $n
    d = 1 + (z * z / $n)
    c = (p + z * z / (2 * $n)) / d
    m = z * sqrt(p * (1 - p) / $n + z * z / (4 * $n * $n)) / d
    lo = c - m
    hi = c + m
    if (lo < 0) lo = 0
    if (hi > 1) hi = 1
    scale=0
    lo_pct = lo * 100 / 1
    hi_pct = hi * 100 / 1
    print lo_pct, "%-", hi_pct, "%"
CALC
}

# --- Extract scenarios ---
# Outputs scenario names, one per line
list_scenarios() {
  grep '^### Scenario:' "$EVAL_FILE" | sed 's/^### Scenario: //'
}

# Extract a scenario block (from its header to the next ### or ## or EOF)
get_scenario_block() {
  local name="$1"
  awk -v name="$name" '
    $0 ~ "^### Scenario: " name { found=1; next }
    found && /^###/ { exit }
    found && /^## [^#]/ { exit }
    found { print }
  ' "$EVAL_FILE"
}

# Extract field value from a scenario block (e.g., "Prompt", "Setup")
get_field() {
  local block="$1" field="$2"
  echo "$block" | sed -n "s/^\*\*${field}:\*\* //p"
}

# Extract checklist items under a heading (Expected or Anti-patterns)
get_checklist() {
  local block="$1" heading="$2"
  echo "$block" | awk -v h="$heading" '
    $0 ~ "^\\*\\*" h ":\\*\\*" { found=1; next }
    found && /^\*\*/ { exit }
    found && /^- \[ \]/ { sub(/^- \[ \] /, ""); print }
  '
}

# --- Main ---
echo "=== PDS Eval: /pds:${SKILL} ==="
echo "Model: ${EXEC_MODEL} | Grade: ${GRADE_MODEL} | Runs: ${RUNS} | Date: $(date +%Y-%m-%d)"
echo ""

TOTAL_SCENARIOS=0
TOTAL_PASS=0
TOTAL_FAIL=0
SUMMARY=""

while IFS= read -r SCENARIO_NAME; do
  TOTAL_SCENARIOS=$((TOTAL_SCENARIOS + 1))
  echo "--- Scenario: ${SCENARIO_NAME} ---"

  BLOCK="$(get_scenario_block "$SCENARIO_NAME")"
  SETUP="$(get_field "$BLOCK" "Setup")"
  PROMPT="$(get_field "$BLOCK" "Prompt")"
  EXPECTED="$(get_checklist "$BLOCK" "Expected")"
  ANTI_PATTERNS="$(get_checklist "$BLOCK" "Anti-patterns")"

  if [[ -z "$PROMPT" ]]; then
    echo "  SKIP: no prompt found"
    echo ""
    continue
  fi

  # Number the criteria for the grading prompt
  EXPECTED_NUMBERED=""
  i=1
  while IFS= read -r line; do
    [[ -n "$line" ]] && EXPECTED_NUMBERED="${EXPECTED_NUMBERED}${i}. ${line}"$'\n'
    i=$((i + 1))
  done <<< "$EXPECTED"

  ANTI_NUMBERED=""
  i=1
  while IFS= read -r line; do
    [[ -n "$line" ]] && ANTI_NUMBERED="${ANTI_NUMBERED}${i}. ${line}"$'\n'
    i=$((i + 1))
  done <<< "$ANTI_PATTERNS"

  SCENARIO_PASS=0
  SCENARIO_FAIL=0

  for ((run=1; run<=RUNS; run++)); do
    printf "  Run %d/%d... " "$run" "$RUNS"

    # Step 1: Execute the scenario
    EXEC_PROMPT="You have this skill loaded:

<skill>
${SKILL_CONTENT}
</skill>

Context: ${SETUP}

Follow this skill exactly for the following task:
${PROMPT}

Produce the complete skill output."

    AGENT_OUTPUT="$(echo "$EXEC_PROMPT" | claude -p --model "$EXEC_MODEL" 2>/dev/null)" || {
      echo "FAIL (claude execution error)"
      SCENARIO_FAIL=$((SCENARIO_FAIL + 1))
      continue
    }

    # Step 2: Grade with LLM-as-judge
    GRADE_PROMPT="You are a strict eval grader. Grade this agent output against the criteria below.

<agent_output>
${AGENT_OUTPUT}
</agent_output>

Expected behaviors (ALL must be observed for PASS):
${EXPECTED_NUMBERED}
Anti-patterns (NONE should be detected for PASS):
${ANTI_NUMBERED}
Check each expected behavior against the output. Check each anti-pattern.
PASS only if ALL expected behaviors are observed AND NO anti-patterns detected.

Your final line MUST be exactly one of:
VERDICT: pass
VERDICT: fail | <brief reason>"

    GRADE_RESULT="$(echo "$GRADE_PROMPT" | claude -p --model "$GRADE_MODEL" 2>/dev/null)" || {
      echo "FAIL (grading error)"
      SCENARIO_FAIL=$((SCENARIO_FAIL + 1))
      continue
    }

    # Step 3: Parse verdict from last VERDICT line
    VERDICT_LINE="$(echo "$GRADE_RESULT" | grep '^VERDICT:' | tail -1)" || VERDICT_LINE=""
    VERDICT="$(echo "$VERDICT_LINE" | awk -F': ' '{print $2}' | awk -F' \\|' '{print $1}' | tr -d '[:space:]')" || VERDICT="fail"
    REASON="$(echo "$VERDICT_LINE" | awk -F'\\| ' '{print $2}')" || REASON=""

    if [[ "$VERDICT" == "pass" ]]; then
      SCENARIO_PASS=$((SCENARIO_PASS + 1))
      echo "PASS"
    else
      SCENARIO_FAIL=$((SCENARIO_FAIL + 1))
      if [[ -n "$REASON" ]]; then
        echo "FAIL (${REASON})"
      else
        echo "FAIL"
      fi
    fi
  done

  TOTAL_PASS=$((TOTAL_PASS + SCENARIO_PASS))
  TOTAL_FAIL=$((TOTAL_FAIL + SCENARIO_FAIL))

  # Compute pass rate + Wilson CI
  RATE="$(echo "scale=0; ${SCENARIO_PASS} * 100 / ${RUNS}" | bc)"
  CI="$(wilson_ci "$RUNS" "$SCENARIO_PASS")"
  echo "  Result: ${SCENARIO_PASS}/${RUNS} (${RATE}%) | 95% CI: [${CI}]"
  echo ""

  SUMMARY="${SUMMARY}  ${SCENARIO_NAME}: ${SCENARIO_PASS}/${RUNS} (${RATE}%) [${CI}]"$'\n'
done < <(list_scenarios)

# --- Summary ---
echo "=== Summary ==="
echo "$SUMMARY"

TOTAL_RUNS=$((TOTAL_PASS + TOTAL_FAIL))
if [[ $TOTAL_RUNS -gt 0 ]]; then
  OVERALL_RATE="$(echo "scale=0; ${TOTAL_PASS} * 100 / ${TOTAL_RUNS}" | bc)"
  OVERALL_CI="$(wilson_ci "$TOTAL_RUNS" "$TOTAL_PASS")"
  echo "  Overall: ${TOTAL_PASS}/${TOTAL_RUNS} (${OVERALL_RATE}%) | 95% CI: [${OVERALL_CI}]"
fi
