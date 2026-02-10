# =============================================================================
# Portable Dev System - Shell Helpers
# Add these to your ~/.zshrc or ~/.bashrc
# =============================================================================

# -----------------------------------------------------------------------------
# Yazi File Manager
# -----------------------------------------------------------------------------
export EDITOR="zed --wait"  # Change to your editor: "nvim", "code --wait", etc.

# y - open yazi and cd to directory on exit
function y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}

# -----------------------------------------------------------------------------
# Worktree Helpers
# -----------------------------------------------------------------------------

# wt - open tmux layout for a worktree (can also create new worktrees)
#      Usage: wt           - fuzzy select existing worktree
#             wt branch    - use existing branch
#             wt -b branch - create new branch
# Layout: ┌─────────────┬─────────────┐
#         │             │  terminal   │  (~30%)
#         │   claude    ├─────────────┤  70%
#         │   (50%)     │    yazi     │  (~70%)
#         ├─────────────┴─────────────┤
#         │          lazygit          │  30%
#         └───────────────────────────┘
function wt() {
  local dir branch existing_wt

  if [[ -n "$1" ]]; then
    # Create new worktree (or use existing branch)
    if [[ "$1" == "-b" ]]; then
      branch="$2"
    else
      branch="$1"
    fi

    # Check if branch is already checked out in a worktree
    existing_wt=$(git worktree list 2>/dev/null | grep "\[$branch\]" | awk '{print $1}')
    if [[ -n "$existing_wt" ]]; then
      echo "Branch '$branch' already checked out at: $existing_wt"
      dir="$existing_wt"
    else
      dir="../$(basename $(pwd))-${branch//\//-}"

      # Try new branch first if -b, fall back to existing
      if [[ "$1" == "-b" ]]; then
        git worktree add -b "$branch" "$dir" 2>/dev/null || git worktree add "$dir" "$branch" || return 1
      else
        git worktree add "$dir" "$branch" || return 1
      fi
      dir=$(cd "$dir" && pwd)  # Get absolute path
    fi
  else
    # Fuzzy select existing worktree
    local selection=$(git worktree list 2>/dev/null | \
      awk '{
        path=$1
        branch=$NF
        gsub(/\[|\]/, "", branch)
        n=split(path, parts, "/")
        dir=parts[n]
        printf "%-20s  %-30s  %s\n", branch, dir, path
      }' | \
      fzf --height 40% --reverse --header="BRANCH               DIR                            PATH")

    [[ -z "$selection" ]] && return
    dir=$(echo "$selection" | awk '{print $NF}')
    branch=$(echo "$selection" | awk '{print $1}')
  fi

  command -v branch-tone &>/dev/null && (cd "$dir" && branch-tone "$branch") &>/dev/null &

  # Include repo name in session to avoid collisions across projects
  local repo_name=$(cd "$dir" && basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || basename "$dir")
  local session_name="${repo_name}-${branch//\//-}"
  session_name="${session_name//./_}"  # Escape dots for tmux

  # Create session if it doesn't exist
  if ! tmux has-session -t "$session_name" 2>/dev/null; then
    # Create new session with claude on the left
    tmux new-session -d -s "$session_name" -c "$dir" "claude"

    # Split right pane for terminal
    tmux split-window -h -t "$session_name" -c "$dir"

    # Split bottom-right pane for yazi (70% of right column)
    tmux split-window -v -p 70 -t "$session_name" -c "$dir" "yazi"

    # Full-width bottom pane for lazygit (30% of total height)
    tmux split-window -fv -p 30 -t "${session_name}:1" -c "$dir" "lazygit"

    # Select the terminal pane (top right)
    tmux select-pane -t "${session_name}:1" -U
  fi

  # Attach or switch depending on whether we're in tmux
  if [[ -n "$TMUX" ]]; then
    tmux switch-client -t "$session_name"
  else
    tmux attach -t "$session_name"
  fi
}

