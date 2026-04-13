#!/bin/bash
# PDS codebase-context hook — injects structural codebase intelligence from
# codebase-memory-mcp into the SessionStart context.
#
# Called by session-start.sh. Returns a plain text summary (not JSON).
# Gracefully degrades: returns empty string if codebase-memory-mcp is not
# installed, not indexed, or queries fail.
#
# Token budget: ~2,048 tokens (roughly 1,500 words / 8,000 chars).
# Target latency: <2 seconds total (queries are <30ms each).
# The outer SessionStart hook enforces a 15-second hard timeout.

CBM_BIN="${CBM_BIN:-codebase-memory-mcp}"
CBM_CACHE="${CBM_CACHE_DIR:-$HOME/.cache/codebase-memory-mcp}"
MAX_CHARS=8000

# --- Check if codebase-memory-mcp is available ---
if ! command -v "$CBM_BIN" >/dev/null 2>&1; then
  exit 0
fi

# --- Detect project ---
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi
REPO_ROOT="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | sed 's|/.git$||')"
PROJECT_NAME=$(echo "$REPO_ROOT" | sed 's|^/||; s|/|-|g')

# Check if project is indexed
DB_FILE="$CBM_CACHE/${PROJECT_NAME}.db"
if [ ! -f "$DB_FILE" ]; then
  exit 0
fi

# --- Query helper ---
# Unwraps MCP envelope: {"content":[{"type":"text","text":"<json>"}]} -> <json>
query_cbm() {
  "$CBM_BIN" cli "$1" "$2" 2>/dev/null | python3 -c "
import json, sys
try:
    mcp = json.load(sys.stdin)
    if mcp.get('isError'): sys.exit(1)
    print(mcp['content'][0]['text'])
except: sys.exit(1)
" 2>/dev/null
}

# --- Gather data ---
ARCH_RAW=$(query_cbm "get_architecture" "{\"project\": \"$PROJECT_NAME\"}") || exit 0
FUNC_RAW=$(query_cbm "search_graph" "{\"label\": \"Function\", \"project\": \"$PROJECT_NAME\", \"limit\": 100}") || FUNC_RAW="{}"

# --- Compose summary ---
python3 - "$ARCH_RAW" "$FUNC_RAW" "$MAX_CHARS" << 'PYEOF'
import json, sys

arch_raw = sys.argv[1] if len(sys.argv) > 1 else "{}"
func_raw = sys.argv[2] if len(sys.argv) > 2 else "{}"
max_chars = int(sys.argv[3]) if len(sys.argv) > 3 else 8000

try:
    arch = json.loads(arch_raw)
except Exception:
    sys.exit(0)

lines = []

# Graph overview
total_nodes = arch.get("total_nodes", 0)
total_edges = arch.get("total_edges", 0)
labels = arch.get("node_labels", [])
label_parts = []
for l in labels:
    if l["label"] != "Project":
        label_parts.append("{} {}s".format(l["count"], l["label"]))
lines.append("Codebase graph: {} nodes, {} edges ({})".format(
    total_nodes, total_edges, ", ".join(label_parts[:6])))

# Edge summary
edges = arch.get("edge_types", [])
edge_parts = ["{} {}".format(e["count"], e["type"]) for e in edges if e["count"] > 0]
if edge_parts:
    lines.append("Relationships: {}".format(", ".join(edge_parts)))

# Functions
try:
    func_data = json.loads(func_raw)
    results = func_data.get("results", [])
except Exception:
    results = []

if results:
    by_callers = sorted(results, key=lambda r: r.get("in_degree", 0), reverse=True)
    hotspots = [r for r in by_callers if r.get("in_degree", 0) > 0][:10]

    if hotspots:
        lines.append("Key functions (by caller count):")
        for h in hotspots:
            lines.append("  {} ({}) -- {} callers, {} callees".format(
                h["name"], h.get("file_path", ""),
                h.get("in_degree", 0), h.get("out_degree", 0)))

    files = {}
    for r in results:
        fp = r.get("file_path", "")
        files.setdefault(fp, []).append(r["name"])
    if files:
        lines.append("Functions by file:")
        for fp in sorted(files.keys()):
            names = ", ".join(sorted(files[fp]))
            lines.append("  {}: {}".format(fp, names))

output = "\n".join(lines)
print(output[:max_chars])
PYEOF
