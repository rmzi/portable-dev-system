#!/usr/bin/env bash
# assemble-finish-writeup.sh — Rewrite a GitHub issue's body from its kickoff
# shape into a populated finish-writeup, per the evolving-body pattern (#154)
# applied to the 7-section format (#156): body = current state, prior state
# preserved as a comment, never edited away silently.
#
# Inputs (env):
#   BRANCH  — current branch (default: git branch --show-current)
#   ISSUE   — issue number (required; caller parses from branch name)
#   SINCE   — session-window start ref (default: merge-base with origin/main)
#   MODE    — post (default), post-dry (stdout only, no gh calls)
#
# Mechanics:
#   1. Fetch the issue's CURRENT body.
#   2. Post it as a comment — "### Kickoff (preserved)" the first time this
#      issue goes through a finish-writeup, "### Snapshot (preserved) —
#      <date>" on every rewrite after that (detected via a second marker
#      appended to the body on first rewrite, not re-added on later ones).
#   3. Carry forward Decisions / Risks / Acceptance Criteria / Full Plan
#      verbatim from the old body (mid-flight edits already updated them —
#      see /pds:ticket section 3; this script must not clobber that).
#   4. Recompute TL;DR (hoisted final-outcome summary, not the kickoff intent).
#   5. Populate Dev Diary and Full Conversation by calling assemble-diary.sh
#      in dry-run mode and extracting its Timeline/well/wrong sections and
#      its collapsed transcript block — this script does not re-implement
#      that gathering (git log, instincts delta, memory entries, shepherd
#      journal parsing already live there; mirror, don't invent).
#   6. Full Conversation embeds inline if the transcript is small; if it's
#      over ~60k chars, commits it to docs/conversations/<date>-<issue>-
#      <slug>.md instead and links it (#156 acceptance criteria B2/B3).
#      PDS's own docs/conversations/ is git-tracked, not gitignored — a
#      plain `git add`, no -f needed (unlike the motivating repo in #156).
#
# Requires: bash, python3, jq, gh, git. assemble-diary.sh + export-session.sh
# alongside this script.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSEMBLE_DIARY="$SCRIPT_DIR/assemble-diary.sh"
EVOLVING_MARKER='<!-- pds:evolving-body -->'
REWRITTEN_MARKER='<!-- pds:finish-writeup-applied -->'
SIZE_THRESHOLD=60000

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

if ! command -v gh >/dev/null 2>&1; then
  echo "error: gh CLI not found" >&2
  exit 3
fi

REPO_SLUG="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo '')"
if [ -z "$REPO_SLUG" ]; then
  echo "error: could not resolve repo" >&2
  exit 3
fi

# --- 1. Fetch current body ---
OLD_BODY="$(gh issue view "$ISSUE" --json body --jq '.body' 2>/dev/null || echo '')"
if [ -z "$OLD_BODY" ]; then
  echo "error: could not fetch issue #$ISSUE body" >&2
  exit 3
fi

# --- Determine preserve-comment title ---
if printf '%s' "$OLD_BODY" | grep -qF "$REWRITTEN_MARKER"; then
  PRESERVE_TITLE="### Snapshot (preserved) — $SHIP_DATE"
  FIRST_REWRITE=false
else
  PRESERVE_TITLE="### Kickoff (preserved)"
  FIRST_REWRITE=true
fi

# --- Extract a section from the old body: "## Name" up to the next "## " ---
extract_section() {
  local name="$1"
  printf '%s' "$OLD_BODY" | python3 -c '
import sys, re
name = sys.argv[1]
txt = sys.stdin.read()
pat = r"(?ms)^## " + re.escape(name) + r"\s*\n(.*?)(?=^## |\Z)"
m = re.search(pat, txt)
print(m.group(1).strip() if m else "")
' "$name"
}

OLD_DECISIONS="$(extract_section "Decisions")"
OLD_RISKS="$(extract_section "Risks")"
OLD_AC="$(extract_section "Acceptance Criteria")"
OLD_PLAN="$(extract_section "Full Plan")"

[ -z "$OLD_DECISIONS" ] && OLD_DECISIONS="_(none recorded at kickoff)_"
[ -z "$OLD_RISKS" ] && OLD_RISKS="_(none recorded at kickoff)_"
[ -z "$OLD_AC" ] && OLD_AC="_(none recorded at kickoff)_"
[ -z "$OLD_PLAN" ] && OLD_PLAN="_(none recorded at kickoff)_"

# --- Get the diary document from assemble-diary.sh (dry-run — no side effects) ---
DIARY_DOC=""
if [ -x "$ASSEMBLE_DIARY" ]; then
  DIARY_DOC="$(BRANCH="$BRANCH" ISSUE="$ISSUE" SINCE="$SINCE" MODE=post-dry PDS_DIARY=1 "$ASSEMBLE_DIARY" 2>/dev/null || true)"
fi

extract_diary_section() {
  local name="$1"
  printf '%s' "$DIARY_DOC" | python3 -c '
import sys, re
name = sys.argv[1]
txt = sys.stdin.read()
pat = r"(?ms)^## " + re.escape(name) + r"\s*\n(.*?)(?=^## |\Z|^---\s*$)"
m = re.search(pat, txt)
print(m.group(1).strip() if m else "")
' "$name"
}

