# Benchmark Report: codebase-memory-mcp on PDS

## Installation

- **Binary**: codebase-memory-mcp 0.6.0
- **Location**: ~/.local/bin/codebase-memory-mcp
- **Platform**: darwin-arm64
- **Install method**: Official install.sh with --skip-config

## Indexing

- **Files indexed**: 106
- **Nodes created**: 1,507
- **Edges created**: 1,647
- **Index time**: 211ms (wall clock), 191ms (pipeline)
- **DB size**: 3.7MB (SQLite)
- **DB location**: ~/.cache/codebase-memory-mcp/Users-ra-dev-portable-dev-system.db

## Node Distribution

| Label | Count |
|-------|-------|
| Section | 1,004 |
| Variable | 205 |
| File | 106 |
| Module | 106 |
| Function | 45 |
| Folder | 37 |
| Class | 3 |
| Project | 1 |

## Edge Distribution

| Type | Count |
|------|-------|
| DEFINES | 1,363 |
| CONTAINS_FILE | 106 |
| CALLS | 87 |
| FILE_CHANGES_WITH | 50 |
| CONTAINS_FOLDER | 36 |
| SEMANTICALLY_RELATED | 2 |
| SIMILAR_TO | 2 |
| CONFIGURES | 1 |

## Query Benchmarks

| Query | Time | Notes |
|-------|------|-------|
| list_projects | 27ms | Includes cold start |
| get_architecture | 7ms | Basic schema overview |
| get_architecture (all) | 14ms | Full aspect analysis |
| search_graph (Function) | 8ms | 45 results returned |
| search_graph (regex) | 17ms | 17 results for ".*secret.*" |
| trace_call_path | 14ms | install_plugin, both directions, 11 callees + 1 caller |
| get_graph_schema | 5ms | Node/edge counts |

## Token Savings Estimate

### Without codebase-memory-mcp (typical file-by-file exploration):
- Reading 106 files to understand structure: ~50-80K tokens (file contents)
- Multiple grep/glob calls to find patterns: ~10-20K tokens (tool call overhead)
- **Estimated total**: 60-100K tokens per session

### With codebase-memory-mcp:
- get_architecture: ~500 tokens
- search_graph (functions): ~2,000 tokens
- 3-5 targeted queries: ~1,500 tokens
- **Estimated total**: ~4,000 tokens per session

### Reduction: ~94-96% (roughly 20-25x fewer tokens)

Note: The claimed 120x reduction is for larger codebases. PDS is small (106 files) and mostly bash+markdown, so the ratio is lower but still substantial.

## Accuracy Assessment

### Strengths
- **Function extraction**: All 45 bash functions correctly identified across install.sh, test-hooks.sh, secret-scrub.sh, run-eval.sh, efficiency-chart.sh
- **Call graph**: 87 CALLS edges accurately map function invocation chains (e.g., install_plugin -> check_jq, check_python3, install_security_settings)
- **File structure**: Complete folder/file hierarchy with 106 files and 37 folders
- **Git co-change analysis**: 50 FILE_CHANGES_WITH edges capturing correlated modifications

### Weaknesses (expected for bash+markdown repos)
- **Section-heavy graph**: 1,004 Section nodes from markdown headers — useful for documentation structure but noisy for code intelligence
- **No class depth**: Only 3 Class nodes (likely from JSON/YAML structures, not true OOP)
- **Limited type resolution**: Bash has no static types; function signatures are bare names
- **No route/HTTP nodes**: PDS has no HTTP endpoints — expected absence
- **Sparse call graph relative to node count**: 87 CALLS edges vs 1,507 nodes (5.8%) — typical for shell scripts where most "calls" are to external commands not tracked in the graph

### Verdict
The graph is **accurate but sparse** for this repo's composition. The structural intelligence is genuinely useful for the 45 functions and their call relationships. The markdown Section nodes provide document-structure search that would otherwise require full-text scan. For a bash+markdown repo, this is near the expected ceiling of what tree-sitter AST analysis can extract.

## SQLite Schema Summary

Key tables for downstream consumers:
- `nodes(id, project, label, name, qualified_name, file_path, start_line, end_line, properties)`
- `edges(id, project, source_id, target_id, type, properties)`
- `projects(name, indexed_at, root_path)`
- `file_hashes(project, rel_path, sha256, mtime_ns, size)`
- `node_vectors(node_id, project, vector)` — semantic similarity
- `nodes_fts` — FTS5 virtual table for full-text search on node names

Indexes: label, name, file_path on nodes; source/target/type on edges.

## CLI Interface

```bash
codebase-memory-mcp cli <tool_name> '<json_args>'
codebase-memory-mcp cli --raw <tool_name> '<json_args>'  # raw JSON output
```

Cold start latency: ~5-27ms (acceptable for hook use within 15s timeout).
