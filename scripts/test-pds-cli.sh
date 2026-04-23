#!/bin/bash
# PDS CLI — end-to-end validation harness.
#
# Sandboxes HOME to $TMPDIR/pds-e2e/ so CLI writes never touch your real settings.
# Walks through every capability with manual checkpoints. At each one, eyeball
# the output, type what you see (or press enter to proceed), and flag anything
# that looks wrong.
#
# Usage (from any worktree of portable-dev-system):
#   bash scripts/test-pds-cli.sh
# Cleanup:
#   rm -rf "${TMPDIR:-/tmp}/pds-e2e"
#
# Covers 17 checkpoints across every sync phase: preset expansion, JSON merge,
# CLAUDE.md marker management, global gitignore, TOFU fingerprint persistence,
# reconcile-with-removals (shape change drops entries), project-scope opt-in,
# doctor.

set -euo pipefail

# --- Config ---------------------------------------------------------------

# Resolve repo root — works from any worktree, any machine.
REPO="${REPO:-$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | sed 's|/\.git$||')}"
if [ -z "$REPO" ] || [ ! -d "$REPO/cli" ]; then
  echo "error: could not locate portable-dev-system repo root with cli/ subdir" >&2
  echo "run from a PDS worktree, or set REPO env var" >&2
  exit 1
fi

SANDBOX="${TMPDIR:-/tmp}/pds-e2e"
HOME_SB="$SANDBOX/home"
PDS_BIN="$REPO/cli/target/debug/pds"

# --- Helpers --------------------------------------------------------------

c_reset=$'\033[0m'
c_dim=$'\033[2m'
c_bold=$'\033[1m'
c_cyan=$'\033[36m'
c_yellow=$'\033[33m'
c_green=$'\033[32m'

step_num=0
checkpoint() {
  step_num=$((step_num + 1))
  echo
  echo "${c_bold}${c_cyan}━━━ Checkpoint ${step_num}: $1 ${c_reset}"
  echo "${c_dim}Expected: $2${c_reset}"
  echo
}

pause() {
  echo
  echo "${c_yellow}↳ Press enter to continue, or Ctrl-C to abort. Note anything unexpected for Claude.${c_reset}"
  read -r _
}

run() {
  echo "${c_dim}\$ $*${c_reset}"
  "$@" || { echo "${c_yellow}(exit $?)${c_reset}"; return 0; }
}

# --- Sandbox setup --------------------------------------------------------
# Create the sandbox directory tree now, but DO NOT override HOME yet — rustup
# needs the real HOME to locate its toolchain for the build below.

rm -rf "$SANDBOX"
mkdir -p "$HOME_SB/.claude" "$HOME_SB/.config/pds" "$HOME_SB/.config/git" \
         "$HOME_SB/.local/share/pds" "$HOME_SB/.cache/pds"
touch "$HOME_SB/.gitconfig"

# Seed a realistic pre-existing ~/.claude/settings.json so we can watch the
# merge (not a clobber) behavior.
cat > "$HOME_SB/.claude/settings.json" <<'JSON'
{
  "permissions": {
    "allow": ["Read", "Write", "Edit"],
    "deny": ["Bash(rm -rf /)"]
  },
  "env": {
    "EXISTING_USER_VALUE": "should_survive"
  }
}
JSON

# Seed a project CLAUDE.md with PDS markers so Phase F has something to manage.
cat > "$HOME_SB/CLAUDE.md" <<'MD'
# Test Project CLAUDE.md

User-owned content above the markers must survive untouched.

<!-- pds:start -->
OLD MANAGED CONTENT (should be replaced by pds sync)
<!-- pds:end -->

User-owned content below the markers must also survive.
MD

# --- Build ----------------------------------------------------------------

echo "${c_bold}${c_green}PDS end-to-end validation harness${c_reset}"
echo "Sandbox: $SANDBOX"
echo "Repo:    $REPO"
echo
echo "Building CLI (cargo build)..."
# Respect an existing rustup default if configured; otherwise pin stable for
# this invocation only (no global state change).
if ! rustup default 2>/dev/null | grep -q '^.'; then
  export RUSTUP_TOOLCHAIN="${RUSTUP_TOOLCHAIN:-stable}"
  echo "  (no rustup default configured — using RUSTUP_TOOLCHAIN=$RUSTUP_TOOLCHAIN for this run)"
  # Ensure the toolchain is installed (first-time only; noop if already present).
  rustup toolchain install "$RUSTUP_TOOLCHAIN" --profile minimal 2>&1 | tail -3 || {
    echo "rustup toolchain install failed — run 'rustup default stable' and retry."; exit 1;
  }
fi
(cd "$REPO/cli" && cargo build 2>&1 | tail -3)

if [ ! -x "$PDS_BIN" ]; then
  echo "Binary not found at $PDS_BIN"
  exit 1
fi

# --- Activate sandbox (after build) ---------------------------------------
# Now that the binary exists, redirect HOME and XDG so every CLI invocation
# that follows writes into the sandbox instead of your real home.
export HOME="$HOME_SB"
export XDG_CONFIG_HOME="$HOME_SB/.config"
export XDG_DATA_HOME="$HOME_SB/.local/share"
export XDG_CACHE_HOME="$HOME_SB/.cache"
export CLAUDE_PLUGIN_ROOT="$REPO"
export GIT_CONFIG_GLOBAL="$HOME_SB/.gitconfig"
# Defense-in-depth: cd into the sandbox so any CWD-based path (project-scope
# settings.json) resolves inside the sandbox even if a phase tries to write
# without --project.
cd "$HOME_SB"

# --- Checkpoints ----------------------------------------------------------

checkpoint "CLI help" \
  "5 subcommands listed: sync, config, archive, doctor, plugins"
