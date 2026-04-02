---
description: Export a Claude Code session to human-readable markdown. Use when the user wants to save, review, or share a conversation transcript.
---
# /export — Session Export

Export Claude Code session JSONL files to human-readable markdown.

## Usage

Run the export script:

```bash
# Export current/latest session to stdout
scripts/export-session.sh

# Export specific session
scripts/export-session.sh <session-id>

# Save to file
scripts/export-session.sh -o docs/conversations/session-name.md

# List available sessions
scripts/export-session.sh --list
```

Or from the plugin root:

```bash
$CLAUDE_PLUGIN_ROOT/scripts/export-session.sh
```

## Output Format

The exported markdown uses role markers for readability:

| Marker | Role |
|--------|------|
| **👤 Human** | User messages |
| **🔵 Claude** | Assistant text + tool calls |
| **🤖 Agent** | Teammate/subagent messages |
| **⚙️ System** | Slash commands |
| **⚙️ Shell** | Terminal commands run by user |

Tool calls appear as compact `📎` lines showing the tool name and key parameters.

Timestamps are shown on every message. System reminders, XML tags, and internal metadata are stripped for readability.

## Where Sessions Live

Session JSONL files are stored at:

```
~/.claude/projects/<project-hash>/<session-id>.jsonl
```

Each project directory corresponds to a working directory. Use `--list` to see available sessions with their sizes and dates.

## When to Use

- After a significant session to preserve the decision trail
- Before closing a session that explored important design decisions
- To share session context with teammates
- For retrospective analysis of how a swarm executed

## Conventions

Save exported sessions to `docs/conversations/` with descriptive names:

```
docs/conversations/2026-04-02-v4.8.0-session.md
docs/conversations/2026-03-31-source-analysis.md
```

## See Also

- `/pds:telemetry` — Usage telemetry management
- `/pds:inspect` — Real-time PDS state
- `scripts/efficiency-chart.sh` — Value stream visualization from telemetry
