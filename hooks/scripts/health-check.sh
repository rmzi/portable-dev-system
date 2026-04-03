#!/bin/sh
# PDS UserPromptSubmit hook — session health monitoring.
# Reminds users to take breaks based on session duration.
# Opt-out via PDS_HEALTH_REMINDERS=0.

[ "$PDS_HEALTH_REMINDERS" = "0" ] && exit 0

# Configurable thresholds (minutes)
GENTLE=${PDS_BREAK_GENTLE:-30}
FIRM=${PDS_BREAK_FIRM:-60}
URGENT=${PDS_BREAK_URGENT:-120}

MARKER="${TMPDIR:-/tmp}/pds-session-start"
NOW=$(date +%s)

# First invocation: record session start time
if [ ! -f "$MARKER" ]; then
    echo "$NOW" > "$MARKER"
    exit 0
fi

START=$(cat "$MARKER" 2>/dev/null)
[ -z "$START" ] && { echo "$NOW" > "$MARKER"; exit 0; }

ELAPSED_SECONDS=$((NOW - START))
ELAPSED_MINUTES=$((ELAPSED_SECONDS / 60))

# Under gentle threshold: no output
[ "$ELAPSED_MINUTES" -lt "$GENTLE" ] && exit 0

# Build message based on threshold
if [ "$ELAPSED_MINUTES" -ge "$URGENT" ]; then
    HOURS=$((ELAPSED_MINUTES / 60))
    MSG="You've been working for ${HOURS}h. Seriously, take a break. Use /pds:pause to save state."
elif [ "$ELAPSED_MINUTES" -ge "$FIRM" ]; then
    MSG="You've been at this over an hour. Take a walk."
else
    MSG="Good time for a stretch. You've been working for ${ELAPSED_MINUTES}m."
fi

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
