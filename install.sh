#!/bin/sh
# PDS Install Script — Plugin-based architecture
# https://github.com/rmzi/portable-dev-system
#
# Default (plugin install):
#   curl -sfL https://raw.githubusercontent.com/rmzi/portable-dev-system/main/install.sh | bash
#
# Project-level settings only (team overrides):
#   curl -sfL https://raw.githubusercontent.com/rmzi/portable-dev-system/main/install.sh | bash -s -- --project
#
# Dev mode (link local checkout as plugin):
#   ./install.sh --plugin-dir /path/to/pds
#
# Force reinstall:
#   curl -sfL ... | bash -s -- --force

set -e

REPO_URL="https://github.com/rmzi/portable-dev-system"
TARBALL_URL="${REPO_URL}/archive/refs/heads/main.tar.gz"
REMOTE_VERSION_URL="https://raw.githubusercontent.com/rmzi/portable-dev-system/main/VERSION"

# --- Defaults ---
MODE="plugin"
FORCE=0
PLUGIN_DIR=""

# --- Helpers ---
info()  { printf '  \033[1;34m>\033[0m %s\n' "$1"; }
ok()    { printf '  \033[1;32m✓\033[0m %s\n' "$1"; }
warn()  { printf '  \033[1;33m!\033[0m %s\n' "$1"; }
err()   { printf '  \033[1;31m✗\033[0m %s\n' "$1" >&2; }

# --- Usage ---
usage() {
  cat <<'EOF'
Usage: install.sh [OPTIONS]

Install PDS (Portable Development System) as a Claude Code plugin.

Options:
  --project     Install project-level settings only (team overrides)
  --plugin-dir  Link a local PDS checkout as the plugin (dev mode)
  --force       Reinstall even if already up to date
  --cleanup     Remove old v3.x project-level PDS files (skills, agents, hooks)
  --test        Run smoke tests in a temp directory (no network)
  --help        Show this help message

Modes:
  Plugin (default):   Downloads PDS as a plugin to ~/.claude/plugins/pds/
                      Installs security settings to ~/.claude/settings.json
  Project (--project): Installs project-level settings.json and CLAUDE.md only

Examples:
  # Plugin install (default — recommended)
  curl -sfL https://raw.githubusercontent.com/rmzi/portable-dev-system/main/install.sh | bash

  # Project-level settings for team overrides
  curl -sfL https://raw.githubusercontent.com/rmzi/portable-dev-system/main/install.sh | bash -s -- --project

  # Dev mode — symlink local checkout
  ./install.sh --plugin-dir .
EOF
  exit 0
}

# --- CLAUDE.md handling ---

PDS_START_MARKER="<!-- PDS:START -->"
PDS_END_MARKER="<!-- PDS:END -->"

install_claude_md() {
  src_file="$1"
  dest_file="$2"

  if [ ! -f "$src_file" ]; then
    warn "Source CLAUDE.md not found — skipping"
    return
  fi

  src_content=$(cat "$src_file")

  if [ ! -f "$dest_file" ]; then
    printf '%s\n' "$src_content" > "$dest_file"
    ok "Created $dest_file"
    return
  fi

  if grep -q "$PDS_START_MARKER" "$dest_file" 2>/dev/null; then
    before=$(sed -n "1,/$PDS_START_MARKER/{ /$PDS_START_MARKER/d; p; }" "$dest_file")
    after=$(sed -n "/$PDS_END_MARKER/,\${ /$PDS_END_MARKER/d; p; }" "$dest_file")

    {
      [ -n "$before" ] && printf '%s\n' "$before"
      printf '%s\n' "$src_content"
      [ -n "$after" ] && printf '%s\n' "$after"
    } > "$dest_file"
    ok "Updated PDS block in $dest_file"
  else
    if [ ! -f "${dest_file}.pre-pds" ]; then
      cp "$dest_file" "${dest_file}.pre-pds"
      warn "Backed up existing $dest_file → ${dest_file}.pre-pds"
    fi
    printf '%s\n' "$src_content" > "$dest_file"
    ok "Installed $dest_file (original backed up)"
  fi
}

