---
description: Usage telemetry management — enable, disable, view reports, rotate logs. Use when checking PDS usage patterns or managing telemetry settings.
---
# /telemetry — Usage Telemetry

PDS telemetry tracks which skills, agents, and hooks are used. All data is local — nothing leaves your machine. Disabled by default.

## Subcommands

### on

Enable telemetry by adding `PDS_TELEMETRY=1` to project settings:

1. Read `.claude/settings.json` (or `.claude/settings.local.json`)
2. Add or update `env.PDS_TELEMETRY` to `"1"`
3. Confirm: **Telemetry enabled. Usage data will be logged to `.claude/telemetry.jsonl`**

### off

Disable telemetry:

1. Set `env.PDS_TELEMETRY` to `"0"` in settings
2. Confirm: **Telemetry disabled. Existing data preserved.**
3. Note: does not delete existing `.claude/telemetry.jsonl`

### view

Show usage report:

1. Run `scripts/telemetry-summary.sh`
2. If `.claude/telemetry.jsonl` doesn't exist or is empty, show: **No telemetry data. Enable with `/pds:telemetry on`**

### rotate

Archive old entries:

- If `.claude/telemetry.jsonl` has > 10,000 lines:
  1. Move current file to `.claude/telemetry-{date}.jsonl.bak`
  2. Keep last 10,000 lines in new `.claude/telemetry.jsonl`
  3. Report: **Rotated N entries to archive**
- If <= 10,000 lines: **No rotation needed (N entries)**

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
