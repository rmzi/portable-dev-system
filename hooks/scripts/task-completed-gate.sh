#!/bin/bash
# PDS TaskCompleted hook — blocks task completion if tests are failing.
# Exit 0 = allow completion, Exit 2 = block (stderr fed back to agent).
# Input: JSON on stdin with task_id, task_subject, task_description, cwd.

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

if [ -z "$CWD" ]; then
  exit 0
fi

# Check for common test runners and run if available
if [ -f "$CWD/package.json" ] && jq -e '.scripts.test' "$CWD/package.json" >/dev/null 2>&1; then
  if ! (cd "$CWD" && npm test 2>&1) >/dev/null 2>&1; then
    TASK=$(echo "$INPUT" | jq -r '.task_subject // "unknown"')
    echo "Tests failing. Fix tests before completing: $TASK" >&2
    exit 2
  fi
elif [ -f "$CWD/Makefile" ] && grep -q '^test:' "$CWD/Makefile" 2>/dev/null; then
  if ! (cd "$CWD" && make test 2>&1) >/dev/null 2>&1; then
    TASK=$(echo "$INPUT" | jq -r '.task_subject // "unknown"')
    echo "Tests failing. Fix tests before completing: $TASK" >&2
    exit 2
  fi
elif [ -f "$CWD/pytest.ini" ] || [ -f "$CWD/conftest.py" ] || ([ -f "$CWD/pyproject.toml" ] && grep -qE '^\[tool\.pytest|^\[pytest\]' "$CWD/pyproject.toml" 2>/dev/null); then
  PYTEST_CMD=""
  if command -v pytest >/dev/null 2>&1; then
    PYTEST_CMD="pytest"
  elif command -v python3 >/dev/null 2>&1; then
    PYTEST_CMD="python3 -m pytest"
  elif command -v python >/dev/null 2>&1; then
    PYTEST_CMD="python -m pytest"
  fi
  if [ -n "$PYTEST_CMD" ]; then
    if ! (cd "$CWD" && $PYTEST_CMD 2>&1) >/dev/null 2>&1; then
      TASK=$(echo "$INPUT" | jq -r '.task_subject // "unknown"')
      echo "Tests failing. Fix tests before completing: $TASK" >&2
      exit 2
    fi
  fi
fi

exit 0
