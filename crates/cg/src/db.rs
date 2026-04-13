use anyhow::{Context, Result};
use rusqlite::Connection;
use serde::Deserialize;
use std::collections::HashMap;
use std::path::{Path, PathBuf};

/// A project indexed by codebase-memory-mcp.
#[derive(Debug, Clone)]
pub struct Project {
    pub name: String,
    pub root_path: String,
    pub indexed_at: String,
}

/// A node in the code graph.
#[derive(Debug, Clone)]
pub struct Node {
    pub id: i64,
    pub label: String,
    pub name: String,
    pub qualified_name: String,
    pub file_path: String,
    pub start_line: i64,
    pub end_line: i64,
    pub properties: NodeProperties,
}

/// Parsed properties JSON from a node.
#[derive(Debug, Clone, Default, Deserialize)]
pub struct NodeProperties {
    #[serde(default)]
    pub extension: String,
    #[serde(default)]
    pub complexity: i64,
    #[serde(default)]
    pub lines: i64,
    #[serde(default)]
    pub is_exported: bool,
    #[serde(default)]
    pub is_test: bool,
    #[serde(default)]
    pub is_entry_point: bool,
    #[serde(default)]
    pub docstring: String,
}

/// An edge in the code graph.
#[derive(Debug, Clone)]
pub struct Edge {
    pub source_id: i64,
    pub target_id: i64,
    pub edge_type: String,
}

/// A search result from FTS5.
#[derive(Debug, Clone)]
pub struct SearchResult {
    pub node: Node,
    pub rank: f64,
}

/// Read-only handle to a codebase-memory-mcp SQLite database.
pub struct Db {
    conn: Connection,
    pub project: String,
}

impl Db {
    pub fn open(path: &Path, project: &str) -> Result<Self> {
        let conn = Connection::open_with_flags(
            path,
            rusqlite::OpenFlags::SQLITE_OPEN_READ_ONLY | rusqlite::OpenFlags::SQLITE_OPEN_NO_MUTEX,
        )
        .with_context(|| format!("Failed to open database: {}", path.display()))?;
        Ok(Self {
            conn,
            project: project.to_string(),
        })
    }

    /// List all indexed projects.
    pub fn list_projects(path: &Path) -> Result<Vec<Project>> {
        let conn = Connection::open_with_flags(
            path,
            rusqlite::OpenFlags::SQLITE_OPEN_READ_ONLY | rusqlite::OpenFlags::SQLITE_OPEN_NO_MUTEX,
        )?;
        let mut stmt = conn.prepare("SELECT name, root_path, indexed_at FROM projects")?;
        let rows = stmt.query_map([], |row| {
            Ok(Project {
                name: row.get(0)?,
                root_path: row.get(1)?,
                indexed_at: row.get(2)?,
            })
        })?;
        rows.collect::<Result<Vec<_>, _>>().map_err(Into::into)
    }

    /// Get node counts by label.
    pub fn label_counts(&self) -> Result<Vec<(String, i64)>> {
        let mut stmt = self.conn.prepare(
            "SELECT label, COUNT(*) FROM nodes WHERE project = ?1 GROUP BY label ORDER BY COUNT(*) DESC",
        )?;
        let rows = stmt.query_map([&self.project], |row| Ok((row.get(0)?, row.get(1)?)))?;
        rows.collect::<Result<Vec<_>, _>>().map_err(Into::into)
    }

    /// Get edge counts by type.
    pub fn edge_type_counts(&self) -> Result<Vec<(String, i64)>> {
        let mut stmt = self.conn.prepare(
            "SELECT type, COUNT(*) FROM edges WHERE project = ?1 GROUP BY type ORDER BY COUNT(*) DESC",
        )?;
        let rows = stmt.query_map([&self.project], |row| Ok((row.get(0)?, row.get(1)?)))?;
        rows.collect::<Result<Vec<_>, _>>().map_err(Into::into)
    }

    /// Get children of a node (via CONTAINS_FILE, CONTAINS_FOLDER, DEFINES edges).
    pub fn children(&self, parent_id: i64) -> Result<Vec<Node>> {
        let mut stmt = self.conn.prepare(
            "SELECT n.id, n.label, n.name, n.qualified_name, n.file_path, n.start_line, n.end_line, n.properties
             FROM edges e
             JOIN nodes n ON e.target_id = n.id
             WHERE e.source_id = ?1 AND e.type IN ('CONTAINS_FILE', 'CONTAINS_FOLDER', 'DEFINES')
             ORDER BY
               CASE n.label
                 WHEN 'Folder' THEN 0
                 WHEN 'File' THEN 1
                 WHEN 'Module' THEN 2
                 WHEN 'Class' THEN 3
                 WHEN 'Function' THEN 4
                 WHEN 'Variable' THEN 5
                 WHEN 'Section' THEN 6
                 ELSE 7
               END,
               n.name",
        )?;
        let rows = stmt.query_map([parent_id], |row| {
            let props_str: String = row.get(7)?;
            Ok(Node {
                id: row.get(0)?,
                label: row.get(1)?,
                name: row.get(2)?,
                qualified_name: row.get(3)?,
                file_path: row.get(4)?,
                start_line: row.get(5)?,
                end_line: row.get(6)?,
                properties: serde_json::from_str(&props_str).unwrap_or_default(),
            })
        })?;
        rows.collect::<Result<Vec<_>, _>>().map_err(Into::into)
    }

