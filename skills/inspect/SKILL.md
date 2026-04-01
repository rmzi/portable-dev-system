---
description: Real-time PDS state inspection — swarm status, telemetry, agent health. Use to check current PDS operational state.
---
# /inspect — PDS State Inspector

Shows current PDS state. Adapts output based on whether a swarm is active.

## Procedure

### Step 1: Gather state

```
1. Read("VERSION") → $VERSION (fallback: echo $PDS_VERSION or "unknown")
2. Bash("test -f .claude/swarm/phase && echo active || echo inactive") → $SWARM_STATE
3. If swarm active:
   a. Read(".claude/swarm/phase") → $PHASE
   b. Read(".claude/swarm/tier") → $TIER
   c. TaskList() → count tasks by status (in_progress, pending, completed)
4. Bash("echo ${PDS_TELEMETRY:-0}") → $TELEMETRY_ENABLED
5. If telemetry enabled:
   Bash("wc -l < .claude/telemetry.jsonl 2>/dev/null || echo 0") → $ENTRY_COUNT
6. Bash("test -d ~/.claude/plugins/pds && echo installed || (test -L ~/.claude/plugins/pds && echo linked || echo missing)") → $PLUGIN_STATUS
```

### Step 2: Format output

**During swarm:**

```
PDS v{VERSION} — Swarm Active
Phase: {PHASE} | Tier: {TIER}
Tasks: {in_progress} in_progress, {pending} pending, {completed} completed
Telemetry: {enabled|disabled} ({ENTRY_COUNT} entries)
```

**No swarm:**

```
PDS v{VERSION} — No Swarm Active
Telemetry: {enabled|disabled}{" (N entries)" if enabled}
Plugin: {installed|linked|missing}
```

## Files Read

| File | Purpose |
|------|---------|
| `VERSION` | PDS version |
| `.claude/swarm/phase` | Swarm active if exists |
| `.claude/swarm/tier` | Current swarm tier |
| `.claude/telemetry.jsonl` | Entry count via `wc -l` |
