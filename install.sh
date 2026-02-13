#!/bin/sh
# PDS Install Script — two-mode, zero-duplication
# https://github.com/rmzi/portable-dev-system
#
# Project install (default, for teams):
#   curl -sfL https://raw.githubusercontent.com/rmzi/portable-dev-system/main/install.sh | bash
#
# User install (personal, all projects):
#   curl -sfL https://raw.githubusercontent.com/rmzi/portable-dev-system/main/install.sh | bash -s -- --user
#
# Force reinstall:
#   curl -sfL ... | bash -s -- --force
#   curl -sfL ... | bash -s -- --user --force

set -e

REPO_URL="https://github.com/rmzi/portable-dev-system"
TARBALL_URL="${REPO_URL}/archive/refs/heads/main.tar.gz"
REMOTE_VERSION_URL="https://raw.githubusercontent.com/rmzi/portable-dev-system/main/VERSION"

# --- Defaults ---
MODE="project"
FORCE=0

# --- Helpers ---
info()  { printf '  \033[1;34m>\033[0m %s\n' "$1"; }
ok()    { printf '  \033[1;32m✓\033[0m %s\n' "$1"; }
warn()  { printf '  \033[1;33m!\033[0m %s\n' "$1"; }
err()   { printf '  \033[1;31m✗\033[0m %s\n' "$1" >&2; }

# --- Usage ---
usage() {
  cat <<'EOF'
Usage: install.sh [OPTIONS]

Install PDS (Portable Development System) into a project or at the user level.

Options:
  --user    Install to ~/.claude/ (personal, all projects)
  --force   Reinstall even if already up to date
  --help    Show this help message

Modes:
  Project (default):  Installs skills, agents, settings into .claude/ and CLAUDE.md
  User (--user):      Installs skills and settings into ~/.claude/ for all projects

Examples:
  # Project install (for teams)
  curl -sfL https://raw.githubusercontent.com/rmzi/portable-dev-system/main/install.sh | bash

  # User install (personal)
  curl -sfL https://raw.githubusercontent.com/rmzi/portable-dev-system/main/install.sh | bash -s -- --user

  # Force reinstall
  curl -sfL ... | bash -s -- --force
  curl -sfL ... | bash -s -- --user --force
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
    # Has markers — replace the PDS block
    before=$(sed -n "1,/$PDS_START_MARKER/{ /$PDS_START_MARKER/d; p; }" "$dest_file")
    after=$(sed -n "/$PDS_END_MARKER/,\${ /$PDS_END_MARKER/d; p; }" "$dest_file")

    {
      [ -n "$before" ] && printf '%s\n' "$before"
      printf '%s\n' "$src_content"
      [ -n "$after" ] && printf '%s\n' "$after"
    } > "$dest_file"
    ok "Updated PDS block in $dest_file"
  else
    # No markers — backup and install
    if [ ! -f "${dest_file}.pre-pds" ]; then
      cp "$dest_file" "${dest_file}.pre-pds"
      warn "Backed up existing $dest_file → ${dest_file}.pre-pds"
    fi
    printf '%s\n' "$src_content" > "$dest_file"
    ok "Installed $dest_file (original backed up)"
  fi
}

