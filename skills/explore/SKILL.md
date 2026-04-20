---
description: Structural codebase exploration using the codebase-memory-mcp SQLite index when one exists for the current project. Prefer over blind Grep when available.
---
# /explore — Structural Codebase Exploration

Before you `grep -r` or `Glob '**/*.py'` to orient in a codebase, check whether an index exists. If it does, prefer structural queries — fewer reads, better signal, real edges instead of string-match guesses.

## Invocation

```
/explore [optional search term or question]
```

## Detection

The codebase-memory-mcp index for the current project lives at:

```
~/.cache/codebase-memory-mcp/$(basename "$PWD").db
```

Check once at the start:

```bash
DB="$HOME/.cache/codebase-memory-mcp/$(basename "$PWD").db"
if [ -f "$DB" ]; then
  PROJECT="$(basename "$PWD")"
  # Index exists → use structural queries (next section)
else
  # Fall back to Grep / Glob as usual
  # Surface a one-line note: "No codebase-memory-mcp index for this repo — structural queries unavailable; using Grep."
fi
```

## Schema (relevant tables)

```
nodes(id, project, label, name, qualified_name, file_path, start_line, end_line, properties)
edges(id, project, source_id, target_id, type, properties)
nodes_fts(name, qualified_name, label, file_path)   -- FTS5 virtual table
```

- `nodes.label` ∈ `Folder`, `File`, `Function`, `Class`, `Variable`, …
- `edges.type` ∈ `CALLS`, `DEFINES`, `CONTAINS_FILE`, `CONTAINS_FOLDER`, `IMPORTS`, `FILE_CHANGES_WITH`, `SEMANTICALLY_RELATED`, …
- `nodes.properties` is JSON — read via `json_extract(properties, '$.key')`

## Useful queries

Run with `sqlite3 -readonly "$DB" "<query>"` (read-only flag prevents any accidental writes).

### Who calls function X?

```sql
SELECT n2.qualified_name, n2.file_path, n2.start_line
FROM edges e
JOIN nodes n1 ON e.target_id = n1.id
JOIN nodes n2 ON e.source_id = n2.id
WHERE n1.name = 'X' AND e.type = 'CALLS' AND e.project = 'PROJECT';
```

### What does X call?

```sql
SELECT n2.qualified_name, n2.file_path, n2.start_line
FROM edges e
JOIN nodes n1 ON e.source_id = n1.id
JOIN nodes n2 ON e.target_id = n2.id
WHERE n1.name = 'X' AND e.type = 'CALLS' AND e.project = 'PROJECT';
```

### Module tree under a path

```sql
SELECT DISTINCT file_path FROM nodes
WHERE project = 'PROJECT' AND file_path LIKE 'src/auth/%'
ORDER BY file_path;
```

### Fuzzy symbol search

```sql
SELECT n.name, n.label, n.file_path, n.start_line
FROM nodes_fts fts
JOIN nodes n ON n.qualified_name = fts.qualified_name
WHERE nodes_fts MATCH 'login*' AND n.project = 'PROJECT'
ORDER BY rank LIMIT 20;
```

### Symbols defined in a file

```sql
SELECT n.name, n.label, n.start_line, n.end_line
FROM edges e
JOIN nodes n ON e.target_id = n.id
WHERE e.source_id = (SELECT id FROM nodes WHERE project = 'PROJECT' AND file_path = 'path/to/file.py' LIMIT 1)
  AND e.type = 'DEFINES'
ORDER BY n.start_line;
```

### High-complexity functions (triage targets)

```sql
SELECT name, file_path, start_line,
       json_extract(properties, '$.complexity') AS complexity,
       json_extract(properties, '$.lines') AS lines
FROM nodes
WHERE project = 'PROJECT' AND label = 'Function'
  AND json_extract(properties, '$.complexity') > 10
ORDER BY complexity DESC LIMIT 20;
```

## Fallback when no DB

Use Grep and Glob as you would normally. Surface one line so the user knows why structural exploration isn't active:

> No codebase-memory-mcp index for this repo — structural queries unavailable; using Grep.

The user can create an index by running `codebase-memory-mcp` against the repo (separate tool, not installed by PDS).

## Why prefer the index

- **Edges are real.** `CALLS` is a parsed call, not a string match. No false positives from comments, strings, or similarly-named symbols in other scopes.
- **Fewer reads.** One SQL query returns what would otherwise take multiple `grep` passes plus file reads to verify context.
- **Ranked results.** FTS5 BM25 ranking surfaces likely matches first — useful when a name is ambiguous.

## See Also

- `/pds:verify` — completion self-check before declaring done
- `/pds:grill` — requirement interrogation before implementation
