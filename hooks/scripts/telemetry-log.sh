#!/bin/sh
# PDS PostToolUse (Skill|Agent) hook — logs skill invocations and agent spawns via ledger
cat | ~/.ledger/bin/ledger hook skill 2>/dev/null || true
