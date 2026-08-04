#!/usr/bin/env bash
# Tests for the WorktreeCreate / WorktreeRemove hook pair.
#
# These hooks own agent worktree lifecycle: registering a WorktreeCreate hook
# takes creation away from Claude Code's native git path, so if the hook
# doesn't create a worktree and print its absolute path to stdout, every
# worktree-isolated agent (pds:worker) fails to spawn and swarms cannot
# dispatch. That is exactly what shipped in #170/#182 — a hook that exited 0
# with no output.
#
# The contract asserted here (verified against Claude Code 2.1.221):
#   - fires with CWD = main repo, before any worktree exists
#   - receives {"name":..., "cwd":..., "hook_event_name":"WorktreeCreate"} on stdin
#   - must print the created worktree's absolute path on stdout, exit 0

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CREATE_HOOK="$SCRIPT_DIR/../scripts/sync-worktree-permissions.sh"
REMOVE_HOOK="$SCRIPT_DIR/../scripts/remove-agent-worktree.sh"

RED=$'\033[1;31m'; GREEN=$'\033[1;32m'; NC=$'\033[0m'
pass=0; fail=0

ok()   { echo "  ${GREEN}✓${NC} PASS: $1"; pass=$((pass+1)); }
bad()  { echo "  ${RED}✗${NC} FAIL: $1"; fail=$((fail+1)); }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want '$3', got '$2')"; fi; }

BASE="$(mktemp -d "${TMPDIR:-/tmp}/pds-wt-test.XXXXXX")" || { echo "mktemp failed"; exit 1; }
BASE="$(cd "$BASE" && pwd -P)"
trap 'rm -rf "$BASE"' EXIT

REPO="$BASE/repo"
git init --quiet "$REPO"
git -C "$REPO" config user.email "test@pds.local"
git -C "$REPO" config user.name "PDS Test"
printf 'x\n' > "$REPO/file"
git -C "$REPO" add -A
git -C "$REPO" commit --quiet -m "init"

echo ""
echo "Test: WorktreeCreate / WorktreeRemove hooks"

# --- 1. Creates the worktree and prints its absolute path -------------------
out="$(printf '{"name":"agent-t1","cwd":"%s","hook_event_name":"WorktreeCreate"}' "$REPO" | sh "$CREATE_HOOK")"
check "prints created worktree path" "$out" "$REPO/.worktrees/agent-t1"
if [ -e "$REPO/.worktrees/agent-t1/.git" ]; then ok "worktree actually created"; else bad "worktree not created"; fi

# --- 2. Path is inside the repo, per CLAUDE.md worktree hygiene -------------
case "$out" in
  "$REPO"/.worktrees/*) ok "worktree lives in-repo under .worktrees/" ;;
  *) bad "worktree escaped .worktrees/ ($out)" ;;
esac

# --- 3. Idempotent — re-firing for the same name reprints, doesn't error ----
out2="$(printf '{"name":"agent-t1","cwd":"%s"}' "$REPO" | sh "$CREATE_HOOK")"
check "idempotent on repeat fire" "$out2" "$out"

# --- 4. Mirrors settings.local.json into the worktree ----------------------
mkdir -p "$REPO/.claude"
printf '{}\n' > "$REPO/.claude/settings.local.json"
printf '{"name":"agent-t2","cwd":"%s"}' "$REPO" | sh "$CREATE_HOOK" >/dev/null
if [ -L "$REPO/.worktrees/agent-t2/.claude/settings.local.json" ]; then
  ok "settings.local.json symlinked into worktree"
else
  bad "settings.local.json not symlinked"
fi

# --- 5. A missing symlink source must not suppress the path ----------------
rm -f "$REPO/.claude/settings.local.json"
out3="$(printf '{"name":"agent-t3","cwd":"%s"}' "$REPO" | sh "$CREATE_HOOK")"
check "prints path even with no settings.local.json" "$out3" "$REPO/.worktrees/agent-t3"

# --- 6. Empty payload (hand-run) exits clean and silent --------------------
out4="$(printf '' | sh "$CREATE_HOOK")"; rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out4" ]; then ok "empty payload: silent, exit 0"; else bad "empty payload: rc=$rc out='$out4'"; fi

# --- 7. Non-git cwd fails loudly rather than returning nothing -------------
NOTGIT="$BASE/notgit"
mkdir -p "$NOTGIT"
if printf '{"name":"agent-t4","cwd":"%s"}' "$NOTGIT" | sh "$CREATE_HOOK" >/dev/null 2>&1; then
  bad "non-git cwd should exit non-zero"
else
  ok "non-git cwd exits non-zero"
fi

# --- 8. Regression guard for #170's silent-exit shape ----------------------
# The hook must never exit 0 with empty stdout on a valid git payload — that
# is the precise failure Claude Code reports as "hook succeeded but returned
# no worktree path".
out5="$(printf '{"name":"agent-t5","cwd":"%s"}' "$REPO" | sh "$CREATE_HOOK")"; rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out5" ]; then
  bad "#170 regression: exit 0 with no path on a valid payload"
else
  ok "#170 regression guard: valid payload always yields a path"
fi

# --- 9. WorktreeRemove tears the worktree down ----------------------------
printf '{"name":"agent-t1","worktreePath":"%s/.worktrees/agent-t1","cwd":"%s"}' "$REPO" "$REPO" | sh "$REMOVE_HOOK"
if [ -d "$REPO/.worktrees/agent-t1" ]; then bad "worktree not removed"; else ok "worktree removed"; fi

# --- 10. Remove works from `name` alone -----------------------------------
printf '{"name":"agent-t2","cwd":"%s"}' "$REPO" | sh "$REMOVE_HOOK"
if [ -d "$REPO/.worktrees/agent-t2" ]; then bad "name-only removal failed"; else ok "name-only removal works"; fi

# --- 11. Remove refuses paths outside .worktrees/ -------------------------
GUARD="$BASE/do-not-delete"
mkdir -p "$GUARD"
printf '{"worktreePath":"%s","cwd":"%s"}' "$GUARD" "$REPO" | sh "$REMOVE_HOOK"
if [ -d "$GUARD" ]; then ok "refuses to remove paths outside .worktrees/"; else bad "deleted a path outside .worktrees/"; fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$fail" -eq 0 ]; then
  echo "  ${GREEN}✓${NC} All $pass worktree hook tests passed"
  exit 0
fi
echo "  ${RED}✗${NC} $fail of $((pass+fail)) worktree hook tests failed"
exit 1