TIMELINE="$(extract_diary_section "Timeline")"
WELL="$(extract_diary_section "What went well")"
WRONG="$(extract_diary_section "What went wrong")"
SUMMARY="$(extract_diary_section "Summary")"

[ -z "$TIMELINE" ] && TIMELINE="_(no commits in session window)_"
[ -z "$WELL" ] && WELL="_(no signals captured)_"
[ -z "$WRONG" ] && WRONG="_(no corrections recorded)_"
[ -z "$SUMMARY" ] && SUMMARY="See commits."

DEV_DIARY="### Chronology
$TIMELINE

### What went well
$WELL

### What went wrong
$WRONG"

# --- TL;DR: hoisted final-outcome summary (not the kickoff intent) ---
TLDR="$SUMMARY"

# --- Full Conversation: extract the raw transcript block, embed or link by size ---
RAW_TRANSCRIPT="$(printf '%s' "$DIARY_DOC" | python3 -c '
import sys, re
txt = sys.stdin.read()
m = re.search(r"(?ms)<summary>Raw conversation transcript.*?</summary>\n\n(.*?)\n\n</details>", txt)
print(m.group(1) if m else "")
')"

CONVO_SECTION=""
CONVO_LINK_LINE=""
if [ -z "$RAW_TRANSCRIPT" ]; then
  CONVO_SECTION="_(transcript unavailable)_"
elif [ "${#RAW_TRANSCRIPT}" -gt "$SIZE_THRESHOLD" ]; then
  # Oversized — commit to docs/conversations/ and link, don't embed (#156 B2/B3)
  SLUG="$(echo "$BRANCH" | sed -E 's|^[a-z]+/[0-9]+-||; s/[^a-zA-Z0-9]+/-/g' | tr '[:upper:]' '[:lower:]')"
  CONVO_FILE="docs/conversations/${SHIP_DATE}-${ISSUE}-${SLUG}.md"
  mkdir -p "$(dirname "$CONVO_FILE")"
  printf '%s\n' "$RAW_TRANSCRIPT" > "$CONVO_FILE"
  if [ "$MODE" != "post-dry" ] && [ "$MODE" != "dry" ]; then
    git add "$CONVO_FILE"
    git commit -m "docs: archive full conversation for #$ISSUE ($SHIP_DATE)" -- "$CONVO_FILE" >/dev/null 2>&1 || true
  fi
  CONVO_SECTION="Transcript exceeded the inline-embed size threshold (${#RAW_TRANSCRIPT} chars) — committed separately: [\`$CONVO_FILE\`](../../blob/main/$CONVO_FILE)"
  CONVO_LINK_LINE="Full conversation transcript (committed separately, too large to embed): $CONVO_FILE"
else
  CONVO_SECTION="<details>
<summary>Raw conversation transcript (click to expand)</summary>

$RAW_TRANSCRIPT

</details>"
fi

# --- Compose the new body ---
WRITEUP_FILE="${TMPDIR:-/tmp}/pds-finish-writeup-$ISSUE-$(date +%Y%m%d-%H%M%S)-$$.md"
{
  echo "$EVOLVING_MARKER"
  echo "$REWRITTEN_MARKER"
  echo ""
  echo "## TL;DR"
  echo ""
  echo "$TLDR"
  echo ""
  echo "## Decisions"
  echo ""
  echo "$OLD_DECISIONS"
  echo ""
  echo "## Risks"
  echo ""
  echo "$OLD_RISKS"
  echo ""
  echo "## Acceptance Criteria"
  echo ""
  echo "$OLD_AC"
  echo ""
  echo "## Full Plan"
  echo ""
  echo "$OLD_PLAN"
  echo ""
  echo "## Dev Diary"
  echo ""
  echo "$DEV_DIARY"
  echo ""
  echo "## Full Conversation"
  echo ""
  echo "$CONVO_SECTION"
} > "$WRITEUP_FILE"

# --- Dry-run: emit and stop ---
if [ "$MODE" = "post-dry" ] || [ "$MODE" = "dry" ]; then
  cat "$WRITEUP_FILE"
  echo "---"
  echo "preserve_title: $PRESERVE_TITLE"
  echo "conversation_link_line: $CONVO_LINK_LINE"
  exit 0
fi

# --- Post the old body as a preserved comment, then overwrite ---
PRESERVE_FILE="${TMPDIR:-/tmp}/pds-preserve-$ISSUE-$(date +%Y%m%d-%H%M%S)-$$.md"
{
  echo "$PRESERVE_TITLE"
  echo ""
  echo "$OLD_BODY"
} > "$PRESERVE_FILE"

if ! gh issue comment "$ISSUE" --body-file "$PRESERVE_FILE" >/dev/null 2>&1; then
  echo "warning: failed to post preserve comment — writeup saved to $WRITEUP_FILE, not applying body overwrite" >&2
  exit 3
fi

if gh issue edit "$ISSUE" --body-file "$WRITEUP_FILE" >/dev/null 2>&1; then
  echo "Rewrote issue #$ISSUE body ($([ "$FIRST_REWRITE" = true ] && echo "first rewrite — kickoff preserved" || echo "subsequent rewrite — snapshot preserved"))"
  echo "conversation_link_line: $CONVO_LINK_LINE"
  exit 0
fi

echo "gh issue edit failed — writeup saved to $WRITEUP_FILE (preserve comment was already posted)" >&2
exit 3
