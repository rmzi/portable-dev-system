#!/usr/bin/env bash
# assemble-diary.sh — Compose a PDS dev-diary document and post/edit it on a GitHub issue.
#
# Inputs (env):
#   BRANCH  — current branch (default: git branch --show-current)
#   ISSUE   — issue number (required; caller parses from branch name)
#   SINCE   — session-window start ref (default: merge-base with origin/main)
#   MODE    — post (default; auto-detects edit via marker), post-dry (stdout only)
#
# Produces: diary markdown + collapsed raw transcript, posted or edited as a single
# canonical comment on issue #ISSUE. On failure, writes to $TMPDIR and surfaces the path.
#
# Requires: bash, python3, jq, gh, git. export-session.sh alongside this script.

set -euo pipefail

# Experimental feature gate — off by default.
# Enable with PDS_DIARY=1 (or on/true/yes) in the environment.
case "${PDS_DIARY:-}" in
  1|on|true|yes) ;;
  *) echo "assemble-diary.sh: disabled (set PDS_DIARY=1 to enable)" >&2; exit 0 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPORT_SESSION="$SCRIPT_DIR/export-session.sh"
MARKER='<!-- pds:diary -->'

BRANCH="${BRANCH:-$(git branch --show-current)}"
ISSUE="${ISSUE:-}"
MODE="${MODE:-post}"

if [ -z "$ISSUE" ]; then
  echo "error: ISSUE is required (pass as env var)" >&2
  exit 2
fi

if [ -z "${SINCE:-}" ]; then
  SINCE="$(git merge-base HEAD origin/main 2>/dev/null || git merge-base HEAD main 2>/dev/null || echo '')"
fi
if [ -z "$SINCE" ]; then
  echo "error: could not resolve SINCE — pass explicitly" >&2
  exit 2
fi

SHIP_DATE="$(date +%Y-%m-%d)"
VERSION_SHIPPED="$(cat VERSION 2>/dev/null || echo 'unreleased')"
SHORT_RANGE="$(git rev-parse --short "$SINCE")..$(git rev-parse --short HEAD)"

# --- Gather: git data ---
COMMITS_TSV="$(git log "$SINCE..HEAD" --format='%H%x09%at%x09%s' 2>/dev/null || true)"
COMMIT_SUBJECTS="$(git log "$SINCE..HEAD" --format='%s' 2>/dev/null || true)"

# --- Gather: instincts delta ---
INSTINCTS_ADDED=""
if [ -f .claude/instincts.md ]; then
  INSTINCTS_ADDED="$(git log "$SINCE..HEAD" -p -- .claude/instincts.md 2>/dev/null \
    | grep -E '^\+### ' | sed 's/^\+### //' || true)"
fi

# --- Gather: auto-memory delta ---
MEMORY_ENTRIES=""
CWD_HASH="$(echo -n "$(pwd)" | tr '/' '-')"
for candidate in "$HOME/.claude/projects/$CWD_HASH/memory" "$HOME/.claude/projects/-$CWD_HASH/memory"; do
  if [ -d "$candidate" ]; then
    SINCE_EPOCH="$(git show -s --format=%at "$SINCE" 2>/dev/null || echo 0)"
    while IFS= read -r -d '' f; do
      FILE_MTIME="$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo 0)"
      if [ "$FILE_MTIME" -ge "$SINCE_EPOCH" ]; then
        HEADER="$(awk '/^name:/{name=$2} /^type:/{type=$2} /^description:/{$1=""; desc=$0} END{print type "\t" name "\t" desc}' "$f")"
        MEMORY_ENTRIES="$MEMORY_ENTRIES$HEADER"$'\n'
      fi
    done < <(find "$candidate" -maxdepth 1 -name '*.md' ! -name 'MEMORY.md' -print0 2>/dev/null)
    break
  fi
done

# --- Gather: raw transcript (for ★ Insight parsing and collapsed block) ---
# Pass through TRANSCRIPT_PATH (canonical, from SessionEnd hook) if set; otherwise
# export-session.sh falls back to CWD-hash discovery. Always filter to current branch
# so the transcript reflects this session's work, not the entire project history.
TRANSCRIPT=""
if [ -x "$EXPORT_SESSION" ]; then
  TRANSCRIPT="$(FILTER_BRANCH="$BRANCH" TRANSCRIPT_PATH="${TRANSCRIPT_PATH:-}" \
    "$EXPORT_SESSION" 2>/dev/null || true)"
fi

INSIGHTS=""
if [ -n "$TRANSCRIPT" ]; then
  INSIGHTS="$(printf '%s\n' "$TRANSCRIPT" | python3 -c '
import sys, re
txt = sys.stdin.read()
blocks = re.findall(r"★ Insight ─+\n(.*?)\n─+", txt, flags=re.DOTALL)
seen = set()
for b in blocks:
    for line in b.splitlines():
        s = line.strip("- \t")
        if s and s not in seen:
            seen.add(s)
            print(f"- {s}")
' 2>/dev/null || true)"
fi

# --- Route signals into (well / wrong) buckets ---
WELL=""
WRONG=""

