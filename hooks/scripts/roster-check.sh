#!/bin/sh
# PDS SubagentStart hook — warns on unknown agent types not in the PDS roster
# or Claude Code's built-ins. Never blocks agent spawning (always exits 0).
#
# NAMESPACING (#181): PDS agents ship in a plugin, so live spawns report
# `agent_type` as `pds:<name>` — confirmed directly from hook payloads, e.g.
# {"agent_type":"pds:orchestrator", ...}. This script previously matched bare
# names only, which meant it warned on *every* legitimate PDS spawn while
# staying silent on genuinely unknown ones — an inverted signal. It exits 0
# unconditionally, so the cost was noise rather than breakage, but it is the
# same root cause as #181 in a third location.
#
# The roster is derived from the plugin's own agents/ directory when that is
# resolvable, so adding an agent needs no edit here. The static list is a
# fallback for when CLAUDE_PLUGIN_ROOT is unset (direct invocation, tests).

INPUT=$(cat)
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // .type // empty' 2>/dev/null)

# Strip the plugin namespace before matching — `pds:worker` and a project-scope
# `worker` are the same role for roster purposes.
BARE=${AGENT_TYPE#pds:}

# Claude Code built-in types
case "$BARE" in
  Explore|Plan|general-purpose|code-simplifier) exit 0 ;;
esac

# Prefer the live roster on disk; fall back to the known list.
ROSTER_DIR="${CLAUDE_PLUGIN_ROOT:-}/agents"
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -d "$ROSTER_DIR" ]; then
  for f in "$ROSTER_DIR"/*.md; do
    [ -e "$f" ] || continue
    name=$(basename "$f" .md)
    # shared-rules is an inherited mixin, never a spawnable agent
    [ "$name" = "shared-rules" ] && continue
    [ "$name" = "$BARE" ] && exit 0
  done
else
  case "$BARE" in
    orchestrator|worker|validator|researcher|reviewer|documenter|scout|auditor|shepherd) exit 0 ;;
  esac
fi

# Empty or unknown — warn but don't block
if [ -z "$AGENT_TYPE" ]; then
  echo "[PDS] Warning: unknown agent type '' — not in PDS roster or Claude Code built-ins" >&2
else
  echo "[PDS] Warning: unknown agent type '$AGENT_TYPE' — not in PDS roster or Claude Code built-ins" >&2
fi

exit 0
