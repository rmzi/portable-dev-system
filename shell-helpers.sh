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
# Layout: ┌─────────────┬─────────────┐
#         │             │  terminal   │
#         │   claude    ├─────────────┤
#         │             │    yazi     │
#         └─────────────┴─────────────┘
function wty() {
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
    local branch=$(echo "$selection" | awk '{print $1}')

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
  fi
}

# wta - create a new worktree
function wta() {
  if [[ "$1" == "-b" ]]; then
    # New branch
    local branch="$2"
    local dir="../$(basename $(pwd))-${branch//\//-}"
    git worktree add "$dir" -b "$branch" && cd "$dir"
  else
    # Existing branch
    local branch="$1"
    local dir="../$(basename $(pwd))-${branch//\//-}"
    git worktree add "$dir" "$branch" && cd "$dir"
  fi
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
# Zoxide - Smart cd (must be installed: brew install zoxide)
# -----------------------------------------------------------------------------
if command -v zoxide &> /dev/null; then
  eval "$(zoxide init zsh)"
fi
