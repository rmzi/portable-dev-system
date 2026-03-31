#!/bin/sh
# PDS UserPromptSubmit hook — suggests relevant PDS skills based on prompt keywords.
# Opt-out via PDS_PROMPT_HINTS=0.

[ "$PDS_PROMPT_HINTS" = "0" ] && exit 0

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // .message // empty')

[ -z "$PROMPT" ] && exit 0

LOWER=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')

HINTS=""

case "$LOWER" in
  *bug*|*fix*|*error*|*broken*|*crash*|*issue*) HINTS="/pds:bugfix" ;;
esac

case "$LOWER" in
  *ship*|*deploy*|*push*|*release*|*publish*)
    [ -n "$HINTS" ] && HINTS="$HINTS, /pds:bcp" || HINTS="/pds:bcp"
    ;;
esac

case "$LOWER" in
  *review*|*pr*|*pull*request*)
    [ -n "$HINTS" ] && HINTS="$HINTS, /pds:verify + /pds:finish" || HINTS="/pds:verify + /pds:finish"
    ;;
esac

case "$LOWER" in
  *plan*|*design*|*architect*)
    [ -n "$HINTS" ] && HINTS="$HINTS, /pds:grill" || HINTS="/pds:grill"
    ;;
esac

case "$LOWER" in
  *parallel*|*swarm*|*multi-agent*|*team*|*concurrent*)
    [ -n "$HINTS" ] && HINTS="$HINTS, /pds:swarm" || HINTS="/pds:swarm"
    ;;
esac

case "$LOWER" in
  *rebase*|*merge*|*conflict*)
    [ -n "$HINTS" ] && HINTS="$HINTS, /pds:merge" || HINTS="/pds:merge"
    ;;
esac

case "$LOWER" in
  *test*|*coverage*|*spec*|*tdd*)
    [ -n "$HINTS" ] && HINTS="$HINTS, /pds:bugfix" || HINTS="/pds:bugfix"
    ;;
esac

# No keyword matches
[ -z "$HINTS" ] && exit 0

python3 -c "
import json, sys
hints = sys.argv[1]
print(json.dumps({
    'hookSpecificOutput': {
        'hookEventName': 'UserPromptSubmit',
        'additionalContext': 'PDS skill hint: Consider using ' + hints + ' for this task. Read the skill first.'
    }
}))
" "$HINTS" 2>/dev/null || exit 0

exit 0
