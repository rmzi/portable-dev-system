#!/bin/sh
# PDS InstructionsLoaded hook — logs session init via ledger
echo '{}' | ~/.ledger/bin/ledger hook init 2>/dev/null || true
