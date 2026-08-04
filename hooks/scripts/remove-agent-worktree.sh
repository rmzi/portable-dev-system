#!/bin/sh
# PDS — WorktreeRemove hook. Tears down the worktree that
# sync-worktree-permissions.sh created.
#
# Registering a WorktreeCreate hook takes ownership of worktree creation away
# from Claude Code's native git path (see that script's header and #182). The
# matching consequence is that PDS also owns removal — without this hook,
# every spawned worker would leave a worktree behind in .worktrees/, which
# accumulates across swarms and trips the Phase 6 teardown gate's
# "clean .worktrees/" check.
#
# stdin payload carries `worktreePath` (and/or `name`) plus `cwd`. Both are
# handled; `worktreePath` wins when present.
#
# Best-effort by design: a failed cleanup should never fail a session. Every
# path exits 0.

PAYLOAD=$(cat 2>/dev/null || true)
[ -n "$PAYLOAD" ] || exit 0

read_field() {
  printf '%s' "$PAYLOAD" | python3 -c "
import json, sys
try:
    print(json.load(sys.stdin).get('$1', '') or '')
except Exception:
    print('')
" 2>/dev/null || printf ''
}

WT_PATH=$(read_field worktreePath)
WT_NAME=$(read_field name)
SPAWN_CWD=$(read_field cwd)

[ -n "$SPAWN_CWD" ] && cd "$SPAWN_CWD" 2>/dev/null

REPO_ROOT="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | sed 's|/\.git$||')"
[ -n "$REPO_ROOT" ] || exit 0

if [ -z "$WT_PATH" ] && [ -n "$WT_NAME" ]; then
  WT_PATH="$REPO_ROOT/.worktrees/$WT_NAME"
fi
[ -n "$WT_PATH" ] || exit 0

# Refuse to touch anything outside this repo's .worktrees/ — the payload is
# untrusted input and `git worktree remove --force` deletes files.
case "$WT_PATH" in
  "$REPO_ROOT"/.worktrees/*) ;;
  *) exit 0 ;;
esac

git -C "$REPO_ROOT" worktree remove --force "$WT_PATH" 2>/dev/null || true
git -C "$REPO_ROOT" worktree prune 2>/dev/null || true

# Drop the auto-created branch if it has no commits of its own.
if [ -n "$WT_NAME" ]; then
  git -C "$REPO_ROOT" branch -d "$WT_NAME" 2>/dev/null || true
fi

exit 0
