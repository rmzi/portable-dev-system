---
description: Usage telemetry management — enable, disable, view reports, rotate logs. Use when checking PDS usage patterns or managing telemetry settings.
---
# /telemetry — Usage Telemetry

PDS telemetry tracks which skills, agents, and hooks are used. All data is local. Disabled by default.

## Subcommands

### on

```
1. Read(".claude/settings.local.json")
   — If file missing or no "env" key, treat as empty object
2. Edit(".claude/settings.local.json")
   — Set or add: "env": { "PDS_TELEMETRY": "1" }
   — Preserve all other keys
3. Output: "Telemetry enabled. Usage data logged to .claude/telemetry.jsonl"
```

### off

```
1. Read(".claude/settings.local.json")
2. Edit(".claude/settings.local.json")
   — Set: "env": { "PDS_TELEMETRY": "0" }
   — Preserve all other keys
3. Output: "Telemetry disabled. Existing data preserved in .claude/telemetry.jsonl"
```

### view

```
1. Bash("wc -l < .claude/telemetry.jsonl 2>/dev/null || echo 0")
   — If 0: output "No telemetry data. Enable with /pds:telemetry on" and stop
2. Bash("${CLAUDE_PLUGIN_ROOT:-$(git rev-parse --path-format=absolute --git-common-dir | sed 's|/.git$||')}/scripts/telemetry-summary.sh .claude/telemetry.jsonl")
3. Output the summary report
```

### rotate

```
1. Bash("wc -l < .claude/telemetry.jsonl 2>/dev/null || echo 0")
   — If <= 10000: output "No rotation needed (N entries)" and stop
2. Bash("DATE=$(date +%Y%m%d); cp .claude/telemetry.jsonl .claude/telemetry-${DATE}.jsonl.bak && tail -10000 .claude/telemetry.jsonl > .claude/telemetry.jsonl.tmp && mv .claude/telemetry.jsonl.tmp .claude/telemetry.jsonl")
3. Bash("wc -l < .claude/telemetry-*.jsonl.bak | tail -1")
4. Output: "Rotated N entries to .claude/telemetry-{date}.jsonl.bak. Active file: 10,000 entries."
```

## Data Format

JSONL, one entry per line:

```json
{"ts":"2026-03-31T12:00:00Z","event":"skill_invoked","name":"swarm","session":"abc123"}
```

Events: `skill_invoked`, `agent_spawned`, `worktree_created`, `instructions_loaded`, `file_modified`

## Privacy

- All data stored locally in `.claude/telemetry.jsonl`
- No network transmission
- `.gitignore`d by default
- User controls: on/off/rotate
