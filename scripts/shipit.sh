#!/bin/bash
# shipit — end-to-end ship flow for a committed feature branch.
#
# Takes feature work that's already committed on a non-main branch and drives
# it all the way to a published PR:
#   1. Verify clean tree + branch ≠ main
#   2. Bump version (VERSION + co-located files + CHANGELOG entry)
#   3. Commit bump
#   4. Push branch (sets upstream on first push)
#   5. Open a GitHub issue with auto-generated body (commits since last tag,
#      journal artifact optionally attached)
#   6. Open a PR targeting main, linked to the issue
#
# Uses curl + `gh auth token` directly to work around macOS TLS keychain
# deny errors (OSStatus -26276) that intermittently break `gh issue create`
# and `gh pr create`. Same outcome, more reliable path.
#
# Usage:
#   shipit patch|minor|major [options]
#
# Options:
#   --title "..."      Issue + PR title. Default: derived from latest feature commit subject.
#   --body FILE        Use FILE as the issue body. Default: auto-generated from commits since last tag.
#   --attach-journal   Append contents of $XDG_DATA_HOME/pds/journal/ entries as collapsible appendix.
#   --draft            Open PR as draft.
#   --dry-run          Show every step without performing mutations.
#
# Exit codes:
#   0 — shipped
#   1 — precondition failed (dirty tree, on main, etc.)
#   2 — a sub-step failed (push, issue, PR); partial state possible

set -euo pipefail

# ---------- helpers -------------------------------------------------------

c_reset=$'\033[0m'
c_bold=$'\033[1m'
c_dim=$'\033[2m'
c_cyan=$'\033[36m'
c_yellow=$'\033[33m'
c_red=$'\033[31m'
c_green=$'\033[32m'

info()  { printf '%s>%s %s\n' "$c_cyan$c_bold" "$c_reset" "$1" >&2; }
ok()    { printf '%s✓%s %s\n' "$c_green" "$c_reset" "$1" >&2; }
warn()  { printf '%s!%s %s\n' "$c_yellow" "$c_reset" "$1" >&2; }
die()   { printf '%s✗%s %s\n' "$c_red" "$c_reset" "$1" >&2; exit "${2:-1}"; }

# ---------- args ----------------------------------------------------------

BUMP=""
TITLE=""
BODY_FILE=""
ATTACH_JOURNAL=0
DRAFT=0
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    patch|minor|major)  BUMP="$1"; shift ;;
    --title)            TITLE="$2"; shift 2 ;;
    --body)             BODY_FILE="$2"; shift 2 ;;
    --attach-journal)   ATTACH_JOURNAL=1; shift ;;
    --draft)            DRAFT=1; shift ;;
    --dry-run)          DRY_RUN=1; shift ;;
    -h|--help)          sed -n '1,40p' "$0"; exit 0 ;;
    *)                  die "unknown arg: $1" ;;
  esac
done

[ -z "$BUMP" ] && die "bump level required: patch | minor | major"

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '%s  dry-run: %s%s\n' "$c_dim" "$*" "$c_reset" >&2
  else
    eval "$@"
  fi
}

# ---------- preconditions -------------------------------------------------

# Operate on the CURRENT worktree, not the main repo root. When run from a
# worktree at `.worktrees/<feature>`, shipit should ship *that* branch, not
# the main repo's HEAD. `--show-toplevel` gives the worktree root; CLAUDE.md
# calls this out as a footgun for worktree *creation* skills (where main
# repo is what you want), but for shipit the worktree root IS the target.
WORKTREE_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$WORKTREE_ROOT" ] && die "not inside a git repository"
cd "$WORKTREE_ROOT"

BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
  die "refusing to ship from $BRANCH — check out a feature branch first"
fi

# Fail if uncommitted changes — shipit expects the feature to be committed.
if ! git diff --quiet || ! git diff --cached --quiet; then
  git status --short >&2
  die "working tree has uncommitted changes; commit or stash first"
fi

# Detect primary version file.
if [ -f VERSION ]; then
  VERSION_FILE="VERSION"
  CURRENT=$(cat VERSION | tr -d '[:space:]')
elif [ -f package.json ]; then
  VERSION_FILE="package.json"
  CURRENT=$(python3 -c 'import json; print(json.load(open("package.json"))["version"])')
elif [ -f Cargo.toml ]; then
  VERSION_FILE="Cargo.toml"
  CURRENT=$(grep -m1 '^version' Cargo.toml | sed 's/.*"\(.*\)".*/\1/')
else
  die "no version file found (expected VERSION, package.json, or Cargo.toml)"
fi

