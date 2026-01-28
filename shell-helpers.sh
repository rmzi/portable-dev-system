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

# wty - fuzzy pick a worktree and open in yazi
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
    cd "$dir" && y
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
# Zoxide - Smart cd (must be installed: brew install zoxide)
# -----------------------------------------------------------------------------
if command -v zoxide &> /dev/null; then
  eval "$(zoxide init zsh)"
fi
