#!/bin/sh
# PDS status line — displayed in Claude Code's CLI footer.
# Shows PDS version + swarm state (if active).

# Get PDS version
if [ -f "${CLAUDE_PLUGIN_ROOT}/VERSION" ]; then
  VERSION=$(cat "${CLAUDE_PLUGIN_ROOT}/VERSION")
else
  VERSION="?"
fi

STATUS="PDS v${VERSION}"

# Swarm state (if active)
if [ -f ".claude/swarm/phase" ]; then
  PHASE=$(cat .claude/swarm/phase 2>/dev/null)
  TIER=$(cat .claude/swarm/tier 2>/dev/null || echo "?")
  STATUS="${STATUS} | ${PHASE} | ${TIER}"
fi

echo "$STATUS"
