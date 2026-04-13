# TUI Architecture Design: Codebase Graph Browser

Architecture document for a terminal-based graph browser reading from codebase-memory-mcp's SQLite database. Self-contained -- a developer can start implementation from this document.

## Tech Stack Evaluation

### Candidate 1: Ratatui (Rust)

**Library**: [ratatui](https://github.com/ratatui/ratatui)
**Language**: Rust
**SQLite**: rusqlite (zero-copy, bundled SQLite)

| Criterion | Score | Notes |
|-----------|-------|-------|
| Rendering performance | Excellent | Immediate mode, no allocation per frame |
| Widget ecosystem | Strong | Tree, table, list, tabs, canvas for graphs |
| Cross-platform | Yes | macOS, Linux, Windows |
| Binary distribution | Single static binary | Matches codebase-memory-mcp's distribution model |
| Learning curve | Moderate | Rust ownership, but ratatui has good docs |
| Community | Active | 10K+ stars, frequent releases |

### Candidate 2: Bubble Tea (Go)

**Library**: [bubbletea](https://github.com/charmbracelet/bubbletea)
**Language**: Go
**SQLite**: modernc.org/sqlite (pure Go, CGo-free)

| Criterion | Score | Notes |
|-----------|-------|-------|
| Rendering performance | Good | Elm architecture, efficient diffing |
| Widget ecosystem | Strong | Lip Gloss styling, Bubbles components |
| Cross-platform | Yes | macOS, Linux, Windows |
| Binary distribution | Single binary | CGo-free SQLite makes cross-compilation easy |
| Learning curve | Low | Go is simple; Elm pattern is intuitive |
| Community | Very active | Charm ecosystem is polished |

### Candidate 3: Textual (Python)

**Library**: [textual](https://github.com/Textualize/textual)
**Language**: Python
**SQLite**: Built-in sqlite3 module

| Criterion | Score | Notes |
|-----------|-------|-------|
| Rendering performance | Good | CSS-like layout engine, async rendering |
| Widget ecosystem | Rich | Tree, DataTable, rich text, CSS theming |
| Cross-platform | Yes | macOS, Linux, Windows |
| Binary distribution | Requires Python runtime | Could use PyInstaller but adds ~40MB |
| Learning curve | Low | Python + CSS-like styling |
| Community | Active | Rich ecosystem (Rich, Textual, Textualize) |

### Candidate 4: Ink (TypeScript/React)

**Library**: [ink](https://github.com/vadimdemedes/ink)
**Language**: TypeScript
**SQLite**: better-sqlite3

| Criterion | Score | Notes |
|-----------|-------|-------|
| Rendering performance | Adequate | React reconciliation overhead |
| Widget ecosystem | Moderate | React component model, fewer TUI-specific widgets |
| Cross-platform | Yes | Node.js required |
| Binary distribution | Requires Node.js | Could bundle but heavy |
| Learning curve | Low for React devs | JSX in terminal |
| Community | Moderate | Niche but functional |

### Recommendation: Ratatui (Rust)

**Rationale**:
1. **Distribution alignment**: codebase-memory-mcp ships as a single static binary. The TUI should match this model -- no runtime dependencies for users.
2. **Performance**: Graph traversal and large node lists need efficient rendering. Ratatui's immediate mode avoids allocation per frame.
3. **SQLite integration**: rusqlite bundles SQLite, matching the zero-dependency philosophy.
4. **PDS ecosystem**: The ledger daemon is already Rust. Adding another Rust binary keeps the toolchain consistent.
5. **Tree widget**: Ratatui has a native Tree widget ideal for the module hierarchy view.

**Runner-up**: Bubble Tea. If the team prefers Go over Rust, Bubble Tea is an excellent alternative with a gentler learning curve. The pure-Go SQLite driver (modernc.org/sqlite) avoids CGo complications.

## Data Model

### SQLite Source Tables

The TUI reads directly from `~/.cache/codebase-memory-mcp/<project>.db`:

```sql
-- Core graph tables
nodes(id, project, label, name, qualified_name, file_path, start_line, end_line, properties)
edges(id, project, source_id, target_id, type, properties)
projects(name, indexed_at, root_path)

-- Indexes available
idx_nodes_label(project, label)     -- fast label filtering
idx_nodes_name(project, name)       -- fast name lookup
idx_nodes_file(project, file_path)  -- fast file path lookup
idx_edges_source(source_id, type)   -- outbound edge traversal
idx_edges_target(target_id, type)   -- inbound edge traversal
idx_edges_type(project, type)       -- edge type filtering

-- Full-text search
nodes_fts(name, qualified_name, label, file_path)  -- FTS5 virtual table
```

### Node Properties JSON

Functions carry structured metadata:
```json
{
  "complexity": 0,
  "lines": 15,
  "is_exported": true,
  "is_test": false,
  "is_entry_point": false,
  "docstring": "description text"
}
```

### View Queries

#### Module Tree View
```sql
-- Top-level folders
SELECT n.id, n.name, n.label
FROM nodes n
WHERE n.project = ? AND n.label = 'Folder'
  AND NOT EXISTS (
    SELECT 1 FROM edges e
    JOIN nodes parent ON e.source_id = parent.id
    WHERE e.target_id = n.id AND e.type = 'CONTAINS_FOLDER'
  )
ORDER BY n.name;

-- Children of a folder
SELECT n.id, n.name, n.label, n.file_path
FROM edges e
JOIN nodes n ON e.target_id = n.id
WHERE e.source_id = ? AND e.type IN ('CONTAINS_FOLDER', 'CONTAINS_FILE')
ORDER BY n.label DESC, n.name;  -- folders first, then files

-- Symbols defined in a file/module
SELECT n.id, n.name, n.label, n.start_line, n.end_line,
       json_extract(n.properties, '$.lines') as lines,
       json_extract(n.properties, '$.complexity') as complexity
FROM edges e
JOIN nodes n ON e.target_id = n.id
WHERE e.source_id = ? AND e.type = 'DEFINES'
ORDER BY n.start_line;
```

#### Function Signatures View
```sql
SELECT n.name, n.file_path, n.start_line, n.end_line,
       json_extract(n.properties, '$.lines') as lines,
       json_extract(n.properties, '$.complexity') as complexity,
       json_extract(n.properties, '$.is_exported') as exported,
       json_extract(n.properties, '$.is_test') as is_test,
       json_extract(n.properties, '$.docstring') as docstring,
       (SELECT COUNT(*) FROM edges e WHERE e.target_id = n.id AND e.type = 'CALLS') as callers,
       (SELECT COUNT(*) FROM edges e WHERE e.source_id = n.id AND e.type = 'CALLS') as callees
FROM nodes n
WHERE n.project = ? AND n.label = 'Function'
ORDER BY n.file_path, n.start_line;
```

#### Call Graph View
```sql
-- Outbound calls from a function
SELECT target.name, target.file_path, target.start_line, e.type
FROM edges e
JOIN nodes target ON e.target_id = target.id
WHERE e.source_id = ? AND e.type = 'CALLS';

-- Inbound calls to a function
SELECT source.name, source.file_path, source.start_line, e.type
FROM edges e
JOIN nodes source ON e.source_id = source.id
WHERE e.target_id = ? AND e.type = 'CALLS';

-- Full call chain (BFS, application-side traversal up to depth N)
-- Start from a function node, follow CALLS edges iteratively
```

#### Dependency View
```sql
-- File co-change relationships (which files change together)
SELECT
  n1.name as file1, n2.name as file2,
  json_extract(e.properties, '$.count') as change_count
FROM edges e
JOIN nodes n1 ON e.source_id = n1.id
JOIN nodes n2 ON e.target_id = n2.id
WHERE e.project = ? AND e.type = 'FILE_CHANGES_WITH'
ORDER BY json_extract(e.properties, '$.count') DESC;

-- Semantic relationships
SELECT
  n1.name as node1, n1.label as label1,
  n2.name as node2, n2.label as label2,
  e.type
FROM edges e
JOIN nodes n1 ON e.source_id = n1.id
JOIN nodes n2 ON e.target_id = n2.id
WHERE e.project = ? AND e.type IN ('SEMANTICALLY_RELATED', 'SIMILAR_TO', 'CONFIGURES')
ORDER BY e.type, n1.name;
```

#### Fuzzy Search
```sql
-- FTS5 search across all node names
SELECT n.id, n.name, n.label, n.file_path, n.start_line
FROM nodes_fts fts
JOIN nodes n ON n.qualified_name = fts.qualified_name
WHERE nodes_fts MATCH ? AND n.project = ?
ORDER BY rank
LIMIT 50;
```

## Wire Layouts

### View 1: Module Tree (Primary Navigation)

```
+-- [Project Panel] --------+-- [Detail Panel] ----------------------+
| portable-dev-system        | File: hooks/scripts/session-start.sh   |
|   agents/                  | Lines: 101  |  Functions: 0            |
|   docs/                    |                                        |
|   hooks/                   | Defined Symbols:                       |
|     hooks.json             |   LEDGER_SOCK (Variable, L21)          |
|     scripts/               |   LEDGER_STATUS (Variable, L23)        |
|   > session-start.sh  <-- |   WORKTREE_INFO (Variable, L28)        |
|       secret-scrub.sh      |   STALE_WARNING (Variable, L39)        |
|       mcp-secret-scrub.sh  |   WORKTREE_WARNING (Variable, L45)     |
|   skills/                  |   CONTEXT (Variable, L88)              |
|     swarm/                 |                                        |
|     team/                  | Co-changed Files:                      |
|     grill/                 |   hooks.json (8 times)                 |
|   scripts/                 |   sync-worktree-permissions.sh (3x)    |
|   install.sh               |                                        |
|                            |                                        |
+----------------------------+----------------------------------------+
| [F1 Tree] [F2 Functions] [F3 Calls] [F4 Deps] [/ Search] [q Quit] |
+--------------------------------------------------------------------+
```

### View 2: Function Signatures

```
+-- [Functions] ----------------------------------------------------------+
| Filter: [____________]  Sort: [File ▼]  Show: [All ▼]                   |
+-------------------------------------------------------------------------+
| Name                  | File                    | Lines | In | Out | Ex |
|=======================|=========================|=======|====|=====|====|
| install_plugin        | install.sh              |    42 |  1 |   8 | Y  |
| install_project       | install.sh              |    18 |  1 |   3 | Y  |
| install_claude_md     | install.sh              |    31 |  2 |   4 | Y  |
| cleanup_project       | install.sh              |    22 |  1 |   5 | Y  |
| install_security_se.. | install.sh              |    15 |  3 |   2 | Y  |
| run_tests             | install.sh              |    25 |  1 |   6 | Y  |
| is_sensitive          | hooks/scripts/secret-.. |     8 |  1 |   0 | Y  |
| scrub                 | hooks/scripts/mcp-se.. |    15 |  1 |   0 | Y  |
| run_hook              | scripts/test-hooks.sh   |    12 |  3 |   0 | Y  |
| assert_blocked        | scripts/test-hooks.sh   |     8 |  1 |   2 | Y  |
| wilson_ci             | scripts/run-eval.sh     |    10 |  1 |   0 | Y  |
+-------------------------------------------------------------------------+
| In=callers  Out=callees  Ex=exported    [Enter] Call graph  [/] Search  |
+-------------------------------------------------------------------------+
```

### View 3: Call Graph (Interactive)

```
+-- [Call Graph: install_plugin] -----------------------------------------+
|                                                                         |
|  Callers (1):                    Callees (8):                           |
|  +-----------------+             +------------------------+             |
|  | install.sh      |───CALLS───>| install_plugin         |             |
|  | (module-level)  |            +------------------------+             |
|  +-----------------+              │                                     |
|                                   ├──CALLS──> info                     |
|                                   ├──CALLS──> ok                       |
|                                   ├──CALLS──> warn                     |
|                                   ├──CALLS──> check_jq                 |
|                                   ├──CALLS──> check_python3            |
|                                   ├──CALLS──> check_gitleaks           |
|                                   │             └──CALLS──> warn       |
|                                   │             └──CALLS──> info       |
|                                   │             └──CALLS──> ok         |
|                                   ├──CALLS──> check_age                |
|                                   │             └──CALLS──> warn       |
|                                   │             └──CALLS──> info       |
|                                   │             └──CALLS──> ok         |
|                                   └──CALLS──> install_security_settings|
|                                                 └──CALLS──> warn       |
|                                                 └──CALLS──> ok         |
|                                                                         |
| Depth: [2 ▼]  Direction: [Both ▼]         [Enter] Focus  [Esc] Back   |
+-------------------------------------------------------------------------+
```

### View 4: Dependency View (File Co-change Heatmap)

```
+-- [Dependencies: FILE_CHANGES_WITH] -----------------------------------+
|                                                                         |
| File Pair                                        | Co-changes | Strength|
|==================================================|============|=========|
| install.sh <-> CHANGELOG.md                      |         12 | ████░░ |
| session-start.sh <-> hooks.json                  |          8 | ███░░░ |
| orchestrator.md <-> shared-rules.md              |          6 | ██░░░░ |
| swarm/SKILL.md <-> team/SKILL.md                 |          5 | ██░░░░ |
| secret-scrub.sh <-> mcp-secret-scrub.sh          |          4 | █░░░░░ |
| validator.md <-> worker.md                       |          3 | █░░░░░ |
| install.sh <-> settings.json                     |          3 | █░░░░░ |
|                                                                         |
| Semantic Relationships:                                                 |
| +--------------------- SEMANTICALLY_RELATED ----+-----------------+     |
| | efficiency-chart.sh                            | detect-patterns |    |
| +------------------------------------------------+-----------------+    |
|                                                                         |
| Filter: [All edge types ▼]                    [Enter] Detail  [q] Back |
+-------------------------------------------------------------------------+
```

### View 5: Search (Global Fuzzy Search)

```
+-- [Search] -------------------------------------------------------------+
| > session_start█                                                        |
+-------------------------------------------------------------------------+
| Results (5):                                                            |
|                                                                         |
| [Module] hooks/scripts/session-start.sh                                 |
|   L1-101 | 0 functions defined                                          |
|                                                                         |
| [Section] "SessionStart" in hooks.json                                  |
|   L3 | Hook configuration for SessionStart event                        |
|                                                                         |
| [Variable] WORKTREE_INFO in session-start.sh                            |
|   L28 | Worktree detection variable                                     |
|                                                                         |
| [Section] "SessionStart Detection" in worktree/SKILL.md                 |
|   Cross-reference to stale worktree detection                           |
|                                                                         |
| [Variable] LEDGER_STATUS in session-start.sh                            |
|   L23 | Ledger daemon status check                                      |
|                                                                         |
+-------------------------------------------------------------------------+
| [Enter] Open  [Tab] Filter by label  [Esc] Cancel                      |
+-------------------------------------------------------------------------+
```

## Architecture

### Component Model

```
+-----------+     +-----------+     +------------------+
| App State | <-- | Event     | <-- | Terminal Events  |
| (Model)   |     | Handler   |     | (crossterm)      |
+-----------+     +-----------+     +------------------+
      |                                      ^
      v                                      |
+-----------+     +-----------+     +------------------+
| View      | --> | Renderer  | --> | Terminal Buffer  |
| Functions |     | (ratatui) |     | (stdout)         |
+-----------+     +-----------+     +------------------+
      ^
      |
+-----------+
| DB Layer  |  (rusqlite, read-only connection)
| (queries) |  ~/.cache/codebase-memory-mcp/*.db
+-----------+
```

### Key Types

```rust
enum View {
    ModuleTree,
    FunctionList,
    CallGraph { focus: NodeId, depth: u8, direction: Direction },
    Dependencies { edge_type: EdgeType },
    Search { query: String },
}

struct AppState {
    project: String,
    db: Connection,          // rusqlite read-only
    current_view: View,
    tree_state: TreeState,   // expanded/collapsed nodes
    selected: Option<NodeId>,
    search_query: String,
    search_results: Vec<SearchResult>,
}

struct GraphNode {
    id: i64,
    label: NodeLabel,
    name: String,
    qualified_name: String,
    file_path: String,
    start_line: u32,
    end_line: u32,
    properties: NodeProperties,
}

struct GraphEdge {
    source_id: i64,
    target_id: i64,
    edge_type: EdgeType,
    properties: serde_json::Value,
}
```

### Key Interactions

1. **Module Tree navigation**: Arrow keys expand/collapse folders. Enter selects a file/module and shows its detail panel.
2. **Function list**: Sortable columns (name, file, lines, callers, callees). Enter on a function opens the Call Graph view focused on that function.
3. **Call Graph**: Displays caller/callee tree. Depth selector (1-5). Enter on a node re-centers the graph on that function.
4. **Dependencies**: Shows file co-change heatmap. Enter on a pair shows both files' symbols.
5. **Search**: Fuzzy search via FTS5. Results grouped by label. Enter navigates to the node in its natural view.

### Database Access Pattern

- Read-only connection (`SQLITE_OPEN_READONLY`)
- No WAL locking concerns (read-only doesn't conflict with codebase-memory-mcp writes)
- Query on demand (lazy loading) -- don't load entire graph into memory
- Cache frequently-accessed aggregates (function count per file, edge counts)
- Connection string: `~/.cache/codebase-memory-mcp/{project-name}.db`

### Project Discovery

```rust
fn discover_projects(cache_dir: &Path) -> Vec<Project> {
    // List *.db files in ~/.cache/codebase-memory-mcp/
    // For each, open and query projects table
    // Return list with name, root_path, node/edge counts
}
```

If multiple projects exist, show a project selector on launch. If launched from a repo directory, auto-select the matching project.

## Implementation Phases

1. **Phase 1**: Module Tree view + Detail panel. SQLite read-only connection. Basic navigation.
2. **Phase 2**: Function List view with sorting. Search via FTS5.
3. **Phase 3**: Call Graph view with BFS traversal. Depth control.
4. **Phase 4**: Dependency heatmap. Edge type filtering.
5. **Phase 5**: Polish: theming, resize handling, help overlay, config file.

## Build and Distribution

```bash
cargo build --release
# Output: target/release/cbm-tui (single binary, ~5MB)
# Install alongside codebase-memory-mcp in ~/.local/bin/
```

No runtime dependencies. Ships as a companion binary to codebase-memory-mcp.