# wtr - remove the current worktree and kill its tmux session
function wtr() {
  local dir=$(pwd)
  local main_wt=$(git worktree list 2>/dev/null | head -1 | awk '{print $1}')

  # Make sure we're in a worktree (not the main one)
  if [[ "$dir" == "$main_wt" ]]; then
    echo "Can't remove the main worktree. Use this from a secondary worktree."
    return 1
  fi

  local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  local repo_name=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)
  local session_name="${repo_name}-${branch//\//-}"
  session_name="${session_name//./_}"  # Escape dots for tmux

  echo "Removing worktree: $dir (branch: $branch)"

  # cd to main worktree first
  cd "$main_wt"

  # Kill associated tmux session
  if tmux has-session -t "$session_name" 2>/dev/null; then
    echo "Killing tmux session: $session_name"
    tmux kill-session -t "$session_name"
  fi

  git worktree remove "$dir"
}

# wts - global session picker: see all tmux sessions from anywhere, jump to one
#       Shows session name, working directory, and git branch
function wts() {
  local sessions=$(tmux list-sessions -F "#{session_name}" 2>/dev/null)

  if [[ -z "$sessions" ]]; then
    echo "No active tmux sessions."
    echo "Use 'wt' in a git repo to create one."
    return 1
  fi

  # Build a list with session name, directory, and branch info
  local session_list=()
  while IFS= read -r session; do
    # Get the working directory of the first pane in the session
    local session_path=$(tmux display-message -t "$session" -p "#{pane_current_path}" 2>/dev/null)
    local dir_name=$(basename "$session_path" 2>/dev/null || echo "?")
    local branch=$(cd "$session_path" 2>/dev/null && git branch --show-current 2>/dev/null || echo "-")
    session_list+=("$(printf "%-25s  %-20s  %-15s  %s" "$session" "$dir_name" "$branch" "$session_path")")
  done <<< "$sessions"

  local selection=$(printf '%s\n' "${session_list[@]}" | \
    fzf --height 40% --reverse --header="SESSION                   DIR                   BRANCH           PATH")

  if [[ -n "$selection" ]]; then
    local session_name=$(echo "$selection" | awk '{print $1}')
    local branch=$(echo "$selection" | awk '{print $3}')

    # Audio and visual feedback for session switch
    command -v branch-tone &>/dev/null && branch-tone "$branch" &>/dev/null &

    if [[ -n "$TMUX" ]]; then
      tmux switch-client -t "$session_name"
    else
      tmux attach -t "$session_name"
    fi
  fi
}

# wtc - clean up stale worktrees and orphaned tmux sessions
function wtc() {
  local cleaned=0
  local main_wt=$(git worktree list 2>/dev/null | head -1 | awk '{print $1}')

  if [[ -z "$main_wt" ]]; then
    echo "Not in a git repository."
    return 1
  fi

  echo "🔍 Scanning for stale worktrees and orphaned sessions..."
  echo ""

  # 1. Prune worktrees whose directories no longer exist
  local prunable=$(git worktree list --porcelain 2>/dev/null | grep "^worktree " | awk '{print $2}' | while read wt_path; do
    [[ ! -d "$wt_path" ]] && echo "$wt_path"
  done)

  if [[ -n "$prunable" ]]; then
    echo "Stale worktrees (directory missing):"
    echo "$prunable" | while read p; do echo "  $p"; done
    echo ""
    git worktree prune
    echo "✓ Pruned stale worktrees"
    ((cleaned++))
  fi

  # 2. Find orphaned tmux sessions (session exists but worktree directory is gone)
  local repo_name=$(basename "$main_wt")
  local sessions=$(tmux list-sessions -F "#{session_name}" 2>/dev/null | grep "^${repo_name}-")

  if [[ -n "$sessions" ]]; then
    local worktree_branches=$(git worktree list 2>/dev/null | awk '{print $NF}' | tr -d '[]')

    while IFS= read -r session; do
      # Extract branch from session name (repo-name-branch-name → branch-name)
      local branch_part="${session#${repo_name}-}"

      # Check if any worktree branch matches this session
      local found=false
      while IFS= read -r wt_branch; do
        local normalized="${wt_branch//\//-}"
        normalized="${normalized//./_}"
        if [[ "$branch_part" == "$normalized" ]]; then
          found=true
          break
        fi
      done <<< "$worktree_branches"

      if [[ "$found" == false ]]; then
        echo "Orphaned session (no matching worktree): $session"
        tmux kill-session -t "$session" 2>/dev/null
        echo "✓ Killed session: $session"
        ((cleaned++))
      fi
    done <<< "$sessions"
  fi

  if [[ $cleaned -eq 0 ]]; then
    echo "✅ Nothing to clean up."
  else
    echo ""
    echo "✅ Cleanup complete."
  fi
}