run "$PDS_BIN" --help
pause

checkpoint "Config path" \
  "Prints $HOME_SB/.config/pds/config.yaml (sandboxed, not your real home)"
run "$PDS_BIN" config path
pause

checkpoint "Doctor — no config yet" \
  "All 5 checks green. Config file says '(missing — PDS will use defaults)'"
run "$PDS_BIN" doctor
pause

checkpoint "Config show — schema defaults" \
  "version: 1; shepherd.tiers: [med, heavy]; health.serious_min: 90; modality: numpad-friendly"
run "$PDS_BIN" config show
pause

checkpoint "Config get — single key without a config file" \
  "Prints 90 (the schema default). Hooks will use this exact path."
run "$PDS_BIN" config get health.serious_min
pause

# Seed a real config now.
cp "$REPO/examples/config.yaml" "$HOME_SB/.config/pds/config.yaml"
# Tweak it a little so we can watch the override flow too.
sed -i.bak 's/serious_min: 90/serious_min: 45/' "$HOME_SB/.config/pds/config.yaml"
rm "$HOME_SB/.config/pds/config.yaml.bak"

checkpoint "Config get — with user override" \
  "Prints 45 (the value we just wrote to config.yaml)."
run "$PDS_BIN" config get health.serious_min
pause

checkpoint "Sync --dry-run — preview only" \
  "Diffs ONLY for: ~/.claude/settings.json (preset expansion), global gitignore
   (new managed block), CLAUDE.md (old managed content replaced).
   CRITICAL: no diff for any path outside $SANDBOX. Also expect a 'note:' line
   saying project-scope writes were skipped because --project wasn't passed.
   No files should be written."
run "$PDS_BIN" sync --dry-run --skip plugins
pause

echo "${c_dim}Verifying dry-run did NOT touch anything...${c_reset}"
before_hash=$(md5 -q "$HOME_SB/.claude/settings.json" 2>/dev/null || md5sum "$HOME_SB/.claude/settings.json" | awk '{print $1}')
if [ -f "$HOME_SB/.cache/pds/sync-fingerprint.sha256" ]; then
  fp_status="PRESENT (unexpected — dry-run should never write the fingerprint)"
else
  fp_status="absent (correct)"
fi
echo "  settings.json content hash: $before_hash"
echo "  fingerprint file: $fp_status"
pause

checkpoint "Sync --yes — actually write" \
  "Same diff, followed by silent success. Writes settings.json, gitignore, CLAUDE.md section."
run "$PDS_BIN" sync --yes --skip plugins
pause

checkpoint "Verify settings.json merged (not clobbered)" \
  "Expect: existing env.EXISTING_USER_VALUE='should_survive' still there;
            permissions.allow grown to include Bash(git status:*), Bash(cargo build:*), etc;
            original Read/Write/Edit still in allow."
run cat "$HOME_SB/.claude/settings.json"
pause

checkpoint "Verify CLAUDE.md managed section" \
  "Expect: content above/below markers untouched.
            Block between <!-- pds:start --> and <!-- pds:end --> replaced with
            PDS-managed summary (shepherd tiers, health thresholds, modality)."
run cat "$HOME_SB/CLAUDE.md"
pause

checkpoint "Verify global gitignore managed block" \
  "Expect: # >>> pds managed >>> / # <<< pds managed <<< block with THREE paths: .claude/swarm/, .claude/plans/, journal/. (diary/telemetry/shepherd-journal were collapsed into one 'journal/' entry.)"
run cat "$HOME_SB/.config/git/ignore"
pause

checkpoint "Verify TOFU fingerprint was recorded" \
  "Expect: sha256 hex string written to cache."
run cat "$HOME_SB/.cache/pds/sync-fingerprint.sha256"
pause

checkpoint "Re-run sync — should be a no-op" \
  "Expect: 'pds sync: already in sync'. No diffs, no prompts."
run "$PDS_BIN" sync --yes --skip plugins
pause

checkpoint "Value-only change — should stay silent (fingerprint unchanged)" \
  "We'll bump health.serious_min from 45 → 60. Shape (keys/presets/plugins) is
   unchanged, so the fingerprint shouldn't trigger re-confirm. Diff should show
   no file changes because health threshold isn't written to any sink yet
   (hooks read it dynamically via pds config get)."
sed -i.bak 's/serious_min: 45/serious_min: 60/' "$HOME_SB/.config/pds/config.yaml"
rm "$HOME_SB/.config/pds/config.yaml.bak"
run "$PDS_BIN" sync --yes --skip plugins
pause

checkpoint "Shape change — should trigger re-confirm when interactive" \
  "We'll remove the dev-tools preset (shape change). Without --yes this would
   prompt for confirmation. We pass --yes here so the test isn't interactive,
   but the fingerprint will update and settings.json will shrink (losing
   dev-tools preset allowances)."
sed -i.bak "s/presets: \[pds-default, dev-tools\]/presets: [pds-default]/" "$HOME_SB/.config/pds/config.yaml"
rm "$HOME_SB/.config/pds/config.yaml.bak"
run "$PDS_BIN" sync --yes --skip plugins
pause

checkpoint "Final settings.json after shrink" \
  "Expect: cargo/npm/pytest allow entries gone; git status/log/diff + rm -rf / deny still present."
run cat "$HOME_SB/.claude/settings.json"
pause

checkpoint "Doctor with real config" \
  "All 5 checks green; presets resolve now shows '1 preset(s)'."
run "$PDS_BIN" doctor
pause

# --- Done -----------------------------------------------------------------

echo
echo "${c_bold}${c_green}All checkpoints complete.${c_reset}"
echo "Sandbox preserved at: $SANDBOX"
echo "  Poke around freely; when done: rm -rf $SANDBOX"
