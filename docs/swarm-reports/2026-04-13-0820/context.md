# Swarm Context: Persistent Codebase Understanding

## Plan Summary

Install codebase-memory-mcp as a structural intelligence backend for PDS, benchmark its capabilities against the PDS codebase (bash+markdown heavy), design a TUI for graph browsing (doc only), and prototype a SessionStart hook that auto-injects architectural context from the graph.

## Research Findings

- PDS is a Claude Code plugin: skills in `skills/*/SKILL.md`, agents in `agents/*.md`, hooks in `hooks/`
- The repo is mostly bash + markdown — tree-sitter graph may be sparse for shell scripts
- Existing SessionStart hook: `hooks/scripts/session-start.sh` — outputs JSON with `additionalContext` field
- Hook timeout: 15 seconds (configured in `hooks/hooks.json`)
- Ledger daemon is a hard dependency (exit 2 if missing); codebase-memory-mcp should degrade gracefully
- The hook uses `$CLAUDE_PLUGIN_ROOT` for path resolution and `$CLAUDE_ENV_FILE` for persistent env vars
- Hook output format: `{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "..."}}`
- `.claude/settings.json` has sandbox config with domain allowlist and credential deny rules
- The hook currently injects: PDS version, key skills list, worktree info, stale warnings, ledger status

## Acceptance Criteria

### Stream 1 — Install and Benchmark
- [ ] Binary installed and executable
- [ ] MCP server configured and visible
- [ ] PDS indexed: list_projects shows project with node/edge counts
- [ ] search_graph, trace_call_path, get_architecture return valid results
- [ ] Report: index time, DB size, query latency (3+ queries), token savings estimate, accuracy assessment

### Stream 2 — TUI Architecture
- [ ] Tech stack evaluation: 3+ candidates with recommendation and rationale
- [ ] Wire layouts for 4+ views (module tree, function signatures, call graph, dependency view)
- [ ] Data model: how to read from SQLite schema at ~/.cache/codebase-memory-mcp/
- [ ] ASCII mockups for 2+ key screens
- [ ] Self-contained — developer could start implementation from it

### Stream 3 — Hook Prototype
- [ ] Working hook script querying graph via CLI or MCP
- [ ] Valid SessionStart hook JSON with additionalContext
- [ ] Injected context under 2,048 tokens
- [ ] Content: key modules, entry points, dependency structure
- [ ] Extends session-start.sh without breaking existing behavior
- [ ] Graceful degradation when codebase-memory-mcp unavailable

## Key Decisions

1. **codebase-memory-mcp over claude-mem**: claude-mem overlaps with existing PDS memory (MEMORY.md + ledger). codebase-memory-mcp provides structural/graph intelligence — complementary.
2. **Graceful degradation for codebase-memory-mcp**: Unlike ledger (hard failure), codebase-memory-mcp is optional tooling. The hook must work when it's not installed/running.
3. **2K token budget for hook injection**: Keeps SessionStart fast and avoids bloating context. Must be concise architectural summary, not full graph dump.
4. **TUI design doc only**: No implementation this swarm. The doc should be self-contained enough for a developer to start building.
5. **Extend, don't replace**: The hook prototype extends existing `session-start.sh` behavior. Existing context (version, skills, worktree, ledger) stays intact.

## Constraints

- macOS darwin-arm64
- Bash hook scripts (existing pattern)
- 15-second hook timeout for SessionStart
- Must coexist with ledger daemon
- Working directory: /Users/ra/dev/portable-dev-system/.worktrees/codebase-understanding
- Repo root: /Users/ra/dev/portable-dev-system