    /// Get the project root node.
    pub fn root_node(&self) -> Result<Node> {
        let mut stmt = self.conn.prepare(
            "SELECT id, label, name, qualified_name, file_path, start_line, end_line, properties
             FROM nodes WHERE project = ?1 AND label = 'Project' LIMIT 1",
        )?;
        stmt.query_row([&self.project], |row| {
            let props_str: String = row.get(7)?;
            Ok(Node {
                id: row.get(0)?,
                label: row.get(1)?,
                name: row.get(2)?,
                qualified_name: row.get(3)?,
                file_path: row.get(4)?,
                start_line: row.get(5)?,
                end_line: row.get(6)?,
                properties: serde_json::from_str(&props_str).unwrap_or_default(),
            })
        })
        .map_err(Into::into)
    }

    /// Get all functions for the function list view.
    pub fn all_functions(&self) -> Result<Vec<Node>> {
        let mut stmt = self.conn.prepare(
            "SELECT id, label, name, qualified_name, file_path, start_line, end_line, properties
             FROM nodes WHERE project = ?1 AND label = 'Function'
             ORDER BY name",
        )?;
        let rows = stmt.query_map([&self.project], |row| {
            let props_str: String = row.get(7)?;
            Ok(Node {
                id: row.get(0)?,
                label: row.get(1)?,
                name: row.get(2)?,
                qualified_name: row.get(3)?,
                file_path: row.get(4)?,
                start_line: row.get(5)?,
                end_line: row.get(6)?,
                properties: serde_json::from_str(&props_str).unwrap_or_default(),
            })
        })?;
        rows.collect::<Result<Vec<_>, _>>().map_err(Into::into)
    }

    /// Count callers (incoming CALLS edges) for a node.
    pub fn caller_count(&self, node_id: i64) -> Result<i64> {
        self.conn
            .query_row(
                "SELECT COUNT(*) FROM edges WHERE target_id = ?1 AND type = 'CALLS'",
                [node_id],
                |row| row.get(0),
            )
            .map_err(Into::into)
    }

    /// Count callees (outgoing CALLS edges) for a node.
    pub fn callee_count(&self, node_id: i64) -> Result<i64> {
        self.conn
            .query_row(
                "SELECT COUNT(*) FROM edges WHERE source_id = ?1 AND type = 'CALLS'",
                [node_id],
                |row| row.get(0),
            )
            .map_err(Into::into)
    }

    /// Batch caller/callee counts for a list of node IDs. Returns map of id → (callers, callees).
    pub fn batch_call_counts(&self, node_ids: &[i64]) -> Result<HashMap<i64, (i64, i64)>> {
        let mut map: HashMap<i64, (i64, i64)> = HashMap::new();
        if node_ids.is_empty() {
            return Ok(map);
        }

        // Build a temporary table approach for efficiency
        let placeholders: Vec<String> = node_ids.iter().map(|_| "?".to_string()).collect();
        let ph = placeholders.join(",");

        // Callers: edges where target_id is in our set
        let sql = format!(
            "SELECT target_id, COUNT(*) FROM edges WHERE target_id IN ({ph}) AND type = 'CALLS' GROUP BY target_id"
        );
        let mut stmt = self.conn.prepare(&sql)?;
        let params: Vec<&dyn rusqlite::ToSql> = node_ids.iter().map(|id| id as &dyn rusqlite::ToSql).collect();
        let rows = stmt.query_map(params.as_slice(), |row| {
            Ok((row.get::<_, i64>(0)?, row.get::<_, i64>(1)?))
        })?;
        for row in rows {
            let (id, count) = row?;
            map.entry(id).or_insert((0, 0)).0 = count;
        }

        // Callees: edges where source_id is in our set
        let sql = format!(
            "SELECT source_id, COUNT(*) FROM edges WHERE source_id IN ({ph}) AND type = 'CALLS' GROUP BY source_id"
        );
        let mut stmt = self.conn.prepare(&sql)?;
        let params: Vec<&dyn rusqlite::ToSql> = node_ids.iter().map(|id| id as &dyn rusqlite::ToSql).collect();
        let rows = stmt.query_map(params.as_slice(), |row| {
            Ok((row.get::<_, i64>(0)?, row.get::<_, i64>(1)?))
        })?;
        for row in rows {
            let (id, count) = row?;
            map.entry(id).or_insert((0, 0)).1 = count;
        }

        Ok(map)
    }

