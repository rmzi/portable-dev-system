# Scout Report: Persistent Codebase Understanding

## Instinct Observations

### Updated Instinct: Context loss on agent spawn is the dominant waste category
- **Times seen**: 2 (bumped from 1)
- **Confidence**: medium (bumped from low)
- **New evidence**: This swarm used context.md to pass benchmark results, SQLite schema, and tool CLI patterns to downstream tasks. Without it, Tasks 2 and 3 would have re-discovered the MCP envelope format, CLI syntax, and query patterns.

### New Instinct: External tool graph sparsity correlates with language composition

- **Observed**: 2026-04-13
- **Times seen**: 1
- **Confidence**: low
- **Context**: codebase-memory-mcp indexed PDS (106 files, mostly bash+markdown) — produced 45 Functions, 87 CALLS edges. The claimed 120x token reduction was 20-25x for this repo.
- **Pattern**: Tree-sitter AST analysis yields diminishing returns on shell-heavy repos. Function extraction works well for bash, but call graph depth is limited (most calls are to external commands not tracked). Markdown Section nodes dominate the graph (1,004/1,507 = 67% of all nodes).
- **Action**: When evaluating graph-based tools for a repo, check language composition first. Expect sparse call graphs for bash/shell, dense for Go/Rust/Python.
- **Status**: active

### New Instinct: macOS lacks GNU coreutils by default

- **Observed**: 2026-04-13
- **Times seen**: 1
- **Confidence**: low
- **Context**: Hook script used `timeout` command which doesn't exist on macOS without `brew install coreutils`.
- **Pattern**: Scripts targeting macOS must avoid GNU-specific commands (`timeout`, `readlink -f`, `sed -i`, `stat --format`) or provide fallbacks.
- **Action**: For PDS hook scripts: avoid `timeout` (use the outer hook timeout instead), use `greadlink` or `python3` for canonical paths, test on clean macOS.
- **Status**: active

## Skill Promotion Candidates

None. Both new instincts are at low confidence (single observation). The context-loss instinct is now at medium confidence but already has a skill-level implementation (context.md in /pds:swarm Phase 2).

## Auto-Memory Entries

### Project Memory: codebase-memory-mcp integration
- codebase-memory-mcp v0.6.0 installed at `~/.local/bin/codebase-memory-mcp`. PDS indexed: 1,507 nodes, 1,647 edges, 3.7MB SQLite at `~/.cache/codebase-memory-mcp/`. Graph is accurate but sparse for bash+markdown repos (45 functions, 87 call edges, 1,004 markdown sections). Query latency: 5-27ms. Hook prototype in `hooks/scripts/codebase-context.sh` injects ~220 tokens of architectural context at SessionStart. TUI design doc at `docs/tui-architecture.md` recommends Ratatui (Rust).

### Feedback Memory: MCP CLI output requires double-parsing
- codebase-memory-mcp CLI wraps all output in MCP envelope: `{"content":[{"type":"text","text":"<inner-json>"}]}`. The inner `text` field is itself a JSON string that must be parsed separately. When scripting against the CLI, always unwrap the MCP envelope first. The `--raw` flag exists but must come after the tool name, not before.

## Telemetry-Detected Patterns

No telemetry file (`.claude/telemetry.jsonl`) found in this worktree. Skipped.

## Permission Promotions

No `.claude/settings.local.json` file found (symlink to repo root). No permission promotions needed.