IFS='.' read -r MAJ MIN PAT <<< "$CURRENT"
case "$BUMP" in
  patch) NEW="$MAJ.$MIN.$((PAT + 1))" ;;
  minor) NEW="$MAJ.$((MIN + 1)).0" ;;
  major) NEW="$((MAJ + 1)).0.0" ;;
esac

info "current: $CURRENT  →  new: $NEW ($BUMP)"

# Derive default title from latest non-chore commit subject if not provided.
if [ -z "$TITLE" ]; then
  TITLE=$(git log -1 --pretty='%s' --invert-grep --grep='^chore' 2>/dev/null || git log -1 --pretty='%s')
  # Strip conventional-commit prefix like "feat(foo): bar" → "bar"
  TITLE=$(echo "$TITLE" | sed -E 's|^[a-z]+(\([^)]+\))?: ?||')
fi

# Commit range for auto-generated issue body.
# Prefer the last git tag; fall back to the last "chore: bump version to" commit
# (this repo doesn't tag its ships, so tag-less repos get a useful range too).
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
if [ -n "$LAST_TAG" ]; then
  RANGE="$LAST_TAG..HEAD"
  RANGE_LABEL="$LAST_TAG"
else
  LAST_BUMP=$(git log --grep='^chore: bump version to' --pretty='%H' -n 1 2>/dev/null)
  if [ -n "$LAST_BUMP" ]; then
    RANGE="$LAST_BUMP..HEAD"
    RANGE_LABEL="last-bump ($(git log -1 --pretty='%s' "$LAST_BUMP"))"
  else
    RANGE="HEAD"
    RANGE_LABEL="initial"
  fi
fi

info "title: $TITLE"
info "range: $RANGE ($RANGE_LABEL)"

# ---------- bump ----------------------------------------------------------

bump_version() {
  info "bumping version files"
  run "echo '$NEW' > VERSION"
  if [ -f .claude-plugin/plugin.json ]; then
    run "python3 -c 'import json; p=\".claude-plugin/plugin.json\"; d=json.load(open(p)); d[\"version\"]=\"$NEW\"; import os; open(p,\"w\").write(json.dumps(d, indent=2)+\"\\n\")'"
  fi
  if [ -f cli/Cargo.toml ]; then
    run "sed -i.bak 's/^version = \"$CURRENT\"/version = \"$NEW\"/' cli/Cargo.toml && rm -f cli/Cargo.toml.bak"
  fi
}

update_changelog() {
  info "updating CHANGELOG.md"
  [ ! -f CHANGELOG.md ] && { warn "no CHANGELOG.md — skipping"; return; }
  TODAY=$(date +%Y-%m-%dT%H:%M:%S%z | sed 's/\(..\)$/:\1/')
  # Build changelog entry from commits since last tag.
  COMMITS=$(git log --pretty='- %s' "$RANGE" | grep -v '^- chore: bump' || true)
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '%s  dry-run changelog entry:%s\n## [%s] - %s\n\n### Changed\n%s\n' "$c_dim" "$c_reset" "$NEW" "$TODAY" "$COMMITS" >&2
    return
  fi
  python3 - "$NEW" "$TODAY" "$COMMITS" <<'PY'
import sys, pathlib
new, today, commits = sys.argv[1], sys.argv[2], sys.argv[3]
p = pathlib.Path("CHANGELOG.md")
text = p.read_text()
entry = f"## [{new}] - {today}\n\n### Changed\n{commits}\n\n"
# Insert after the top banner (before the first existing "## [" heading).
idx = text.find("\n## [")
if idx < 0:
    p.write_text(text.rstrip() + "\n\n" + entry)
else:
    p.write_text(text[:idx+1] + entry + text[idx+1:])
PY
}

bump_version
update_changelog

info "committing bump"
run "git add VERSION CHANGELOG.md .claude-plugin/plugin.json cli/Cargo.toml 2>/dev/null || true"
run "git commit -m 'chore: bump version to $NEW' --allow-empty"

# ---------- push ----------------------------------------------------------

info "pushing $BRANCH"
if git rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
  run "git push"
else
  run "git push -u origin $BRANCH"
fi

# ---------- issue body ----------------------------------------------------

TMP_BODY="${TMPDIR:-/tmp}/shipit-body-$$.md"
trap 'rm -f "$TMP_BODY" "$TMP_BODY.json"' EXIT

if [ -n "$BODY_FILE" ]; then
  cp "$BODY_FILE" "$TMP_BODY"
else
  # Auto-generate from commit log + feature commit bodies.
  {
    echo "## Summary"
    echo
    echo "Shipped in v$NEW. Branch: \`$BRANCH\`."
    echo
    echo "## Commits since $RANGE_LABEL"
    echo
    git log --pretty='- %h %s' "$RANGE"
    echo
    echo "## Feature-commit bodies"
    echo
    git log --pretty='### %h %s%n%n%b%n---' "$RANGE" --no-merges | grep -v '^chore: bump' || true
  } > "$TMP_BODY"
