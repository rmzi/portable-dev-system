#!/bin/bash
# PDS Stop hook for validator agent — ensures validation report was produced.
# Defined in validator.md frontmatter; auto-converts to SubagentStop.
# Uses JSON decision control: {"decision": "block", "reason": "..."} to prevent stopping.

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

if [ -z "$CWD" ]; then
  exit 0
fi

# Check that the last assistant message mentions a validation report
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty')
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  # Look for validation report markers in the transcript
  if tail -20 "$TRANSCRIPT" | grep -qi "validation report\|test results\|all.*pass\|tests passed"; then
    exit 0
  fi
fi

# Fallback: check if tests exist and pass
if [ -f "$CWD/package.json" ] && jq -e '.scripts.test' "$CWD/package.json" >/dev/null 2>&1; then
  if ! (cd "$CWD" && npm test 2>&1) >/dev/null 2>&1; then
    jq -n '{decision: "block", reason: "Tests are failing. Produce a validation report before stopping."}'
    exit 0
  fi
elif [ -f "$CWD/Makefile" ] && grep -q '^test:' "$CWD/Makefile" 2>/dev/null; then
  if ! (cd "$CWD" && make test 2>&1) >/dev/null 2>&1; then
    jq -n '{decision: "block", reason: "Tests are failing. Produce a validation report before stopping."}'
    exit 0
  fi
fi

exit 0
