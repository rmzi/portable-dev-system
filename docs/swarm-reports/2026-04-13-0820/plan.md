# Decomposition Plan: Persistent Codebase Understanding

## Task DAG

```
Task 1: Install + Benchmark codebase-memory-mcp
    ├──> Task 2: TUI Architecture Design (blocked by Task 1)
    └──> Task 3: Hook Prototype (blocked by Task 1)
```

## Task 1: Install + Benchmark codebase-memory-mcp

**Owner**: worker
**Deliverables**:
1. Install codebase-memory-mcp binary (darwin-arm64)
2. Configure as MCP server
3. Index the PDS repo
4. Run benchmark queries (search_graph, trace_call_path, get_architecture)
5. Produce benchmark report with: index time, DB size, query latency, token savings estimate, accuracy assessment
6. Document the SQLite schema at ~/.cache/codebase-memory-mcp/ for Tasks 2 and 3

**Acceptance criteria** (checklist):
- [ ] Binary installed at a known path and executable
- [ ] MCP server configured (document how)
- [ ] PDS indexed: list_projects shows project with node/edge counts
- [ ] search_graph returns valid results for PDS queries
- [ ] trace_call_path returns valid results
- [ ] get_architecture returns valid results
- [ ] Benchmark report written with index time, DB size, query latency (3+ queries), token savings estimate, accuracy assessment
- [ ] SQLite schema documented for downstream tasks

## Task 2: TUI Architecture Design

**Owner**: researcher (plan mode)
**Blocked by**: Task 1 (needs SQLite schema and working binary)
**Deliverables**:
1. Tech stack evaluation (3+ candidates)
2. Wire layouts for 4+ views
3. Data model documentation
4. ASCII mockups for 2+ screens

**Acceptance criteria** (checklist):
- [ ] Tech stack evaluation: 3+ candidates with recommendation and rationale
- [ ] Wire layouts for 4+ views (module tree, function signatures, call graph, dependency view)
- [ ] Data model: how to read from SQLite schema at ~/.cache/codebase-memory-mcp/
- [ ] ASCII mockups for 2+ key screens
- [ ] Self-contained design doc — developer could start implementation from it

## Task 3: Hook Prototype

**Owner**: worker
**Blocked by**: Task 1 (needs working binary and query patterns)
**Deliverables**:
1. Working hook script that queries the codebase graph
2. Integration with existing session-start.sh
3. Graceful degradation when unavailable

**Acceptance criteria** (checklist):
- [ ] Working hook script querying graph via CLI or MCP
- [ ] Valid SessionStart hook JSON with additionalContext
- [ ] Injected context under 2,048 tokens
- [ ] Content includes: key modules, entry points, dependency structure
- [ ] Extends session-start.sh without breaking existing behavior
- [ ] Graceful degradation when codebase-memory-mcp unavailable