# Instincts → well (recorded learnings are wins)
if [ -n "$INSTINCTS_ADDED" ]; then
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    WELL="$WELL- Instinct recorded: $line"$'\n'
  done <<< "$INSTINCTS_ADDED"
fi

# Memory entries → route by type
if [ -n "$MEMORY_ENTRIES" ]; then
  while IFS=$'\t' read -r mtype mname mdesc; do
    [ -z "$mname" ] && continue
    mdesc="${mdesc# }"
    case "$mtype" in
      feedback)
        WRONG="$WRONG- Feedback captured ($mname):$mdesc"$'\n' ;;
      project|user|reference)
        WELL="$WELL- Memory saved ($mtype/$mname):$mdesc"$'\n' ;;
    esac
  done <<< "$MEMORY_ENTRIES"
fi

# Commit-based wrong signals (fixups, reverts)
FIXUPS="$(printf '%s\n' "$COMMIT_SUBJECTS" | grep -iE '^(fixup!|revert |fix:.*regression|chore: revert)' || true)"
if [ -n "$FIXUPS" ]; then
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    WRONG="$WRONG- Correction: $line"$'\n'
  done <<< "$FIXUPS"
fi

# Insights folded into both (heuristic: default to well)
if [ -n "$INSIGHTS" ]; then
  WELL="$WELL$INSIGHTS"$'\n'
fi

[ -z "$WELL" ] && WELL="- (no signals captured)"$'\n'
[ -z "$WRONG" ] && WRONG="- (no corrections recorded)"$'\n'

# --- Summary (derived from commit subjects) ---
SUMMARY="$(printf '%s\n' "$COMMIT_SUBJECTS" | python3 -c '
import sys
subjects = [l.strip() for l in sys.stdin if l.strip()]
if not subjects:
    print("No commits in session window.")
else:
    top = [s for s in subjects if not s.startswith(("chore: bump", "chore: archive"))][:3]
    if not top:
        top = subjects[:3]
    print("; ".join(top) + ".")
' 2>/dev/null || echo "See commits.")"

# --- Timeline (from TSV) ---
TIMELINE="$(printf '%s\n' "$COMMITS_TSV" | python3 -c '
import sys
from datetime import datetime
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    parts = line.split("\t")
    if len(parts) < 3:
        continue
    sha, epoch, subj = parts[0], parts[1], parts[2]
    try:
        ts = datetime.fromtimestamp(int(epoch)).strftime("%H:%M")
    except Exception:
        ts = "?"
    print(f"- {ts} — {subj}")
' 2>/dev/null || echo "- (no commits)")"
[ -z "$TIMELINE" ] && TIMELINE="- (no commits)"

# --- Compose diary ---
DIARY_FILE="${TMPDIR:-/tmp}/pds-diary-$ISSUE-$(date +%Y%m%d-%H%M%S)-$$.md"
{
  echo "$MARKER"
  echo "# Dev Diary — $BRANCH ($SHIP_DATE)"
  echo ""
  echo "**Issue:** #$ISSUE  **Version shipped:** $VERSION_SHIPPED  **Commits:** \`$SHORT_RANGE\`"
  echo ""
  echo "## Summary"
  echo "$SUMMARY"
  echo ""
  echo "## Timeline"
  echo "$TIMELINE"
  echo ""
  echo "## What went well"
  printf '%s' "$WELL"
  echo ""
  echo "## What went wrong"
  printf '%s' "$WRONG"
  echo ""
  echo "---"
  echo ""
  echo "<details>"
  echo "<summary>Raw conversation transcript (click to expand)</summary>"
  echo ""
  if [ -n "$TRANSCRIPT" ]; then
    printf '%s\n' "$TRANSCRIPT"
  else
    echo "_(transcript unavailable)_"
  fi
  echo ""
  echo "</details>"
} > "$DIARY_FILE"

# --- Dry-run: just emit ---
if [ "$MODE" = "post-dry" ] || [ "$MODE" = "dry" ]; then
  cat "$DIARY_FILE"
  exit 0
fi

# --- Post or edit ---
if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI not found — diary saved to $DIARY_FILE" >&2
  exit 3
fi

REPO_SLUG="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo '')"
if [ -z "$REPO_SLUG" ]; then
  echo "could not resolve repo — diary saved to $DIARY_FILE" >&2
  exit 3
fi

EXISTING_ID="$(gh api "repos/$REPO_SLUG/issues/$ISSUE/comments" --paginate \
  --jq ".[] | select(.body | contains(\"$MARKER\")) | .id" 2>/dev/null | head -1 || true)"

if [ -n "$EXISTING_ID" ]; then
  if jq -Rs '{body: .}' < "$DIARY_FILE" \
     | gh api "repos/$REPO_SLUG/issues/comments/$EXISTING_ID" -X PATCH --input - >/dev/null 2>&1; then
    echo "Edited diary comment on issue #$ISSUE (id=$EXISTING_ID)"
    exit 0
  fi
else
  if gh issue comment "$ISSUE" --body-file "$DIARY_FILE" >/dev/null 2>&1; then
    echo "Posted diary comment on issue #$ISSUE"
    exit 0
  fi
fi

echo "gh call failed — diary saved to $DIARY_FILE" >&2
exit 3