# --- Install security settings ---

install_security_settings() {
  target_settings="$1"

  if [ -f "$target_settings" ] && [ ! -f "${target_settings}.pre-pds" ]; then
    cp "$target_settings" "${target_settings}.pre-pds"
    warn "Backed up existing settings → ${target_settings}.pre-pds"
  fi
  cp "$SRC_DIR/.claude/settings.json" "$target_settings"
  ok "Installed security settings → $target_settings"
}

# --- Install modes ---

install_plugin() {
  PLUGIN_TARGET="$HOME/.claude/plugins/pds"
  SETTINGS_TARGET="$HOME/.claude/settings.json"

  mkdir -p "$PLUGIN_TARGET"

  # Copy plugin structure
  if [ -d "$SRC_DIR/.claude-plugin" ]; then
    cp -R "$SRC_DIR/.claude-plugin" "$PLUGIN_TARGET/.claude-plugin"
    ok "Installed plugin manifest"
  fi

  if [ -d "$SRC_DIR/agents" ]; then
    rm -rf "$PLUGIN_TARGET/agents"
    cp -R "$SRC_DIR/agents" "$PLUGIN_TARGET/agents"
    ok "Installed agents → $PLUGIN_TARGET/agents/"
  fi

  if [ -d "$SRC_DIR/skills" ]; then
    rm -rf "$PLUGIN_TARGET/skills"
    cp -R "$SRC_DIR/skills" "$PLUGIN_TARGET/skills"
    ok "Installed skills → $PLUGIN_TARGET/skills/"
  fi

  if [ -d "$SRC_DIR/hooks" ]; then
    rm -rf "$PLUGIN_TARGET/hooks"
    cp -R "$SRC_DIR/hooks" "$PLUGIN_TARGET/hooks"
    ok "Installed hooks → $PLUGIN_TARGET/hooks/"
  fi

  # Security settings go to user-level settings.json (can't be in plugin)
  install_security_settings "$SETTINGS_TARGET"

  # Copy instincts seed file if not present
  if [ -f "$SRC_DIR/.claude/instincts.md" ] && [ ! -f "$HOME/.claude/instincts.md" ]; then
    cp "$SRC_DIR/.claude/instincts.md" "$HOME/.claude/instincts.md"
    ok "Installed instincts → ~/.claude/instincts.md"
  fi

  echo ""
  ok "PDS v4 plugin installed!"
  echo "    Plugin: ~/.claude/plugins/pds/"
  echo "    Settings: ~/.claude/settings.json"
  echo "    Skills: /pds:swarm, /pds:grill, /pds:verify, etc."
  echo "    Agents: orchestrator, worker, validator, etc."

  # Check for sandbox dependencies on Linux
  if [ "$(uname)" = "Linux" ]; then
    for dep in bwrap socat; do
      command -v "$dep" >/dev/null 2>&1 || warn "Sandbox dependency missing: $dep. Install with: sudo apt install bubblewrap socat"
    done
  fi
}

install_plugin_dir() {
  PLUGIN_TARGET="$HOME/.claude/plugins/pds"

  # Remove existing plugin dir if it exists
  if [ -d "$PLUGIN_TARGET" ] || [ -L "$PLUGIN_TARGET" ]; then
    rm -rf "$PLUGIN_TARGET"
  fi

  mkdir -p "$(dirname "$PLUGIN_TARGET")"
  ln -s "$(cd "$PLUGIN_DIR" && pwd)" "$PLUGIN_TARGET"
  ok "Linked plugin: $PLUGIN_TARGET → $(cd "$PLUGIN_DIR" && pwd)"

  # Security settings
  SRC_DIR="$PLUGIN_DIR"
  install_security_settings "$HOME/.claude/settings.json"

  echo ""
  ok "PDS dev plugin linked!"
  echo "    Plugin: $PLUGIN_TARGET → $(cd "$PLUGIN_DIR" && pwd)"
  echo "    Changes to the source dir are immediately active."
}

