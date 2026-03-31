#!/bin/sh
# PDS PostCompact hook — re-injects swarm context after context compaction.
# Reads snapshot written by pre-compact-snapshot.sh and outputs it as additionalContext.

SNAPSHOT_FILE='.claude/swarm/pre-compact-snapshot.md'

# No snapshot to restore
[ -f "$SNAPSHOT_FILE" ] || exit 0

CONTENT=$(cat "$SNAPSHOT_FILE")

python3 -c "
import json, sys
content = sys.argv[1]
print(json.dumps({
    'hookSpecificOutput': {
        'hookEventName': 'PostCompact',
        'additionalContext': 'PDS Swarm Context (restored after compaction): ' + content
    }
}))
" "$CONTENT" 2>/dev/null || exit 0

# Snapshot consumed — clean up
rm -f "$SNAPSHOT_FILE"

exit 0
