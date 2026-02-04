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

# wt - fuzzy pick a worktree and cd to it
function wt() {
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

  if [[ -n "$selection" ]]; then
    local dir=$(echo "$selection" | awk '{print $NF}')
    cd "$dir"
  fi
}

# wty - fuzzy pick a worktree and open tmux layout with claude, terminal, and yazi
#       or create a new worktree: wty branch | wty -b new-branch
# Layout: ┌─────────────┬─────────────┐
#         │             │  terminal   │
#         │   claude    ├─────────────┤
#         │             │    yazi     │
#         └─────────────┴─────────────┘
function wty() {
  local dir branch

  if [[ -n "$1" ]]; then
    # Create new worktree (or use existing branch)
    if [[ "$1" == "-b" ]]; then
      branch="$2"
    else
      branch="$1"
    fi
    dir="../$(basename $(pwd))-${branch//\//-}"

    # Try new branch first if -b, fall back to existing
    if [[ "$1" == "-b" ]]; then
      git worktree add "$dir" -b "$branch" 2>/dev/null || git worktree add "$dir" "$branch" || return 1
    else
      git worktree add "$dir" "$branch" || return 1
    fi
    dir=$(cd "$dir" && pwd)  # Get absolute path
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

  local session_name="wt-${branch//\//-}"

  if tmux has-session -t "$session_name" 2>/dev/null; then
    tmux attach -t "$session_name"
  else
    # Create new session with claude on the left
    tmux new-session -d -s "$session_name" -c "$dir" "claude"

    # Split horizontally - terminal on the right
    tmux split-window -h -t "$session_name" -c "$dir"

    # Split the right pane (terminal) vertically - yazi at bottom right
    tmux split-window -v -t "$session_name" -c "$dir" "y"

    # Select the terminal pane (top right, pane 1)
    tmux select-pane -t "$session_name:0.1"

    tmux attach -t "$session_name"
  fi
}

# wta - create a new worktree
# Usage: wta branch (existing) or wta -b branch (new, falls back to existing)
function wta() {
  local branch dir
  if [[ "$1" == "-b" ]]; then
    branch="$2"
  else
    branch="$1"
  fi
  dir="../$(basename $(pwd))-${branch//\//-}"

  # Try new branch first if -b, fall back to existing
  if [[ "$1" == "-b" ]]; then
    git worktree add "$dir" -b "$branch" 2>/dev/null || git worktree add "$dir" "$branch"
  else
    git worktree add "$dir" "$branch"
  fi && cd "$dir"
}

# wtl - list worktrees
alias wtl='git worktree list'

# wtr - remove a worktree (fuzzy select)
function wtr() {
  local dir=$(git worktree list 2>/dev/null | fzf --height 40% --reverse | awk '{print $1}')
  if [[ -n "$dir" ]]; then
    git worktree remove "$dir"
  fi
}

# -----------------------------------------------------------------------------
# Tmux Session Helpers
# -----------------------------------------------------------------------------
# ts - list or attach to tmux sessions
function ts() {
  if [[ -z "$1" ]]; then
    # No arg: list sessions or show help
    if tmux list-sessions 2>/dev/null; then
      echo ""
      echo "Attach: ts <name> | New: ts -n <name>"
    else
      echo "No sessions. Create one: ts -n <name>"
    fi
  elif [[ "$1" == "-n" ]]; then
    # New session
    tmux new-session -s "$2"
  else
    # Attach to existing
    tmux attach -t "$1" 2>/dev/null || tmux new-session -s "$1"
  fi
}

# tsk - kill a tmux session (fuzzy select)
function tsk() {
  local session=$(tmux list-sessions -F "#{session_name}" 2>/dev/null | fzf --height 40% --reverse)
  if [[ -n "$session" ]]; then
    tmux kill-session -t "$session"
  fi
}

# twt - create/attach tmux session for current worktree
function twt() {
  local session_name=$(basename $(pwd))
  if tmux has-session -t "$session_name" 2>/dev/null; then
    tmux attach -t "$session_name"
  else
    tmux new-session -s "$session_name"
  fi
}

# Quick aliases
alias tl='tmux list-sessions'
alias td='tmux detach'

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
# Ghostty Helpers (with tmux for session persistence)
# -----------------------------------------------------------------------------
# wtyg - fuzzy pick a worktree and open tmux layout (with session resume)
#        or create a new worktree: wtyg branch | wtyg -b new-branch
# Layout: ┌─────────────┬─────────────┐
#         │             │  terminal   │
#         │   claude    ├─────────────┤
#         │             │    yazi     │
#         └─────────────┴─────────────┘
# Session persistence: reattaching restores terminal AND Claude conversation
function wtyg() {
  local dir branch

  if [[ -n "$1" ]]; then
    # Create new worktree (or use existing branch)
    if [[ "$1" == "-b" ]]; then
      branch="$2"
    else
      branch="$1"
    fi
    dir="../$(basename $(pwd))-${branch//\//-}"

    # Try new branch first if -b, fall back to existing
    if [[ "$1" == "-b" ]]; then
      git worktree add "$dir" -b "$branch" 2>/dev/null || git worktree add "$dir" "$branch" || return 1
    else
      git worktree add "$dir" "$branch" || return 1
    fi
    dir=$(cd "$dir" && pwd)  # Get absolute path
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

  local session_name="wtyg-${branch//\//-}"

  if tmux has-session -t "$session_name" 2>/dev/null; then
    # Reattach to existing session (terminal + claude preserved)
    tmux attach -t "$session_name"
  else
    # Create new session with claude on the left
    tmux new-session -d -s "$session_name" -c "$dir" "claude"

    # Split horizontally - terminal on the right
    tmux split-window -h -t "$session_name" -c "$dir"

    # Split the right pane (terminal) vertically - yazi at bottom right
    tmux split-window -v -t "$session_name" -c "$dir" "y"

    # Select the terminal pane (top right, pane 1)
    tmux select-pane -t "$session_name:0.1"

    tmux attach -t "$session_name"
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
  local skills=(bootstrap commit debug design ethos quickref review test worktree wt)
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
    echo "   .claude/ config. Combine CLAUDE.md files and add any new"
    echo "   skills. Then remove .pds-incoming/"
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

  echo ""
  echo "✅ PDS uninstalled. Restart your terminal to complete."
  echo ""
  echo "Note: Project-level files (.claude/, CLAUDE.md) are untouched."
  echo "Remove them manually if desired: rm -rf .claude CLAUDE.md"
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
