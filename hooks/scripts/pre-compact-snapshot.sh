#!/bin/sh
# PDS PreCompact hook — captures swarm state before context compaction.
# Only activates when a swarm is running (.claude/swarm/phase exists).

# No swarm active — nothing to snapshot
[ -f .claude/swarm/phase ] || exit 0

PHASE=$(cat .claude/swarm/phase 2>/dev/null || echo 'unknown')
TIER=$(cat .claude/swarm/tier 2>/dev/null || echo 'unknown')
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

mkdir -p .claude/swarm

cat > .claude/swarm/pre-compact-snapshot.md <<EOF
# Pre-Compact Snapshot
Captured: ${TS}
Phase: ${PHASE}
Tier: ${TIER}

## Active Tasks
Task state preserved in team task list.
EOF

exit 0