install_project() {
  TARGET_DIR=".claude"
  mkdir -p "$TARGET_DIR"

  # Install project-level settings (team can override deny rules, domains, etc.)
  install_security_settings "$TARGET_DIR/settings.json"

  # Handle CLAUDE.md with PDS markers
  install_claude_md "$SRC_DIR/CLAUDE.md" "CLAUDE.md"

  # Add .worktrees/ to .gitignore if not present
  if [ -f .gitignore ]; then
    if ! grep -q '^\.worktrees/' .gitignore 2>/dev/null; then
      printf '\n.worktrees/\n' >> .gitignore
      ok "Added .worktrees/ to .gitignore"
    fi
  else
    printf '.worktrees/\n' > .gitignore
    ok "Created .gitignore with .worktrees/"
  fi

  echo ""
  ok "PDS project settings installed!"
  echo "    Settings: .claude/settings.json (team overrides)"
  echo "    CLAUDE.md updated with PDS block"
  echo "    The PDS plugin provides skills and agents — install it with:"
  echo "    curl -sfL https://raw.githubusercontent.com/rmzi/portable-dev-system/main/install.sh | bash"
}

# --- Cleanup old v3.x project files ---

cleanup_project() {
  removed=0

  if [ -d ".claude/skills" ]; then
    rm -rf ".claude/skills"
    ok "Removed .claude/skills/ (now in plugin)"
    removed=$((removed + 1))
  fi

  if [ -d ".claude/agents" ]; then
    rm -rf ".claude/agents"
    ok "Removed .claude/agents/ (now in plugin)"
    removed=$((removed + 1))
  fi

  if [ -f ".claude/settings.json" ] && grep -q '"hooks"' ".claude/settings.json" 2>/dev/null; then
    # Remove hooks key from settings.json (now in plugin hooks/hooks.json)
    if command -v python3 >/dev/null 2>&1; then
      python3 -c "
import json, sys
with open('.claude/settings.json') as f: d = json.load(f)
d.pop('hooks', None)
with open('.claude/settings.json', 'w') as f: json.dump(d, f, indent=2); f.write('\n')
"
      ok "Removed hooks from .claude/settings.json (now in plugin)"
      removed=$((removed + 1))
    else
      warn "Found hooks in .claude/settings.json — remove manually (python3 not available)"
    fi
  fi

  if [ -f ".claude/.pds-version" ]; then
    rm -f ".claude/.pds-version"
    ok "Removed .claude/.pds-version (plugin tracks its own version)"
    removed=$((removed + 1))
  fi

  # Check if .claude/ is now empty (only settings.json and instincts.md may remain)
  remaining=$(ls -A .claude/ 2>/dev/null | grep -v 'settings.json' | grep -v 'instincts.md' | grep -v 'agent-memory' | wc -l | tr -d ' ')
  if [ "$remaining" -eq 0 ] && [ ! -f ".claude/settings.json" ] && [ ! -f ".claude/instincts.md" ]; then
    rm -rf .claude
    ok "Removed empty .claude/ directory"
  fi

  echo ""
  if [ "$removed" -gt 0 ]; then
    ok "Cleaned up $removed old PDS artifacts"
    echo "    Remaining project files (if any):"
    echo "      .claude/settings.json — team-specific deny rules (keep if customized)"
    echo "      .claude/instincts.md — project-learned patterns (keep)"
    echo "      CLAUDE.md — project rules (keep)"
  else
    ok "Nothing to clean up — project is already clean"
  fi
}

# --- Self-test ---

