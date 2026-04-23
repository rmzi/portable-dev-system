#!/usr/bin/env bash
# Seed a fresh PDS integration-test repo from the fixture template.
# Usage: scripts/seed-integration.sh [target-dir]
#   default target: $TMPDIR/pds-integration-test
# Output: prints the absolute path of the seeded repo to stdout.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXTURE_DIR="$REPO_ROOT/tests/fixtures/integration-minimal"

TARGET="${1:-${TMPDIR:-/tmp}/pds-integration-test}"
TARGET="${TARGET%/}"  # strip trailing slash

if [ ! -d "$FIXTURE_DIR" ]; then
  echo "fixture dir missing: $FIXTURE_DIR" >&2
  exit 1
fi

# Wipe and re-seed
rm -rf "$TARGET"
mkdir -p "$TARGET"
cp -R "$FIXTURE_DIR/." "$TARGET/"

# Initialize git with a single baseline commit
cd "$TARGET"
git init -q
git -c user.email=pds-integration@test -c user.name="PDS Integration" add .
git -c user.email=pds-integration@test -c user.name="PDS Integration" commit -q -m "seed: integration-minimal fixture"

echo "$TARGET"
