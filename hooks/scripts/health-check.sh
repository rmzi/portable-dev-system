#!/bin/sh
# PDS UserPromptSubmit hook — session activity tracking.
# Silent under serious-duration thresholds. Activity-based: idle gaps reset the session clock.
# Fires at most once per threshold tier per continuous-work block.
#
# Thresholds come from pds.config.yaml via `pds config get`. If the CLI isn't
# on PATH (fresh install, CI, etc.) we fall back to env-var defaults so the
# hook never fails loudly on a missing config.
#
# Opt-out via PDS_HEALTH_REMINDERS=0.

[ "$PDS_HEALTH_REMINDERS" = "0" ] && exit 0

# Helper: read a config key via pds CLI, fall back to the second arg if
# pds isn't on PATH or the key isn't in config.
cfg() {
  key=$1
  default=$2
  if command -v pds >/dev/null 2>&1; then
    value=$(pds config get "$key" 2>/dev/null)
    if [ -n "$value" ]; then
      printf '%s' "$value"
      return
    fi
  fi
  printf '%s' "$default"
}

IDLE_RESET=$(cfg health.idle_reset_min "${PDS_IDLE_RESET_MIN:-20}")
SERIOUS=$(cfg health.serious_min "${PDS_HEALTH_SERIOUS_MIN:-180}")
VERY_SERIOUS=$(cfg health.very_serious_min "${PDS_HEALTH_VERY_SERIOUS_MIN:-300}")
VERY_SERIOUS_ACTION=$(cfg health.very_serious_action "reminder")

MARKER="${TMPDIR:-/tmp}/pds-session-activity"
NOW=$(date +%s)

if [ -f "$MARKER" ]; then
    read -r START LAST TIER < "$MARKER" 2>/dev/null
fi

if [ -z "$START" ] || [ -z "$LAST" ]; then
    echo "$NOW $NOW 0" > "$MARKER"
    exit 0
fi

[ -z "$TIER" ] && TIER=0

IDLE_SECONDS=$((NOW - LAST))
IDLE_THRESHOLD_SECONDS=$((IDLE_RESET * 60))

if [ "$IDLE_SECONDS" -ge "$IDLE_THRESHOLD_SECONDS" ]; then
    START=$NOW
    TIER=0
fi

ELAPSED_MINUTES=$(( (NOW - START) / 60 ))

if [ "$ELAPSED_MINUTES" -ge "$VERY_SERIOUS" ]; then
    CURRENT_TIER=2
elif [ "$ELAPSED_MINUTES" -ge "$SERIOUS" ]; then
    CURRENT_TIER=1
else
    CURRENT_TIER=0
fi

if [ "$CURRENT_TIER" -le "$TIER" ]; then
    echo "$START $NOW $TIER" > "$MARKER"
    exit 0
fi

echo "$START $NOW $CURRENT_TIER" > "$MARKER"

HOURS=$((ELAPSED_MINUTES / 60))
MINS=$((ELAPSED_MINUTES % 60))

# Compose message based on tier and configured action for very-serious.
if [ "$CURRENT_TIER" -eq 2 ]; then
    case "$VERY_SERIOUS_ACTION" in
        ack)
            MSG="Active session: ${HOURS}h ${MINS}m continuous. Type 'continue' to acknowledge or /pds:pause to stop."
            ;;
        pause)
            MSG="Active session: ${HOURS}h ${MINS}m continuous. PDS recommends /pds:pause before continuing."
            ;;
        *)
            MSG="Active session: ${HOURS}h ${MINS}m continuous."
            ;;
    esac
else
    MSG="Active session: ${HOURS}h ${MINS}m continuous."
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
