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
CLEANUP=0
USER_LEVEL=0
ALL_LEVEL=0
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
  --cleanup     Remove PDS artifacts (strips CLAUDE.md markers, hooks, v3.x files)
  --user        With --cleanup: remove user-level PDS (plugin, settings, hooks)
  --all         With --cleanup: remove both project and user-level PDS
  --test        Run smoke tests in a temp directory (no network)
  --help        Show this help message

Modes:
  Plugin (default):   Downloads PDS as a plugin to ~/.claude/plugins/pds/
                      Installs security settings to ~/.claude/settings.json
  Project (--project): Installs project-level settings.json and CLAUDE.md only

Cleanup:
  --cleanup           Remove PDS from the current project
  --cleanup --user    Remove PDS from user level (~/.claude/)
  --cleanup --all     Remove PDS from both project and user level

Examples:
  # Plugin install (default — recommended)
  curl -sfL https://raw.githubusercontent.com/rmzi/portable-dev-system/main/install.sh | bash

  # Project-level settings for team overrides
  curl -sfL https://raw.githubusercontent.com/rmzi/portable-dev-system/main/install.sh | bash -s -- --project

  # Dev mode — symlink local checkout
  ./install.sh --plugin-dir .

  # Remove PDS from project
  curl -sfL ... | bash -s -- --cleanup

  # Remove PDS from user level
  curl -sfL ... | bash -s -- --cleanup --user

  # Remove PDS from both project and user level
  curl -sfL ... | bash -s -- --cleanup --all
EOF
  exit 0
}

# --- CLAUDE.md handling ---

PDS_START_MARKER="<!-- PDS:START -->"
PDS_END_MARKER="<!-- PDS:END -->"

# Extract content before/after PDS markers using explicit line numbers.
# Avoids BSD sed range bug where 1,/pattern/ extends to EOF if line 1 matches.
_pds_before() {
  _file="$1"
  _start=$(grep -n "$PDS_START_MARKER" "$_file" | head -1 | cut -d: -f1)
  if [ -n "$_start" ] && [ "$_start" -gt 1 ] 2>/dev/null; then
    sed -n "1,$((_start - 1))p" "$_file"
  fi
}

_pds_after() {
  _file="$1"
  _end=$(grep -n "$PDS_END_MARKER" "$_file" | head -1 | cut -d: -f1)
  _total=$(wc -l < "$_file" | tr -d ' ')
  if [ -n "$_end" ] && [ "$_end" -lt "$_total" ] 2>/dev/null; then
    sed -n "$((_end + 1)),\$p" "$_file"
  fi
}

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
    before=$(_pds_before "$dest_file")
    after=$(_pds_after "$dest_file")

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

# --- Cleanup helpers ---

cleanup_claude_md() {
  target_file="$1"

  if [ ! -f "$target_file" ]; then
    return
  fi

  if ! grep -q "$PDS_START_MARKER" "$target_file" 2>/dev/null; then
    warn "No PDS markers found in $target_file — skipping"
    return
  fi

  before=$(_pds_before "$target_file")
  after=$(_pds_after "$target_file")

  # Check if before or after have any non-whitespace content
  has_content=0
  if printf '%s' "$before" | grep -q '[^[:space:]]' 2>/dev/null; then
    has_content=1
  fi
  if printf '%s' "$after" | grep -q '[^[:space:]]' 2>/dev/null; then
    has_content=1
  fi

  if [ "$has_content" -eq 0 ]; then
    # File was entirely PDS content
    if [ -f "${target_file}.pre-pds" ]; then
      mv "${target_file}.pre-pds" "$target_file"
      ok "Restored $target_file from pre-PDS backup"
    else
      rm "$target_file"
      ok "Removed $target_file (was entirely PDS-managed)"
    fi
  else
    # Write back only non-PDS content
    {
      [ -n "$before" ] && printf '%s\n' "$before"
      [ -n "$after" ] && printf '%s\n' "$after"
    } > "$target_file"
    ok "Stripped PDS block from $target_file"
  fi
}