fi

if [ "$ATTACH_JOURNAL" -eq 1 ]; then
  JOURNAL="${XDG_DATA_HOME:-$HOME/.local/share}/pds/journal"
  if [ -d "$JOURNAL" ] && [ -n "$(find "$JOURNAL" -type f 2>/dev/null)" ]; then
    info "attaching journal entries from $JOURNAL"
    {
      echo
      echo "<details>"
      echo "<summary>Journal appendix</summary>"
      echo
      find "$JOURNAL" -type f -name '*.md' | sort | while read -r f; do
        printf '\n---\n\n### `%s`\n\n```markdown\n' "$(basename "$f")"
        cat "$f"
        printf '\n```\n'
      done
      echo
      echo "</details>"
    } >> "$TMP_BODY"
  fi
fi

# ---------- issue + PR ----------------------------------------------------

REMOTE_URL=$(git config --get remote.origin.url)
# Extract owner/repo from URL (handles SSH and HTTPS forms).
GH_REPO=$(echo "$REMOTE_URL" | sed -E 's|.*github.com[/:]([^/]+/[^/]+)(\.git)?$|\1|' | sed 's/\.git$//')

TOKEN=$(gh auth token 2>/dev/null || true)
[ -z "$TOKEN" ] && die "no GitHub token from \`gh auth token\` — run \`gh auth login\`" 2

gh_api() {
  local method=$1 path=$2 data=${3:-}
  if [ -n "$data" ]; then
    curl -sSf -X "$method" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      -H "Content-Type: application/json" \
      "https://api.github.com$path" --data-binary "$data"
  else
    curl -sSf -X "$method" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com$path"
  fi
}

info "opening issue on $GH_REPO"
if [ "$DRY_RUN" -eq 1 ]; then
  echo "(dry-run) would POST to /repos/$GH_REPO/issues with title=\"$TITLE\" body=<$(wc -c < "$TMP_BODY") bytes>"
  ISSUE_NUMBER="<n>"
  ISSUE_URL="https://github.com/$GH_REPO/issues/<n>"
else
  jq -Rn --arg title "$TITLE" --rawfile body "$TMP_BODY" '{title: $title, body: $body}' > "$TMP_BODY.json"
  ISSUE_JSON=$(gh_api POST "/repos/$GH_REPO/issues" @"$TMP_BODY.json" 2>&1) || die "issue create failed: $ISSUE_JSON" 2
  ISSUE_NUMBER=$(echo "$ISSUE_JSON" | python3 -c 'import json,sys;print(json.load(sys.stdin)["number"])')
  ISSUE_URL=$(echo "$ISSUE_JSON" | python3 -c 'import json,sys;print(json.load(sys.stdin)["html_url"])')
  ok "issue #$ISSUE_NUMBER: $ISSUE_URL"
fi

# PR body: short, links the issue (GitHub auto-closes on merge).
PR_BODY=$(cat <<EOF
## Summary
Ships v$NEW. See #$ISSUE_NUMBER for full context, design decisions, and follow-ups.

## Test plan
- [ ] CI green
- [ ] Manual validation per harness in \`scripts/test-*.sh\` (if applicable)

Closes #$ISSUE_NUMBER

Generated with [PDS](https://github.com/rmzi/portable-dev-system)
EOF
)

info "opening PR targeting main"
if [ "$DRY_RUN" -eq 1 ]; then
  echo "(dry-run) would POST to /repos/$GH_REPO/pulls with head=$BRANCH base=main title=\"$TITLE\""
else
  PR_PAYLOAD=$(python3 -c "
import json, sys
print(json.dumps({
    'title': sys.argv[1],
    'head': sys.argv[2],
    'base': 'main',
    'body': sys.argv[3],
    'draft': bool(int(sys.argv[4]))
}))
" "$TITLE" "$BRANCH" "$PR_BODY" "$DRAFT")
  PR_JSON=$(gh_api POST "/repos/$GH_REPO/pulls" "$PR_PAYLOAD" 2>&1) || die "PR create failed: $PR_JSON" 2
  PR_URL=$(echo "$PR_JSON" | python3 -c 'import json,sys;print(json.load(sys.stdin)["html_url"])')
  ok "PR: $PR_URL"
fi

echo
ok "shipped v$NEW"
echo "  issue: $ISSUE_URL"
[ "$DRY_RUN" -eq 0 ] && echo "  PR:    $PR_URL"