run_tests() {
  PASS=0
  FAIL=0
  SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

  assert() {
    desc="$1"; shift
    if "$@" >/dev/null 2>&1; then
      ok "PASS: $desc"
      PASS=$((PASS + 1))
    else
      err "FAIL: $desc"
      FAIL=$((FAIL + 1))
    fi
  }

  assert_file()    { assert "$1 exists" test -f "$2"; }
  assert_dir()     { assert "$1 exists" test -d "$2"; }
  assert_contains() { assert "$1 contains '$2'" grep -q "$2" "$3"; }
  assert_not_dir() { assert "$1 does not exist" test ! -d "$2"; }

  info "Running PDS v4 plugin install smoke tests (offline, temp dirs)"
  echo ""

  # --- Test 1: Plugin structure ---
  info "Test: plugin structure"
  SRC_DIR="$SCRIPT_DIR"

  assert_dir  ".claude-plugin"     "$SRC_DIR/.claude-plugin"
  assert_file "plugin.json"        "$SRC_DIR/.claude-plugin/plugin.json"
  assert_dir  "agents"             "$SRC_DIR/agents"
  assert_dir  "skills"             "$SRC_DIR/skills"
  assert_dir  "hooks"              "$SRC_DIR/hooks"

  # Count agents (should be 8)
  agent_count=$(ls "$SRC_DIR/agents/"*.md 2>/dev/null | wc -l | tr -d ' ')
  assert "agents count = 8 (got $agent_count)" test "$agent_count" -eq 8

  # Count skills (should be 16 directories)
  skill_count=$(ls -d "$SRC_DIR/skills/"*/SKILL.md 2>/dev/null | wc -l | tr -d ' ')
  assert "skills count = 16 (got $skill_count)" test "$skill_count" -eq 16

  # Validate JSON
  assert "plugin.json is valid JSON" python3 -c "import json; json.load(open('$SRC_DIR/.claude-plugin/plugin.json'))"
  assert "hooks.json is valid JSON" python3 -c "import json; json.load(open('$SRC_DIR/hooks/hooks.json'))"
  assert "settings.json is valid JSON" python3 -c "import json; json.load(open('$SRC_DIR/.claude/settings.json'))"

  echo ""

  # --- Test 2: Skill namespace ---
  info "Test: skill namespace (pds: prefix in agents)"
  for agent_file in "$SRC_DIR/agents/"*.md; do
    agent_name=$(basename "$agent_file" .md)
    if grep -q 'skills:' "$agent_file"; then
      # Check that all skill references use pds: prefix
      if grep -A 10 'skills:' "$agent_file" | grep -E '^\s+- [a-z]' | grep -v 'pds:' >/dev/null 2>&1; then
        err "FAIL: $agent_name has non-prefixed skills"
        FAIL=$((FAIL + 1))
      else
        ok "PASS: $agent_name skills use pds: prefix"
        PASS=$((PASS + 1))
      fi
    fi
  done

  echo ""

  # --- Test 3: No demoted skills ---
  info "Test: demoted skills removed"
  for removed in test commit debug design quickref review merge-main; do
    assert_not_dir "no $removed skill dir" "$SRC_DIR/skills/$removed"
  done

  echo ""

  # --- Test 4: Hooks extracted ---
  info "Test: hooks in plugin, not in settings"
  assert_contains "hooks.json" "SessionStart" "$SRC_DIR/hooks/hooks.json"
  assert_contains "hooks.json" "PermissionRequest" "$SRC_DIR/hooks/hooks.json"
  # settings.json should NOT have hooks
  if grep -q '"hooks"' "$SRC_DIR/.claude/settings.json" 2>/dev/null; then
    err "FAIL: settings.json still has hooks (should be in plugin)"
    FAIL=$((FAIL + 1))
  else
    ok "PASS: settings.json has no hooks"
    PASS=$((PASS + 1))
  fi

  echo ""

  # --- Test 5: PDS marker replacement ---
  info "Test: PDS marker replacement"
  testdir=$(mktemp -d)
  trap 'rm -rf "$testdir"' EXIT

  cat > "$testdir/marker-test.md" <<'MARKEREOF'
# My custom header

<!-- PDS:START -->
old PDS content here
<!-- PDS:END -->

# My custom footer
MARKEREOF
  install_claude_md "$SRC_DIR/CLAUDE.md" "$testdir/marker-test.md"
  assert_contains "marker-test.md" "PDS:START"       "$testdir/marker-test.md"
  assert_contains "marker-test.md" "My custom header" "$testdir/marker-test.md"
  assert_contains "marker-test.md" "My custom footer" "$testdir/marker-test.md"

  echo ""

  # --- Summary ---
  TOTAL=$((PASS + FAIL))
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  if [ "$FAIL" -eq 0 ]; then
    ok "All $TOTAL tests passed"
  else
    err "$FAIL/$TOTAL tests failed"
  fi
  return "$FAIL"
}

