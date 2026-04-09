#!/bin/sh
# PDS PostToolUse (Write|Edit) hook — logs file modification events via ledger
cat | ~/.ledger/bin/ledger hook file 2>/dev/null || true
