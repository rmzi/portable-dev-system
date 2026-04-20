#!/bin/sh
# PDS UserPromptSubmit hook — session activity tracking.
# Silent under serious-duration thresholds. Activity-based: idle gaps reset the session clock.
# Fires at most once per threshold tier per continuous-work block.
# Opt-out via PDS_HEALTH_REMINDERS=0.

[ "$PDS_HEALTH_REMINDERS" = "0" ] && exit 0

# Minutes of inactivity that counts as "walked away" — resets the session clock.
IDLE_RESET=${PDS_IDLE_RESET_MIN:-20}
# Minutes of continuous active work before surfacing a factual status line.
SERIOUS=${PDS_HEALTH_SERIOUS_MIN:-180}
# Minutes of continuous active work that warrants a direct nudge.
VERY_SERIOUS=${PDS_HEALTH_VERY_SERIOUS_MIN:-300}

MARKER="${TMPDIR:-/tmp}/pds-session-activity"
NOW=$(date +%s)

# Marker format: "<session_start_epoch> <last_prompt_epoch> <highest_tier_fired>"
# highest_tier_fired: 0 (none), 1 (serious), 2 (very_serious)
if [ -f "$MARKER" ]; then
    read -r START LAST TIER < "$MARKER" 2>/dev/null
fi

# Missing or unreadable marker: initialize silently.
if [ -z "$START" ] || [ -z "$LAST" ]; then
    echo "$NOW $NOW 0" > "$MARKER"
    exit 0
fi

[ -z "$TIER" ] && TIER=0

IDLE_SECONDS=$((NOW - LAST))
IDLE_THRESHOLD_SECONDS=$((IDLE_RESET * 60))

# Walked away long enough that this counts as a new continuous-work block.
# Reset session clock and tier history.
if [ "$IDLE_SECONDS" -ge "$IDLE_THRESHOLD_SECONDS" ]; then
    START=$NOW
    TIER=0
fi

ELAPSED_MINUTES=$(( (NOW - START) / 60 ))

# Determine current tier based on elapsed continuous work.
if [ "$ELAPSED_MINUTES" -ge "$VERY_SERIOUS" ]; then
    CURRENT_TIER=2
elif [ "$ELAPSED_MINUTES" -ge "$SERIOUS" ]; then
    CURRENT_TIER=1
else
    CURRENT_TIER=0
fi

# Only fire when transitioning to a higher tier than previously fired.
# Prevents per-prompt spam once a threshold has been announced.
if [ "$CURRENT_TIER" -le "$TIER" ]; then
    echo "$START $NOW $TIER" > "$MARKER"
    exit 0
fi

echo "$START $NOW $CURRENT_TIER" > "$MARKER"

HOURS=$((ELAPSED_MINUTES / 60))
MINS=$((ELAPSED_MINUTES % 60))
MSG="Active session: ${HOURS}h ${MINS}m continuous."

python3 -c "
import json, sys
msg = sys.argv[1]
print(json.dumps({
    'hookSpecificOutput': {
        'hookEventName': 'UserPromptSubmit',
        'additionalContext': msg
    }
}))
" "$MSG" 2>/dev/null || exit 0

exit 0
