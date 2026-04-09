# Plan: Ledger CLI hook integration + PDS telemetry rewrite

## Context

Ledger is running. PDS has 6 hook scripts that write telemetry to JSONL files. These scripts each contain 15-45 lines of jq parsing, field extraction, mkdir, and printf formatting. That logic should live in ledger's CLI, not in PDS hooks.

The hooks should become one-liners. Ledger should understand Claude Code hook JSON natively.

## Approach: `ledger hook` subcommand

Add a `hook` subcommand to `ledger-cli` that:
1. Reads Claude Code hook JSON from stdin
2. Extracts the right fields based on event type
3. Logs to ledgerd via gRPC

### New CLI surface

```
ledger hook skill     # PostToolUse (Skill|Agent) — reads tool_name, tool_input
ledger hook file      # PostToolUse (Write|Edit) — reads tool_input.file_path
ledger hook worktree  # WorktreeCreate — reads name
ledger hook init      # InstructionsLoaded — logs session init
ledger hook scrub     # PreToolUse/PostToolUse — reads tool_name, logs scrub event
```

Each reads JSON from stdin (the `$INPUT` that Claude Code provides), extracts relevant fields, calls `ledger log` internally.

### Field extraction per event type

| Subcommand | Input fields | Event type | Payload |
|-----------|-------------|------------|---------|
| `hook skill` | `.tool_name`, `.tool_input.skill` or `.tool_input.subagent_type` | `skill_invoked` or `agent_spawned` | `{"name":"...", "agent":"..."}` |
| `hook file` | `.tool_input.file_path` | `file_modified` | `{"path":"...", "ext":"..."}` |
| `hook worktree` | `.name` | `worktree_created` | `{"name":"..."}` |
| `hook init` | (none) | `instructions_loaded` | `{}` |
| `hook scrub` | `.tool_name` | `secret_scrubbed` | `{"tool":"..."}` |

All events get `source: "pds"` and `session` from `$CLAUDE_SESSION_ID` env var.

## Files to modify

### In ledger repo (`~/dev/ledger`)

**`crates/ledger-cli/src/main.rs`** — Add `Hook` subcommand with sub-subcommands (skill, file, worktree, init, scrub). Each:
- Reads stdin as JSON (serde_json::Value)
- Extracts fields
- Calls the existing gRPC log endpoint

### In PDS repo (`~/dev/portable-dev-system`)

**Rewrite to one-liners:**

| Script | Before (lines) | After |
|--------|----------------|-------|
| `hooks/scripts/telemetry-log.sh` | 45 | `cat \| ~/.ledger/bin/ledger hook skill` |
| `hooks/scripts/file-telemetry-log.sh` | 28 | `cat \| ~/.ledger/bin/ledger hook file` |
| `hooks/scripts/worktree-telemetry.sh` | 16 | `cat \| ~/.ledger/bin/ledger hook worktree` |
| `hooks/scripts/instructions-telemetry.sh` | 13 | `cat \| ~/.ledger/bin/ledger hook init` |

**Rewrite scrub telemetry (keep scrub logic, replace telemetry):**

| Script | Change |
|--------|--------|
| `hooks/scripts/secret-scrub.sh` | Replace `log_scrub()` function (lines 58-89) with `echo "$INPUT" \| ~/.ledger/bin/ledger hook scrub` |
| `hooks/scripts/mcp-secret-scrub.sh` | Replace lines 47-54 (telemetry block) with `echo "$INPUT" \| ~/.ledger/bin/ledger hook scrub` |

**Remove:**
- `PDS_TELEMETRY` env var gating — ledger is always-on, no opt-in
- JSONL write paths (`.claude/telemetry.jsonl`, `~/.claude/telemetry/sessions.jsonl`)
- `~/.config/pds/scrub-telemetry.jsonl` writes
- Age-encrypted scrub telemetry (ledger replaces this)

**Update:**
- `hooks/scripts/status-line.sh` — Replace `PDS_TELEMETRY` indicator with ledger status (query event count via `ledger status` or just check socket)

## Verification

```bash
# 1. Build updated ledger CLI
cd ~/dev/ledger && cargo build --release -p ledger-cli
cp target/release/ledger ~/.ledger/bin/ledger

# 2. Test hook subcommands directly
echo '{"tool_name":"Skill","tool_input":{"skill":"pds:swarm"}}' | ~/.ledger/bin/ledger hook skill
echo '{"tool_input":{"file_path":"/foo/bar.rs"}}' | ~/.ledger/bin/ledger hook file
echo '{"name":"worker-auth"}' | ~/.ledger/bin/ledger hook worktree
echo '{}' | ~/.ledger/bin/ledger hook init

# 3. Verify events landed in ledger
ledger query --source pds --limit 10

# 4. Test PDS hooks work end-to-end
# (Start a new Claude Code session — hooks fire automatically)

# 5. Verify no JSONL files created
ls .claude/telemetry.jsonl  # should not exist
ls ~/.claude/telemetry/     # should not exist
```