# tmux-reset - kill all tmux sessions (dangerous!)
function tmux-reset() {
  echo "⚠️  This will kill ALL tmux sessions!"
  read -p "Are you sure? (y/n) " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    tmux kill-server 2>/dev/null && echo "✓ All sessions killed" || echo "No tmux server running"
  else
    echo "Cancelled"
  fi
}

# -----------------------------------------------------------------------------
# Git Aliases
# -----------------------------------------------------------------------------
alias gst='git status'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gp='git push'
alias gl='git pull'
alias ga='git add'
alias gc='git commit'
alias gd='git diff'
alias gds='git diff --staged'
alias glog='git log --oneline -20'

# -----------------------------------------------------------------------------
# Fuzzy Git Helpers
# -----------------------------------------------------------------------------
# gco-fzf - fuzzy checkout branch
function gco-fzf() {
  local branch=$(git branch -a --format='%(refname:short)' 2>/dev/null | \
    sed 's|origin/||' | sort -u | \
    fzf --height 40% --reverse --header="Select branch to checkout")
  if [[ -n "$branch" ]]; then
    git checkout "$branch"
  fi
}

# glog-fzf - fuzzy browse commits and show details
function glog-fzf() {
  local commit=$(git log --oneline -50 2>/dev/null | \
    fzf --height 40% --reverse --preview 'git show --stat --color=always {1}' \
        --header="Select commit to view")
  if [[ -n "$commit" ]]; then
    local sha=$(echo "$commit" | awk '{print $1}')
    git show "$sha"
  fi
}

# gstash-fzf - fuzzy apply stash
function gstash-fzf() {
  local stash=$(git stash list 2>/dev/null | \
    fzf --height 40% --reverse --header="Select stash to apply")
  if [[ -n "$stash" ]]; then
    local index=$(echo "$stash" | cut -d: -f1)
    git stash apply "$index"
  fi
}

# gadd-fzf - fuzzy add files
function gadd-fzf() {
  local files=$(git status --short 2>/dev/null | \
    fzf --height 40% --reverse --multi --header="Select files to stage" | \
    awk '{print $2}')
  if [[ -n "$files" ]]; then
    echo "$files" | xargs git add
    git status --short
  fi
}

# -----------------------------------------------------------------------------
# Claude Code
# -----------------------------------------------------------------------------
# clauder = claude --continue (auto-resume most recent session)
alias clauder='claude --continue'

