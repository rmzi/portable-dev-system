---
description: Real-time PDS state inspection — swarm status, telemetry, agent health. Use to check current PDS operational state.
---
# /inspect — PDS State Inspector

Shows the current state of PDS. Adapts output based on whether a swarm is active.

## During Swarm

When `.claude/swarm/phase` exists, show:

```
PDS v{version} — Swarm Active
Phase: {phase} | Tier: {tier}
Tasks: {in_progress} in_progress, {pending} pending, {completed} completed
Agents: {agent-1} (active), {agent-2} (idle), {agent-3} (pending)
Telemetry: {enabled|disabled} ({count} entries)
```

How to gather:
- **Phase**: read `.claude/swarm/phase`
- **Tier**: read `.claude/swarm/tier`
- **Tasks**: use `TaskList` if available, summarize counts by status
- **Agents**: from team config if available
- **Telemetry**: check `PDS_TELEMETRY` env and `wc -l .claude/telemetry.jsonl`

## During Non-Swarm

When no swarm is active (`.claude/swarm/phase` does not exist), show:

```
PDS v{version} — No Swarm Active
Telemetry: {enabled|disabled}
Plugin: {installed|linked|missing} at {path}
```

How to gather:
- **Version**: read `VERSION` file or `PDS_VERSION` env
- **Telemetry**: check `PDS_TELEMETRY` env; if enabled, report entry count and date range from `.claude/telemetry.jsonl`
- **Plugin**: check if `~/.claude/plugins/pds/` exists

## How to Check

Read the following files:

| File | Purpose |
|------|---------|
| `.claude/swarm/phase` | Swarm active if exists |
| `.claude/swarm/tier` | Current swarm tier |
| `VERSION` | PDS version |
| `.claude/telemetry.jsonl` | Telemetry data (`wc -l` for count) |