install_user_claude_md() {
  dest_file="$TARGET_DIR/CLAUDE.md"
  user_pds_block="$PDS_START_MARKER
# Portable Development System (User)

## Rules

- **Never clone repos** — use \`git worktree add\` for branch isolation
- **Never use /tmp for code** — worktrees go in \`.worktrees/\` inside the repo
- **Create a PR after pushing** — don't wait to be asked

## Skills

If this project has \`.claude/skills/\`, read and follow those skills before performing actions.
Otherwise, scan \`~/.claude/skills/\` for available workflow patterns.
$PDS_END_MARKER"

  if [ ! -f "$dest_file" ]; then
    printf '%s\n' "$user_pds_block" > "$dest_file"
    ok "Created $dest_file"
    return
  fi

  if grep -q "$PDS_START_MARKER" "$dest_file" 2>/dev/null; then
    before=$(sed -n "1,/$PDS_START_MARKER/{ /$PDS_START_MARKER/d; p; }" "$dest_file")
    after=$(sed -n "/$PDS_END_MARKER/,\${ /$PDS_END_MARKER/d; p; }" "$dest_file")

    {
      [ -n "$before" ] && printf '%s\n' "$before"
      printf '%s\n' "$user_pds_block"
      [ -n "$after" ] && printf '%s\n' "$after"
    } > "$dest_file"
    ok "Updated PDS block in $dest_file"
  else
    # No markers — prepend PDS block, keep existing content
    existing=$(cat "$dest_file")
    {
      printf '%s\n\n' "$user_pds_block"
      printf '%s\n' "$existing"
    } > "$dest_file"
    ok "Added PDS block to $dest_file (existing content preserved)"
  fi
}

# --- Install modes ---

install_project() {
  mkdir -p "$TARGET_DIR/skills" "$TARGET_DIR/agents"

  # Copy skills
  if [ -d "$SRC_DIR/.claude/skills" ]; then
    cp "$SRC_DIR/.claude/skills/"*.md "$TARGET_DIR/skills/" 2>/dev/null || true
    ok "Installed skills → $TARGET_DIR/skills/"
  fi

  # Copy agents
  if [ -d "$SRC_DIR/.claude/agents" ]; then
    cp "$SRC_DIR/.claude/agents/"*.md "$TARGET_DIR/agents/" 2>/dev/null || true
    ok "Installed agents → $TARGET_DIR/agents/"
  fi

  # Copy settings.json
  if [ -f "$SRC_DIR/.claude/settings.json" ]; then
    if [ -f "$TARGET_DIR/settings.json" ] && [ ! -f "$TARGET_DIR/settings.json.pre-pds" ]; then
      cp "$TARGET_DIR/settings.json" "$TARGET_DIR/settings.json.pre-pds"
      warn "Backed up existing settings → $TARGET_DIR/settings.json.pre-pds"
    fi
    cp "$SRC_DIR/.claude/settings.json" "$TARGET_DIR/settings.json"
    ok "Installed settings → $TARGET_DIR/settings.json"
  fi

  # Handle CLAUDE.md with PDS markers
  install_claude_md "$SRC_DIR/CLAUDE.md" "CLAUDE.md"

  # Write version
  printf '%s\n' "$REMOTE_VERSION" > "$VERSION_FILE"
  ok "Version: $REMOTE_VERSION"

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
  ok "PDS installed! Next steps:"
  echo "    git add .claude CLAUDE.md .gitignore"
  echo "    git commit -m \"feat: add PDS\""
}

install_user() {
  mkdir -p "$TARGET_DIR/skills"

  # Copy skills (fallback for non-PDS projects)
  if [ -d "$SRC_DIR/.claude/skills" ]; then
    cp "$SRC_DIR/.claude/skills/"*.md "$TARGET_DIR/skills/" 2>/dev/null || true
    ok "Installed skills → $TARGET_DIR/skills/"
  fi

  # Copy settings.json (security guardrails for all projects)
  if [ -f "$SRC_DIR/.claude/settings.json" ]; then
    if [ -f "$TARGET_DIR/settings.json" ] && [ ! -f "$TARGET_DIR/settings.json.pre-pds" ]; then
      cp "$TARGET_DIR/settings.json" "$TARGET_DIR/settings.json.pre-pds"
      warn "Backed up existing settings → $TARGET_DIR/settings.json.pre-pds"
      warn "Review and merge your settings: diff $TARGET_DIR/settings.json.pre-pds $TARGET_DIR/settings.json"
    fi
    cp "$SRC_DIR/.claude/settings.json" "$TARGET_DIR/settings.json"
    ok "Installed settings → $TARGET_DIR/settings.json"
  fi

  # Do NOT install agents (Task tool only reads project .claude/agents/)

  # Install user-level CLAUDE.md with conditional skill reference
  install_user_claude_md

  # Write version
  printf '%s\n' "$REMOTE_VERSION" > "$VERSION_FILE"
  ok "Version: $REMOTE_VERSION"

  echo ""
  ok "PDS installed at user level!"
  echo "    Skills in ~/.claude/skills/ are used when projects don't have their own."
  echo "    Settings in ~/.claude/settings.json apply security guardrails everywhere."
  echo "    Agents are project-only — add PDS to a project for agent support."
}

# ============================================================
# Main
# ============================================================

# --- Parse args ---
while [ $# -gt 0 ]; do
  case "$1" in
    --user)  MODE="user"; shift ;;
    --force) FORCE=1; shift ;;
    --help)  usage ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
done

# --- Check dependencies ---
for cmd in curl tar mktemp; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    err "Required command not found: $cmd"
    exit 1
  fi
done

# --- Determine target directory ---
if [ "$MODE" = "user" ]; then
  TARGET_DIR="$HOME/.claude"
  VERSION_FILE="$TARGET_DIR/.pds-version"
  info "User-level install → $TARGET_DIR"
else
  TARGET_DIR=".claude"
  VERSION_FILE="$TARGET_DIR/.pds-version"
  info "Project-level install → $(pwd)/$TARGET_DIR"
fi

# --- Version check ---
LOCAL_VERSION=""
if [ -f "$VERSION_FILE" ]; then
  LOCAL_VERSION=$(cat "$VERSION_FILE")
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
if [ "$MODE" = "user" ]; then
  install_user
else
  install_project
fi