# pds-init - install PDS skills to current project
# Downloads .claude/ config from the repo
# Handles collisions by placing files in .pds-incoming/ for manual merge
function pds-init() {
  local repo_url="https://raw.githubusercontent.com/rmzi/portable-dev-system/main"
  local skills=(commit debug design ethos quickref review test worktree)
  local has_collision=false
  local collision_dir=".pds-incoming"
  local errors=0

  # Check network connectivity
  if ! curl -fsSL --connect-timeout 5 "$repo_url/CLAUDE.md" > /dev/null 2>&1; then
    echo "❌ Cannot reach GitHub. Check your internet connection."
    return 1
  fi

  # Check for existing files
  if [[ -f "CLAUDE.md" ]] || [[ -d ".claude" ]]; then
    has_collision=true
    echo "⚠️  Existing Claude configuration detected!"
    echo ""
    if [[ -f "CLAUDE.md" ]]; then
      echo "   Found: CLAUDE.md"
    fi
    if [[ -d ".claude" ]]; then
      echo "   Found: .claude/"
    fi
    echo ""
    echo "📁 Installing PDS files to $collision_dir/ for manual merge..."
    echo ""
    mkdir -p "$collision_dir/.claude/skills"
  else
    echo "📝 Installing PDS skills to $(pwd)/.claude/"
    mkdir -p .claude/skills
  fi

  local target_dir="."
  if [[ "$has_collision" == true ]]; then
    target_dir="$collision_dir"
  fi

  # Download CLAUDE.md
  if curl -fsSL "$repo_url/CLAUDE.md" > "$target_dir/CLAUDE.md" 2>/dev/null; then
    echo "  ✓ CLAUDE.md"
  else
    echo "  ✗ CLAUDE.md (failed)"; ((errors++))
  fi

  # Download version marker
  local version=$(curl -fsSL "$repo_url/VERSION" 2>/dev/null || echo "unknown")
  echo "$version" > "$target_dir/.claude/.pds-version"
  echo "  ✓ .claude/.pds-version ($version)"

  # Download settings and hooks
  if curl -fsSL "$repo_url/.claude/settings.json" > "$target_dir/.claude/settings.json" 2>/dev/null; then
    echo "  ✓ .claude/settings.json"
  else
    echo "  ✗ .claude/settings.json (failed)"; ((errors++))
  fi

  if curl -fsSL "$repo_url/.claude/hooks.json" > "$target_dir/.claude/hooks.json" 2>/dev/null; then
    echo "  ✓ .claude/hooks.json"
  else
    echo "  ✗ .claude/hooks.json (failed)"; ((errors++))
  fi

  # Download skills
  for skill in "${skills[@]}"; do
    if curl -fsSL "$repo_url/.claude/skills/${skill}.md" > "$target_dir/.claude/skills/${skill}.md" 2>/dev/null; then
      echo "  ✓ .claude/skills/${skill}.md"
    else
      echo "  ✗ .claude/skills/${skill}.md (failed)"; ((errors++))
    fi
  done

  if [[ $errors -gt 0 ]]; then
    echo ""
    echo "⚠️  $errors file(s) failed to download. Run pds-init again to retry."
  fi

  echo ""
  if [[ "$has_collision" == true ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 PDS files saved to: $collision_dir/"
    echo ""
    echo "To merge with your existing config, ask Claude:"
    echo ""
    echo "   Merge the PDS skills from .pds-incoming/ with my existing"
    echo "   .claude/ config. Add the Skills System section from"
    echo "   .pds-incoming/CLAUDE.md to my CLAUDE.md, copy any new"
    echo "   skills, and remove .pds-incoming/"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  else
    echo "✅ Done! Skills available:"
    echo "   /ethos /commit /review /debug /design /test /worktree /bootstrap /quickref"
  fi
}

# pds-uninstall - remove PDS from system
function pds-uninstall() {
  echo "🗑️  Uninstalling Portable Dev System..."
  echo ""

  # Remove ~/.pds
  if [[ -d "$HOME/.pds" ]]; then
    rm -rf "$HOME/.pds"
    echo "✓ Removed ~/.pds/"
  fi

  # Restore shell rc from backup if it exists
  local shell_rc
  if [[ "$SHELL" == *"zsh"* ]]; then
    shell_rc="$HOME/.zshrc"
  else
    shell_rc="$HOME/.bashrc"
  fi

  if [[ -f "${shell_rc}.pds-backup" ]]; then
    cp "${shell_rc}.pds-backup" "$shell_rc"
    echo "✓ Restored $shell_rc from backup"
  else
    # Manual removal of source line
    if grep -q ".pds/shell-helpers.sh" "$shell_rc" 2>/dev/null; then
      # Create backup before modifying
      cp "$shell_rc" "${shell_rc}.pre-uninstall"
      grep -v ".pds/shell-helpers.sh" "$shell_rc" | grep -v "# Portable Dev System" > "${shell_rc}.tmp"
      mv "${shell_rc}.tmp" "$shell_rc"
      echo "✓ Removed PDS lines from $shell_rc (backup: ${shell_rc}.pre-uninstall)"
    fi
  fi

  # Offer to restore tmux.conf
  if [[ -f "$HOME/.tmux.conf.backup" ]]; then
    read -p "Restore tmux.conf from backup? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      mv "$HOME/.tmux.conf.backup" "$HOME/.tmux.conf"
      echo "✓ Restored ~/.tmux.conf"
    fi
  fi

  # Offer to restore starship.toml
  if [[ -f "$HOME/.config/starship.toml.backup" ]]; then
    read -p "Restore starship.toml from backup? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      mv "$HOME/.config/starship.toml.backup" "$HOME/.config/starship.toml"
      echo "✓ Restored ~/.config/starship.toml"
    fi
  fi

  # Offer to restore Claude settings
  if [[ -f "$HOME/.claude/settings.json.backup" ]]; then
    read -p "Restore Claude settings from backup? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      mv "$HOME/.claude/settings.json.backup" "$HOME/.claude/settings.json"
      echo "✓ Restored ~/.claude/settings.json"
    fi
  fi

  echo ""
  echo "✅ PDS uninstalled. Restart your terminal to complete."
  echo ""
  echo "Note: Project-level files (.claude/, CLAUDE.md) are untouched."
  echo "Remove them manually if desired: rm -rf .claude CLAUDE.md"
}

# pds-update - update PDS (system or project)
# Usage: pds-update          - update project skills
#        pds-update --system - update ~/.pds shell helpers
function pds-update() {
  local repo_url="https://raw.githubusercontent.com/rmzi/portable-dev-system/main"

  if [[ "$1" == "--system" ]] || [[ "$1" == "-s" ]]; then
    # System update - update ~/.pds/shell-helpers.sh
    echo "🔄 Updating PDS system files..."

    local remote_version=$(curl -fsSL "$repo_url/VERSION" 2>/dev/null || echo "unknown")

    if curl -fsSL "$repo_url/shell-helpers.sh" > "$HOME/.pds/shell-helpers.sh" 2>/dev/null; then
      echo "  ✓ ~/.pds/shell-helpers.sh"
    else
      echo "  ✗ Failed to update shell-helpers.sh"
      return 1
    fi

    echo ""
    echo "✅ System updated to v$remote_version"
    echo "   Run: source ~/.pds/shell-helpers.sh"
    return 0
  fi

  # Project update - update .claude/skills/
  local skills=(commit debug design ethos quickref review test worktree)

  # Check if PDS is installed in this project
  if [[ ! -f ".claude/.pds-version" ]]; then
    echo "❌ PDS not installed in this project."
    echo ""
    echo "Options:"
    echo "  pds-init          - install PDS skills to this project"
    echo "  pds-update -s     - update system shell helpers"
    return 1
  fi

  local current_version=$(cat .claude/.pds-version 2>/dev/null || echo "unknown")
  local remote_version=$(curl -fsSL "$repo_url/VERSION" 2>/dev/null || echo "unknown")

  echo "📦 PDS Update Check"
  echo "   Installed: v$current_version"
  echo "   Available: v$remote_version"
  echo ""

  if [[ "$current_version" == "$remote_version" ]]; then
    echo "✅ Already up to date!"
    return 0
  fi

  echo "🔄 Updating skills..."

  # Update skills (only PDS skills, not project-specific ones)
  for skill in "${skills[@]}"; do
    if curl -fsSL "$repo_url/.claude/skills/${skill}.md" > ".claude/skills/${skill}.md" 2>/dev/null; then
      echo "  ✓ ${skill}.md"
    else
      echo "  ✗ ${skill}.md (failed)"
    fi
  done

  # Update version marker
  echo "$remote_version" > .claude/.pds-version

  echo ""
  echo "✅ Updated to v$remote_version"
  echo ""
  echo "View changes: https://github.com/rmzi/portable-dev-system/blob/main/CHANGELOG.md"
}

# -----------------------------------------------------------------------------
# Branch-tone Addon (optional audio feedback for branch switches)
# -----------------------------------------------------------------------------
# pds-addon - manage optional PDS addons
# Usage: pds-addon branch-tone [install|update|remove]
function pds-addon() {
  local addon="$1"
  local action="$2"

  if [[ "$addon" != "branch-tone" ]]; then
    echo "Available addons:"
    echo "  branch-tone - Audio feedback when switching branches"
    echo ""
    echo "Usage: pds-addon <addon> [install|update|remove]"
    return 1
  fi

  case "$action" in
    install)
      echo "🎵 Installing branch-tone..."

      # Check for cargo
      if ! command -v cargo &>/dev/null; then
        echo "❌ Rust/Cargo required. Install from https://rustup.rs"
        return 1
      fi

      # Check for jq
      if ! command -v jq &>/dev/null; then
        echo "❌ jq required. Install with: brew install jq"
        return 1
      fi

      # Install branch-tone
      cargo install branch-tone

      # Create hook scripts
      mkdir -p "$HOME/.pds"
      cat > "$HOME/.pds/branch-tone-hook.sh" << 'HOOK'
#!/bin/bash
# Branch-tone hook wrapper for Claude Code
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "claude")
repo=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")
branch-tone "$branch" --repo "$repo" --pad --chorus --steps 5 -d 800 -v 0.2
HOOK
      chmod +x "$HOME/.pds/branch-tone-hook.sh"

      # Add Stop hook to Claude settings
      local settings_file="$HOME/.claude/settings.json"
      local hook_cmd="$HOME/.pds/branch-tone-hook.sh"
      local hook_entry='{"hooks":[{"type":"command","command":"'"$hook_cmd"'","async":true}]}'

      if [[ -f "$settings_file" ]]; then
        # Check if Stop hook already exists
        if jq -e '.hooks.Stop' "$settings_file" &>/dev/null; then
          echo "⚠️  Stop hook already exists in settings.json - skipping"
        else
          # Add hooks.Stop to existing settings
          local tmp_file=$(mktemp)
          jq --argjson hook "[$hook_entry]" '.hooks = (.hooks // {}) + {Stop: $hook}' "$settings_file" > "$tmp_file" && \
            mv "$tmp_file" "$settings_file"
          echo "✓ Added Stop hook to ~/.claude/settings.json"
        fi
      else
        echo "⚠️  ~/.claude/settings.json not found - skipping hook setup"
        echo "   Run pds-install first, then re-run this addon install"
      fi

      echo ""
      echo "✅ branch-tone installed!"
      echo ""
      echo "Restart Claude Code for the hook to take effect."
      echo ""
      ;;

    update)
      echo "🔄 Updating branch-tone..."
      if ! command -v branch-tone &>/dev/null; then
        echo "❌ branch-tone not installed. Run: pds-addon branch-tone install"
        return 1
      fi
      cargo install branch-tone --force
      echo "✅ branch-tone updated!"
      ;;

    remove)
      echo "🗑️  Removing branch-tone..."

      # Remove binary
      if command -v branch-tone &>/dev/null; then
        cargo uninstall branch-tone 2>/dev/null || rm -f "$HOME/.cargo/bin/branch-tone"
        echo "✓ Removed branch-tone binary"
      fi

      # Remove hook script
      if [[ -f "$HOME/.pds/branch-tone-hook.sh" ]]; then
        rm -f "$HOME/.pds/branch-tone-hook.sh"
        echo "✓ Removed branch-tone hook script"
      fi

      # Remove Stop hook from Claude settings
      local settings_file="$HOME/.claude/settings.json"
      if [[ -f "$settings_file" ]] && command -v jq &>/dev/null; then
        if jq -e '.hooks.Stop' "$settings_file" &>/dev/null; then
          local tmp_file=$(mktemp)
          jq 'del(.hooks.Stop) | if .hooks == {} then del(.hooks) else . end' "$settings_file" > "$tmp_file" && \
            mv "$tmp_file" "$settings_file"
          echo "✓ Removed Stop hook from settings.json"
        fi
      fi

      echo ""
      echo "✅ branch-tone removed!"
      echo ""
      ;;

    *)
      echo "Usage: pds-addon branch-tone [install|update|remove]"
      echo ""
      echo "  install - Install branch-tone and create hook script"
      echo "  update  - Update branch-tone to latest version"
      echo "  remove  - Uninstall branch-tone and remove hook script"
      ;;
  esac
}

# -----------------------------------------------------------------------------
# Zoxide - Smart cd (must be installed: brew install zoxide)
# -----------------------------------------------------------------------------
if command -v zoxide &> /dev/null; then
  # Detect shell and init zoxide accordingly
  if [[ -n "$ZSH_VERSION" ]]; then
    eval "$(zoxide init zsh)"
  elif [[ -n "$BASH_VERSION" ]]; then
    eval "$(zoxide init bash)"
  fi
fi