cleanup_hooks() {
  settings_file="$1"

  if [ ! -f "$settings_file" ]; then
    return
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    warn "python3 not found — cannot clean PDS settings from $settings_file"
    warn "Manually remove PDS hooks, spinnerTipsOverride, and attribution from $settings_file"
    return
  fi

  python3 -c "
import json, sys
path = sys.argv[1]
with open(path) as f:
    data = json.load(f)
changed = False
# Remove PDS hook events
for event in ['SessionStart', 'PostToolUse', 'PermissionRequest', 'Stop', 'TaskCompleted', 'TeammateIdle']:
    if event in data.get('hooks', {}):
        data['hooks'].pop(event)
        changed = True
if not data.get('hooks'):
    data.pop('hooks', None)
    changed = True
# Remove PDS UX keys
for key in ['spinnerTipsOverride', 'attribution']:
    if key in data:
        data.pop(key)
        changed = True
if not changed:
    sys.exit(0)
with open(path, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
" "$settings_file" && ok "Removed PDS settings from $settings_file"
}

# --- Install security settings ---

install_security_settings() {
  target_settings="$1"
  pds_settings="$SRC_DIR/.claude/settings.json"

  if [ ! -f "$pds_settings" ]; then
    warn "PDS settings.json not found — skipping"
    return
  fi

  if [ ! -f "$target_settings" ]; then
    cp "$pds_settings" "$target_settings"
    ok "Installed security settings → $target_settings"
    return
  fi

  # Merge PDS security keys into existing settings, preserving user config
  if ! command -v python3 >/dev/null 2>&1; then
    warn "python3 not found — copying PDS settings (backup at ${target_settings}.pre-pds)"
    if [ ! -f "${target_settings}.pre-pds" ]; then
      cp "$target_settings" "${target_settings}.pre-pds"
    fi
    cp "$pds_settings" "$target_settings"
    ok "Installed security settings → $target_settings"
    return
  fi

  python3 -c "
import json, sys

pds_path, target_path = sys.argv[1], sys.argv[2]
with open(pds_path) as f:
    pds = json.load(f)
with open(target_path) as f:
    user = json.load(f)

# Merge env: PDS defaults, user overrides
if 'env' in pds or 'env' in user:
    merged_env = {**pds.get('env', {}), **user.get('env', {})}
    user['env'] = merged_env

# PDS-managed keys overwrite (security guardrails + UX)
for key in ['sandbox', 'permissions', 'spinnerTipsOverride', 'attribution']:
    if key in pds:
        user[key] = pds[key]

with open(target_path, 'w') as f:
    json.dump(user, f, indent=2)
    f.write('\n')
" "$pds_settings" "$target_settings"
  ok "Merged PDS security settings into $target_settings"
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

# --- Cleanup modes ---

cleanup_project() {
  info "Cleaning up project-level PDS artifacts..."
  removed=0

  # Remove v3.x project directories
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

  # Remove hooks from project settings.json
  if [ -f ".claude/settings.json" ] && grep -q '"hooks"' ".claude/settings.json" 2>/dev/null; then
    cleanup_hooks ".claude/settings.json"
    removed=$((removed + 1))
  fi

  if [ -f ".claude/.pds-version" ]; then
    rm -f ".claude/.pds-version"
    ok "Removed .claude/.pds-version (plugin tracks its own version)"
    removed=$((removed + 1))
  fi

  # Strip PDS block from CLAUDE.md (Issue #45)
  if [ -f "CLAUDE.md" ] && grep -q "$PDS_START_MARKER" "CLAUDE.md" 2>/dev/null; then
    cleanup_claude_md "CLAUDE.md"
    removed=$((removed + 1))
  fi

  # Remove PDS hooks from user-level settings (Issue #46)
  if [ -f "$HOME/.claude/settings.json" ] && grep -q '"hooks"' "$HOME/.claude/settings.json" 2>/dev/null; then
    warn "Also removing PDS hooks from user-level ~/.claude/settings.json"
    cleanup_hooks "$HOME/.claude/settings.json"
    removed=$((removed + 1))
  fi

  # Check if .claude/ is now empty (only settings.json and instincts.md may remain)
  if [ -d ".claude" ]; then
    remaining=$(ls -A .claude/ 2>/dev/null | grep -v 'settings.json' | grep -v 'instincts.md' | grep -v 'agent-memory' | wc -l | tr -d ' ')
    if [ "$remaining" -eq 0 ] && [ ! -f ".claude/settings.json" ] && [ ! -f ".claude/instincts.md" ]; then
      rm -rf .claude
      ok "Removed empty .claude/ directory"
    fi
  fi

  echo ""
  if [ "$removed" -gt 0 ]; then
    ok "Cleaned up $removed old PDS artifacts"
    echo "    Remaining project files (if any):"
    echo "      .claude/settings.json — team-specific deny rules (keep if customized)"
    echo "      .claude/instincts.md — project-learned patterns (keep)"
  else
    ok "Nothing to clean up — project is already clean"
  fi
}

cleanup_user() {
  info "Cleaning up user-level PDS artifacts..."

  # Remove plugin directory
  if [ -d "$HOME/.claude/plugins/pds" ] || [ -L "$HOME/.claude/plugins/pds" ]; then
    rm -rf "$HOME/.claude/plugins/pds"
    ok "Removed plugin: ~/.claude/plugins/pds/"
  fi

  # Remove PDS hooks from user settings (Issue #46)
  cleanup_hooks "$HOME/.claude/settings.json"

  # Restore user settings from backup if available
  if [ -f "$HOME/.claude/settings.json.pre-pds" ]; then
    mv "$HOME/.claude/settings.json.pre-pds" "$HOME/.claude/settings.json"
    ok "Restored ~/.claude/settings.json from pre-PDS backup"
  fi

  # Strip PDS block from user CLAUDE.md (Issue #45)
  cleanup_claude_md "$HOME/.claude/CLAUDE.md"

  echo ""
  ok "PDS user artifacts cleaned up"
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
  assert_no_file()  { assert "$1 does not exist" test ! -f "$2"; }
  assert_not_contains() {
    desc="$1"; pattern="$2"; file="$3"
    if grep -q "$pattern" "$file" 2>/dev/null; then
      err "FAIL: $desc does not contain '$pattern'"
      FAIL=$((FAIL + 1))
    else
      ok "PASS: $desc does not contain '$pattern'"
      PASS=$((PASS + 1))
    fi
  }

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
  assert_file "settings.json"      "$SRC_DIR/settings.json"

  # Count agents (at least 1)
  agent_count=$(ls "$SRC_DIR/agents/"*.md 2>/dev/null | wc -l | tr -d ' ')
  assert "agents count > 0 (got $agent_count)" test "$agent_count" -gt 0

  # Count skills (at least 1)
  skill_count=$(ls -d "$SRC_DIR/skills/"*/SKILL.md 2>/dev/null | wc -l | tr -d ' ')
  assert "skills count > 0 (got $skill_count)" test "$skill_count" -gt 0

  # Validate JSON
  assert "plugin.json is valid JSON" python3 -c "import json; json.load(open('$SRC_DIR/.claude-plugin/plugin.json'))"
  assert "hooks.json is valid JSON" python3 -c "import json; json.load(open('$SRC_DIR/hooks/hooks.json'))"
  assert "plugin settings.json valid" python3 -c "import json; d=json.load(open('$SRC_DIR/settings.json')); assert d.get('agent') == 'orchestrator', 'missing agent key'"
  assert "settings.json is valid JSON" python3 -c "import json; json.load(open('$SRC_DIR/.claude/settings.json'))"
  assert "settings has spinnerTips"    python3 -c "import json; d=json.load(open('$SRC_DIR/.claude/settings.json')); assert 'spinnerTipsOverride' in d"
  assert "settings has attribution"    python3 -c "import json; d=json.load(open('$SRC_DIR/.claude/settings.json')); assert 'attribution' in d"

  echo ""

  # --- Test 2: Skill namespace ---
  info "Test: skill namespace (pds: prefix in agents)"
  for agent_file in "$SRC_DIR/agents/"*.md; do
    agent_name=$(basename "$agent_file" .md)
    if grep -q 'skills:' "$agent_file"; then
      # Check that all skill references use pds: prefix (stop at next YAML key)
      if sed -n '/^skills:/,/^[a-z]/p' "$agent_file" | grep -E '^\s+- [a-z]' | grep -v 'pds:' >/dev/null 2>&1; then
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
  assert_contains "hooks.json" "Stop" "$SRC_DIR/hooks/hooks.json"
  assert_contains "hooks.json" "TaskCompleted" "$SRC_DIR/hooks/hooks.json"
  assert_contains "hooks.json" "TeammateIdle" "$SRC_DIR/hooks/hooks.json"
  # Hook scripts exist and are executable
  assert_file "task-completed-gate.sh" "$SRC_DIR/hooks/scripts/task-completed-gate.sh"
  assert_file "teammate-idle-gate.sh" "$SRC_DIR/hooks/scripts/teammate-idle-gate.sh"
  assert "task-completed-gate.sh is executable" test -x "$SRC_DIR/hooks/scripts/task-completed-gate.sh"
  assert "teammate-idle-gate.sh is executable" test -x "$SRC_DIR/hooks/scripts/teammate-idle-gate.sh"
  assert_file "session-start.sh" "$SRC_DIR/hooks/scripts/session-start.sh"
  assert "session-start.sh is executable" test -x "$SRC_DIR/hooks/scripts/session-start.sh"
  assert "session-start.sh outputs JSON" bash -c "'$SRC_DIR/hooks/scripts/session-start.sh' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"additionalContext\" in d.get(\"hookSpecificOutput\", {})'"
  assert_file "post-write-check.sh" "$SRC_DIR/hooks/scripts/post-write-check.sh"
  assert "post-write-check.sh is executable" test -x "$SRC_DIR/hooks/scripts/post-write-check.sh"
  assert_file "validator-stop-gate.sh" "$SRC_DIR/hooks/scripts/validator-stop-gate.sh"
  assert "validator-stop-gate.sh is executable" test -x "$SRC_DIR/hooks/scripts/validator-stop-gate.sh"
  # Agent frontmatter hooks
  assert_contains "worker hooks" "PostToolUse" "$SRC_DIR/agents/worker.md"
  assert_contains "validator hooks" "Stop" "$SRC_DIR/agents/validator.md"
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

  # Self-contained source CLAUDE.md with markers
  cat > "$testdir/src-claude.md" <<'SRCEOF'
<!-- PDS:START -->
# Portable Development System
## Skills System (MANDATORY)
New PDS content
<!-- PDS:END -->
SRCEOF

  cat > "$testdir/marker-test.md" <<'MARKEREOF'
# My custom header

<!-- PDS:START -->
old PDS content here
<!-- PDS:END -->

# My custom footer
MARKEREOF
  install_claude_md "$testdir/src-claude.md" "$testdir/marker-test.md"
  assert_contains "marker-test.md" "PDS:START"        "$testdir/marker-test.md"
  assert_contains "marker-test.md" "Skills System"    "$testdir/marker-test.md"
  assert_contains "marker-test.md" "My custom header" "$testdir/marker-test.md"
  assert_contains "marker-test.md" "My custom footer" "$testdir/marker-test.md"

  echo ""

  # --- Test 6: Cleanup strips PDS block from CLAUDE.md (#45) ---
  info "Test: cleanup strips PDS block from CLAUDE.md"

  # 6a: File entirely PDS-managed → gets removed
  cat > "$testdir/pds-only.md" <<'EOF'
<!-- PDS:START -->
PDS content only
<!-- PDS:END -->
EOF
  cleanup_claude_md "$testdir/pds-only.md"
  assert_no_file "pds-only.md removed" "$testdir/pds-only.md"

  # 6b: File with pre-PDS backup → restore original
  echo "Original content before PDS" > "$testdir/has-backup.md.pre-pds"
  cat > "$testdir/has-backup.md" <<'EOF'
<!-- PDS:START -->
PDS replaced this
<!-- PDS:END -->
EOF
  cleanup_claude_md "$testdir/has-backup.md"
  assert_file     "backup restored"         "$testdir/has-backup.md"
  assert_contains "has-backup.md" "Original" "$testdir/has-backup.md"
  assert_no_file  "pre-pds backup removed"  "$testdir/has-backup.md.pre-pds"

  # 6c: File with custom content + PDS block → PDS stripped, custom preserved
  cat > "$testdir/mixed.md" <<'EOF'
# My Project

Custom rules here.

<!-- PDS:START -->
PDS content to remove
<!-- PDS:END -->

# More custom content
EOF
  cleanup_claude_md "$testdir/mixed.md"
  assert_file         "mixed.md still exists"  "$testdir/mixed.md"
  assert_not_contains "mixed.md" "PDS:START"   "$testdir/mixed.md"
  assert_not_contains "mixed.md" "PDS:END"     "$testdir/mixed.md"
  assert_contains     "mixed.md" "My Project"  "$testdir/mixed.md"
  assert_contains     "mixed.md" "More custom" "$testdir/mixed.md"

  # 6d: File without PDS markers → left untouched
  echo "No PDS here" > "$testdir/no-markers.md"
  cleanup_claude_md "$testdir/no-markers.md"
  assert_file     "no-markers.md untouched"    "$testdir/no-markers.md"
  assert_contains "no-markers.md" "No PDS"     "$testdir/no-markers.md"

  echo ""

  # --- Test 7: Cleanup removes hooks from settings.json (#46) ---
  info "Test: cleanup removes PDS hooks from settings.json"

  # 7a: Settings with PDS hooks + UX keys → all PDS keys removed, rest preserved
  cat > "$testdir/hooks-test.json" <<'EOF'
{
  "permissions": {
    "allow": ["Read"]
  },
  "hooks": {
    "SessionStart": [{"hooks": [{"type": "command", "command": "echo version check"}]}],
    "PostToolUse": [{"hooks": [{"type": "command", "command": "echo test reminder"}]}],
    "PermissionRequest": [{"hooks": [{"type": "prompt", "prompt": "evaluate permissions"}]}],
    "Stop": [{"hooks": [{"type": "prompt", "prompt": "check completion"}]}],
    "TaskCompleted": [{"hooks": [{"type": "command", "command": "echo gate"}]}],
    "TeammateIdle": [{"hooks": [{"type": "command", "command": "echo gate"}]}]
  },
  "spinnerTipsOverride": {"tips": ["test tip"]},
  "attribution": {"pr": "test"}
}
EOF
  cleanup_hooks "$testdir/hooks-test.json"
  assert "hooks removed"       python3 -c "import json; d=json.load(open('$testdir/hooks-test.json')); assert 'hooks' not in d"
  assert "spinnerTips removed" python3 -c "import json; d=json.load(open('$testdir/hooks-test.json')); assert 'spinnerTipsOverride' not in d"
  assert "attribution removed" python3 -c "import json; d=json.load(open('$testdir/hooks-test.json')); assert 'attribution' not in d"
  assert "permissions kept"    python3 -c "import json; d=json.load(open('$testdir/hooks-test.json')); assert 'permissions' in d"
  assert "valid JSON after"    python3 -c "import json; json.load(open('$testdir/hooks-test.json'))"

  # 7b: Settings with mixed hooks → only PDS hooks removed
  cat > "$testdir/mixed-hooks.json" <<'EOF'
{
  "permissions": {"allow": ["Read"]},
  "hooks": {
    "SessionStart": [{"hooks": [{"type": "command", "command": "echo pds"}]}],
    "Stop": [{"hooks": [{"type": "prompt", "prompt": "check"}]}],
    "PreToolUse": [{"hooks": [{"type": "command", "command": "echo custom"}]}]
  }
}
EOF
  cleanup_hooks "$testdir/mixed-hooks.json"
  assert "PDS hook removed"    python3 -c "import json; d=json.load(open('$testdir/mixed-hooks.json')); assert 'SessionStart' not in d.get('hooks', {})"
  assert "Stop hook removed"   python3 -c "import json; d=json.load(open('$testdir/mixed-hooks.json')); assert 'Stop' not in d.get('hooks', {})"
  assert "custom hook kept"    python3 -c "import json; d=json.load(open('$testdir/mixed-hooks.json')); assert 'PreToolUse' in d['hooks']"
  assert "hooks key kept"      python3 -c "import json; d=json.load(open('$testdir/mixed-hooks.json')); assert 'hooks' in d"

  # 7c: Settings without hooks → no-op
  cat > "$testdir/no-hooks.json" <<'EOF'
{
  "permissions": {"allow": ["Read"]}
}
EOF
  cleanup_hooks "$testdir/no-hooks.json"
  assert "no-hooks unchanged"  python3 -c "import json; d=json.load(open('$testdir/no-hooks.json')); assert 'permissions' in d and 'hooks' not in d"

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
    --cleanup)    CLEANUP=1; shift ;;
    --user)       USER_LEVEL=1; shift ;;
    --all)        ALL_LEVEL=1; shift ;;
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

# --- Cleanup mode (no download needed) ---
if [ "$CLEANUP" -eq 1 ]; then
  if [ "$ALL_LEVEL" -eq 1 ]; then
    cleanup_project
    echo ""
    cleanup_user
  elif [ "$USER_LEVEL" -eq 1 ]; then
    cleanup_user
  else
    cleanup_project
  fi
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
