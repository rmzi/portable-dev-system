#!/bin/sh
# PDS UserPromptSubmit hook — suggests relevant PDS skills based on prompt keywords.
#
# Hit-rate decay: tracks show→ignore ratio per skill at
# ${XDG_DATA_HOME:-~/.local/share}/pds/hints.json. After N consecutive ignores
# (configurable via hints.decay_after_ignores, default 3) the hint self-silences
# for that skill. "Ignore" is inferred: a hint was shown last turn but the
# user's next prompt didn't invoke the suggested skill.
#
# Opt-out via PDS_PROMPT_HINTS=0 or set hints.enabled=false in pds.config.yaml.

[ "$PDS_PROMPT_HINTS" = "0" ] && exit 0

cfg() {
  if command -v pds >/dev/null 2>&1; then
    value=$(pds config get "$1" 2>/dev/null)
    [ -n "$value" ] && { printf '%s' "$value"; return; }
  fi
  printf '%s' "$2"
}

[ "$(cfg hints.enabled true)" = "false" ] && exit 0

DECAY_ENABLED=$(cfg hints.hit_rate_decay true)
DECAY_AFTER=$(cfg hints.decay_after_ignores 3)
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
STATE_FILE="$XDG_DATA_HOME/pds/hints.json"
mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || true

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // .message // empty')
[ -z "$PROMPT" ] && exit 0
LOWER=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')

# Reconcile any previously-shown hint against this prompt — if user didn't
# invoke the skill we suggested, increment its ignore counter.
if [ "$DECAY_ENABLED" = "true" ] && [ -f "$STATE_FILE" ]; then
    python3 - "$STATE_FILE" "$LOWER" <<'PY' 2>/dev/null || true
import json, sys, os, re
state_file, prompt = sys.argv[1], sys.argv[2]
try:
    with open(state_file) as f:
        state = json.load(f)
except Exception:
    state = {"pending": None, "skills": {}}
pending = state.get("pending")
if pending:
    # Did the user use the pending skill this turn?
    token = "/pds:" + pending
    if token in prompt:
        state["skills"].setdefault(pending, {"shown": 0, "ignored": 0, "used": 0})
        state["skills"][pending]["used"] += 1
        state["skills"][pending]["ignored"] = 0  # reset streak
    else:
        state["skills"].setdefault(pending, {"shown": 0, "ignored": 0, "used": 0})
        state["skills"][pending]["ignored"] += 1
    state["pending"] = None
    with open(state_file, "w") as f:
        json.dump(state, f)
PY
fi

# Decide candidate skill for *this* prompt.
CANDIDATE=""
case "$LOWER" in
  *bug*|*fix*|*error*|*broken*|*crash*|*issue*) CANDIDATE=bugfix ;;
  *ship*|*deploy*|*push*|*release*|*publish*)   CANDIDATE=finish ;;
  *review*|*pr*|*pull*request*)                 CANDIDATE=verify ;;
  *plan*|*design*|*architect*)                  CANDIDATE=grill ;;
  *parallel*|*swarm*|*multi-agent*|*team*|*concurrent*) CANDIDATE=swarm ;;
  *rebase*|*merge*|*conflict*)                  CANDIDATE=rebase ;;
  *test*|*coverage*|*spec*|*tdd*)               CANDIDATE=bugfix ;;
esac

[ -z "$CANDIDATE" ] && exit 0

# Decay gate: if this skill has been ignored >= DECAY_AFTER times in a row,
# silence it for this session.
if [ "$DECAY_ENABLED" = "true" ] && [ -f "$STATE_FILE" ]; then
    IGNORED=$(python3 -c "
import json, sys
try:
    with open('$STATE_FILE') as f:
        s = json.load(f)
    print(s.get('skills', {}).get('$CANDIDATE', {}).get('ignored', 0))
except Exception:
    print(0)
" 2>/dev/null)
    if [ "${IGNORED:-0}" -ge "$DECAY_AFTER" ]; then
        exit 0
    fi
fi

# Record that we're showing this hint so next turn can judge ignore/use.
if [ "$DECAY_ENABLED" = "true" ]; then
    python3 - "$STATE_FILE" "$CANDIDATE" <<'PY' 2>/dev/null || true
import json, sys
state_file, cand = sys.argv[1], sys.argv[2]
try:
    with open(state_file) as f:
        state = json.load(f)
except Exception:
    state = {"pending": None, "skills": {}}
state["pending"] = cand
state["skills"].setdefault(cand, {"shown": 0, "ignored": 0, "used": 0})
state["skills"][cand]["shown"] += 1
with open(state_file, "w") as f:
    json.dump(state, f)
PY
fi

HINTS="/pds:$CANDIDATE"

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
