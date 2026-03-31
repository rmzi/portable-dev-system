#!/bin/sh
# PDS SubagentStart hook — warns on unknown agent types not in PDS roster or Claude Code built-ins.
# Never blocks agent spawning (always exits 0).

INPUT=$(cat)
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // .type // empty')

# PDS roster (8 agents)
case "$AGENT_TYPE" in
  orchestrator|worker|validator|researcher|reviewer|documenter|scout|auditor) exit 0 ;;
esac

# Claude Code built-in types
case "$AGENT_TYPE" in
  Explore|Plan|general-purpose|code-simplifier) exit 0 ;;
esac

# Empty or unknown — warn but don't block
if [ -z "$AGENT_TYPE" ]; then
  echo "[PDS] Warning: unknown agent type '' — not in PDS roster or Claude Code built-ins" >&2
else
  echo "[PDS] Warning: unknown agent type '$AGENT_TYPE' — not in PDS roster or Claude Code built-ins" >&2
fi

exit 0
