#!/bin/bash
# PDS PostToolUse hook for worker agent — lint/format check after Write|Edit.
# Scoped to worker agent lifetime via frontmatter hooks.
# Input: JSON on stdin with tool_name, tool_input (file_path), cwd.

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
  exit 0
fi

EXT="${FILE##*.}"

case "$EXT" in
  sh|bash)
    if command -v shellcheck >/dev/null 2>&1; then
      shellcheck "$FILE" 2>&1 | head -5 || true
    fi
    ;;
  py)
    if command -v python3 >/dev/null 2>&1; then
      python3 -m py_compile "$FILE" 2>&1 || true
    fi
    ;;
  js|ts|jsx|tsx)
    if command -v npx >/dev/null 2>&1 && [ -f "$(dirname "$FILE")/node_modules/.bin/eslint" ]; then
      npx eslint --no-error-on-unmatched-pattern "$FILE" 2>&1 | head -5 || true
    fi
    ;;
esac

exit 0