# ============================================================
# Main
# ============================================================

# --- Parse args ---
while [ $# -gt 0 ]; do
  case "$1" in
    --project)    MODE="project"; shift ;;
    --plugin-dir) MODE="plugin-dir"; PLUGIN_DIR="$2"; shift 2 ;;
    --cleanup)    MODE="cleanup"; shift ;;
    --force)      FORCE=1; shift ;;
    --test)       MODE="test"; shift ;;
    --help)       usage ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
done

# --- Self-test mode ---
if [ "$MODE" = "test" ]; then
  run_tests
  exit $?
fi

# --- Cleanup mode ---
if [ "$MODE" = "cleanup" ]; then
  cleanup_project
  exit 0
fi

# --- Dev plugin-dir mode ---
if [ "$MODE" = "plugin-dir" ]; then
  if [ -z "$PLUGIN_DIR" ]; then
    err "--plugin-dir requires a path argument"
    exit 1
  fi
  install_plugin_dir
  exit 0
fi

# --- Check dependencies ---
for cmd in curl tar mktemp; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    err "Required command not found: $cmd"
    exit 1
  fi
done

# --- Version check ---
LOCAL_VERSION=""
PLUGIN_JSON="$HOME/.claude/plugins/pds/.claude-plugin/plugin.json"
if [ -f "$PLUGIN_JSON" ] && command -v python3 >/dev/null 2>&1; then
  LOCAL_VERSION=$(python3 -c "import json; print(json.load(open('$PLUGIN_JSON')).get('version',''))" 2>/dev/null || echo "")
fi

REMOTE_VERSION=$(curl -sf --max-time 10 "$REMOTE_VERSION_URL" 2>/dev/null || echo "")
if [ -z "$REMOTE_VERSION" ]; then
  warn "Could not fetch remote version — installing anyway"
  REMOTE_VERSION="unknown"
fi

if [ "$FORCE" -eq 0 ] && [ -n "$LOCAL_VERSION" ] && [ "$LOCAL_VERSION" = "$REMOTE_VERSION" ]; then
  ok "PDS $LOCAL_VERSION is already up to date (use --force to reinstall)"
  exit 0
fi

if [ -n "$LOCAL_VERSION" ]; then
  info "Updating PDS: $LOCAL_VERSION → $REMOTE_VERSION"
else
  info "Installing PDS $REMOTE_VERSION"
fi

# --- Download and extract ---
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

info "Downloading PDS..."
if ! curl -sfL --max-time 30 "$TARBALL_URL" | tar xz -C "$tmpdir" 2>/dev/null; then
  err "Failed to download PDS from $TARBALL_URL"
  exit 1
fi

# GitHub tarballs extract to repo-branch/ directory
SRC_DIR="$tmpdir/portable-dev-system-main"
if [ ! -d "$SRC_DIR" ]; then
  err "Unexpected archive structure — expected $SRC_DIR"
  exit 1
fi

# --- Dispatch ---
if [ "$MODE" = "project" ]; then
  install_project
else
  install_plugin
fi