    /// Get co-changed files for a given file path.
    pub fn co_changed_files(&self, node_id: i64) -> Result<Vec<(String, String)>> {
        let mut stmt = self.conn.prepare(
            "SELECT n2.name, e.properties
             FROM edges e
             JOIN nodes n2 ON e.target_id = n2.id
             WHERE e.source_id = ?1 AND e.type = 'FILE_CHANGES_WITH'
             UNION ALL
             SELECT n2.name, e.properties
             FROM edges e
             JOIN nodes n2 ON e.source_id = n2.id
             WHERE e.target_id = ?1 AND e.type = 'FILE_CHANGES_WITH'",
        )?;
        let rows = stmt.query_map([node_id], |row| Ok((row.get(0)?, row.get(1)?)))?;
        rows.collect::<Result<Vec<_>, _>>().map_err(Into::into)
    }

    /// Get symbols defined in a file.
    pub fn symbols_in_file(&self, file_id: i64) -> Result<Vec<Node>> {
        let mut stmt = self.conn.prepare(
            "SELECT n.id, n.label, n.name, n.qualified_name, n.file_path, n.start_line, n.end_line, n.properties
             FROM edges e
             JOIN nodes n ON e.target_id = n.id
             WHERE e.source_id = ?1 AND e.type = 'DEFINES'
             AND n.label IN ('Function', 'Class', 'Variable')
             ORDER BY n.start_line",
        )?;
        let rows = stmt.query_map([file_id], |row| {
            let props_str: String = row.get(7)?;
            Ok(Node {
                id: row.get(0)?,
                label: row.get(1)?,
                name: row.get(2)?,
                qualified_name: row.get(3)?,
                file_path: row.get(4)?,
                start_line: row.get(5)?,
                end_line: row.get(6)?,
                properties: serde_json::from_str(&props_str).unwrap_or_default(),
            })
        })?;
        rows.collect::<Result<Vec<_>, _>>().map_err(Into::into)
    }

    /// FTS5 search across all nodes.
    pub fn search(&self, query: &str) -> Result<Vec<SearchResult>> {
        if query.trim().is_empty() {
            return Ok(Vec::new());
        }
        // Escape special FTS5 characters and append wildcard
        let safe_query = query.replace('"', "\"\"");
        let fts_query = format!("\"{safe_query}\"*");

        let mut stmt = self.conn.prepare(
            "SELECT n.id, n.label, n.name, n.qualified_name, n.file_path, n.start_line, n.end_line, n.properties, fts.rank
             FROM nodes_fts fts
             JOIN nodes n ON n.id = fts.rowid
             WHERE nodes_fts MATCH ?1 AND n.project = ?2
             ORDER BY fts.rank
             LIMIT 100",
        )?;
        let rows = stmt.query_map(rusqlite::params![fts_query, self.project], |row| {
            let props_str: String = row.get(7)?;
            Ok(SearchResult {
                node: Node {
                    id: row.get(0)?,
                    label: row.get(1)?,
                    name: row.get(2)?,
                    qualified_name: row.get(3)?,
                    file_path: row.get(4)?,
                    start_line: row.get(5)?,
                    end_line: row.get(6)?,
                    properties: serde_json::from_str(&props_str).unwrap_or_default(),
                },
                rank: row.get(8)?,
            })
        })?;
        rows.collect::<Result<Vec<_>, _>>().map_err(Into::into)
    }

    /// Get a single node by ID.
    pub fn node_by_id(&self, id: i64) -> Result<Node> {
        let mut stmt = self.conn.prepare(
            "SELECT id, label, name, qualified_name, file_path, start_line, end_line, properties
             FROM nodes WHERE id = ?1",
        )?;
        stmt.query_row([id], |row| {
            let props_str: String = row.get(7)?;
            Ok(Node {
                id: row.get(0)?,
                label: row.get(1)?,
                name: row.get(2)?,
                qualified_name: row.get(3)?,
                file_path: row.get(4)?,
                start_line: row.get(5)?,
                end_line: row.get(6)?,
                properties: serde_json::from_str(&props_str).unwrap_or_default(),
            })
        })
        .map_err(Into::into)
    }
}

/// Discover all database files in the codebase-memory-mcp cache directory.
pub fn discover_databases() -> Result<Vec<PathBuf>> {
    let cache_dir = dirs_cache().join("codebase-memory-mcp");
    if !cache_dir.exists() {
        return Ok(Vec::new());
    }
    let mut dbs = Vec::new();
    for entry in std::fs::read_dir(&cache_dir)? {
        let entry = entry?;
        let path = entry.path();
        if path.extension().is_some_and(|e| e == "db") {
            dbs.push(path);
        }
    }
    dbs.sort();
    Ok(dbs)
}

/// Platform-aware cache directory.
fn dirs_cache() -> PathBuf {
    if let Ok(home) = std::env::var("HOME") {
        #[cfg(target_os = "macos")]
        return PathBuf::from(home).join(".cache");
        #[cfg(not(target_os = "macos"))]
        return PathBuf::from(home).join(".cache");
    }
    PathBuf::from("/tmp")
}
