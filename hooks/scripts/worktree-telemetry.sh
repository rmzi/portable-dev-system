#!/bin/sh
# PDS WorktreeCreate hook — logs worktree creation via ledger
cat | ~/.ledger/bin/ledger hook worktree 2>/dev/null || true
echo ok
