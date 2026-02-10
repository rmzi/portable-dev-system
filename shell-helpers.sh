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

    # Warn if creating a worktree from a non-default branch (nested worktree)
    local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [[ "$current_branch" != "main" && "$current_branch" != "dev" ]]; then
      local main_wt_path=$(git worktree list 2>/dev/null | head -1 | awk '{print $1}')
      if [[ "$(pwd -P)" != "$main_wt_path" ]]; then
        echo "⚠️  Creating worktree from branch '$current_branch' (not main/dev)"
        echo "   Parent: $(basename $(pwd))"
        read -p "   Continue? (y/n) " -n 1 -r
        echo ""
        [[ ! $REPLY =~ ^[Yy]$ ]] && return 0
      fi
    fi

    # Check if branch is already checked out in a worktree
    existing_wt=$(git worktree list 2>/dev/null | grep "\[$branch\]" | awk '{print $1}')
    if [[ -n "$existing_wt" ]]; then
      echo "Branch '$branch' already checked out at: $existing_wt"
      dir="$existing_wt"
    else
      # Always resolve from main worktree so path is consistent from anywhere
      local main_wt=$(git worktree list 2>/dev/null | head -1 | awk '{print $1}')
      mkdir -p "${main_wt}/.worktrees"

      # Auto-add .worktrees/ to .gitignore
      local gitignore="${main_wt}/.gitignore"
      if ! grep -qx '.worktrees/' "$gitignore" 2>/dev/null; then
        echo '.worktrees/' >> "$gitignore"
      fi

      dir="${main_wt}/.worktrees/${branch//\//-}"

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

  if command -v branch-tone &>/dev/null; then
    local __bt_repo=$(cd "$dir" && basename "$(dirname "$(cd "$(git rev-parse --git-common-dir 2>/dev/null)" && pwd)")" 2>/dev/null)
    (branch-tone "$branch" --repo "${__bt_repo:-unknown}") &>/dev/null &
  fi

  # Include repo name in session to avoid collisions across projects
  # Always derive from main worktree (git rev-parse --show-toplevel returns worktree path inside .worktrees/)
  local main_wt_for_name=$(cd "$dir" && git worktree list 2>/dev/null | head -1 | awk '{print $1}')
  local repo_name=$(basename "$main_wt_for_name")
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
  local main_wt_for_name=$(git worktree list 2>/dev/null | head -1 | awk '{print $1}')
  local repo_name=$(basename "$main_wt_for_name")
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

    # Audio feedback for session switch
    if command -v branch-tone &>/dev/null; then
      local __bt_path=$(echo "$selection" | awk '{print $NF}')
      local __bt_repo=$(cd "$__bt_path" && basename "$(dirname "$(cd "$(git rev-parse --git-common-dir 2>/dev/null)" && pwd)")" 2>/dev/null)
      branch-tone "$branch" --repo "${__bt_repo:-unknown}" &>/dev/null &
    fi

    if [[ -n "$TMUX" ]]; then
      tmux switch-client -t "$session_name"
    else
      tmux attach -t "$session_name"
    fi
  fi
}

# -----------------------------------------------------------------------------
# Worktree Cleanup Internals
# -----------------------------------------------------------------------------

# __pds_discover_repos - find all git repos with worktrees
# Scans tmux sessions and configurable directories
# Outputs: one main worktree path per line (deduplicated)
function __pds_discover_repos() {
  local scan_dirs="$HOME/dev"
  local found=""

  # Load config if exists
  if [[ -f "$HOME/.pds/eod.conf" ]]; then
    source "$HOME/.pds/eod.conf"
    scan_dirs="${SCAN_DIRS:-$scan_dirs}"
  fi

  # 1. Scan tmux session panes for git repos
  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    local main=$(git -C "$path" worktree list 2>/dev/null | head -1 | awk '{print $1}')
    [[ -n "$main" ]] && found="${found}${main}\n"
  done < <(tmux list-panes -a -F "#{pane_current_path}" 2>/dev/null | sort -u)

  # 2. Scan configured directories for git repos
  for scan_dir in $scan_dirs; do
    [[ ! -d "$scan_dir" ]] && continue
    for d in "$scan_dir"/*/; do
      [[ ! -d "${d}.git" && ! -f "${d}.git" ]] && continue
      local main=$(git -C "$d" worktree list 2>/dev/null | head -1 | awk '{print $1}')
      [[ -n "$main" ]] && found="${found}${main}\n"
    done
  done

  echo -e "$found" | grep -v '^$' | sort -u
}

# __pds_scan_worktree - check status of a single worktree
# Args: $1 = worktree path
# Outputs: space-separated flags (clean|dirty|unpushed|no_upstream|open_pr|conflicts)
function __pds_scan_worktree() {
  local path="$1"
  local flags=""

  # Uncommitted changes (staged + unstaged)
  if [[ -n "$(git -C "$path" status --porcelain 2>/dev/null)" ]]; then
    flags="${flags}dirty "
  fi

  # Merge conflicts
  if [[ -n "$(git -C "$path" ls-files -u 2>/dev/null)" ]]; then
    flags="${flags}conflicts "
  fi

  # Unpushed commits
  if git -C "$path" rev-parse --abbrev-ref '@{upstream}' &>/dev/null; then
    if [[ -n "$(git -C "$path" log '@{upstream}..HEAD' --oneline 2>/dev/null)" ]]; then
      flags="${flags}unpushed "
    fi
  else
    flags="${flags}no_upstream "
  fi

  # Open PRs (if gh is available)
  if command -v gh &>/dev/null; then
    local branch=$(git -C "$path" rev-parse --abbrev-ref HEAD 2>/dev/null)
    local pr_json=$(gh pr list --head "$branch" --state open --json number,title 2>/dev/null)
    if [[ -n "$pr_json" && "$pr_json" != "[]" ]]; then
      flags="${flags}open_pr "
    fi
  fi

  if [[ -z "$flags" ]]; then
    echo "clean"
  else
    echo "$flags"
  fi
}

# __pds_repo_cleanup - clean up worktrees for a single repo
# Args: $1 = main worktree path, $2 = "batch" (skip prompts, only remove clean/merged)
# Returns: number of items cleaned
function __pds_repo_cleanup() {
  local main_wt="$1"
  local mode="${2:-interactive}"
  local cleaned=0
  local repo_name=$(basename "$main_wt")

  # 1. Prune worktrees whose directories no longer exist
  local prunable=$(git -C "$main_wt" worktree list --porcelain 2>/dev/null | grep "^worktree " | awk '{print $2}' | while read wt_path; do
    [[ ! -d "$wt_path" ]] && echo "$wt_path"
  done)

  if [[ -n "$prunable" ]]; then
    echo "Stale worktrees (directory missing):"
    echo "$prunable" | while read p; do echo "  $p"; done
    echo ""
    git -C "$main_wt" worktree prune
    echo "✓ Pruned stale worktrees"
    ((cleaned++))
  fi

  # 2. Find orphaned tmux sessions (session exists but worktree directory is gone)
  local sessions=$(tmux list-sessions -F "#{session_name}" 2>/dev/null | grep "^${repo_name}-")

  if [[ -n "$sessions" ]]; then
    local worktree_branches=$(git -C "$main_wt" worktree list 2>/dev/null | awk '{print $NF}' | tr -d '[]')

    while IFS= read -r session; do
      local branch_part="${session#${repo_name}-}"

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

  # 3. Remove worktrees whose branches have been merged to main
  local current_wt=$(pwd -P)
  local main_branch=$(git -C "$main_wt" symbolic-ref --short HEAD 2>/dev/null || echo "main")
  local merged_branches=$(git -C "$main_wt" branch --merged "$main_branch" 2>/dev/null | sed 's/^[* ]*//')
  local removable=()

  local all_wt_paths=()
  local all_wt_branches=()
  while IFS= read -r wt_line; do
    all_wt_paths+=("$(echo "$wt_line" | awk '{print $1}')")
    all_wt_branches+=("$(echo "$wt_line" | awk '{print $NF}' | tr -d '[]')")
  done < <(git -C "$main_wt" worktree list 2>/dev/null)

  for i in "${!all_wt_paths[@]}"; do
    local wt_path="${all_wt_paths[$i]}"
    local wt_branch="${all_wt_branches[$i]}"

    [[ "$wt_path" == "$main_wt" ]] && continue
    [[ "$wt_path" == "$current_wt" ]] && continue
    [[ "$wt_branch" == "$main_branch" ]] && continue

    if echo "$merged_branches" | grep -qx "$wt_branch"; then
      removable+=("$wt_path|$wt_branch|merged")

      local wt_dir_name=$(basename "$wt_path")
      for j in "${!all_wt_paths[@]}"; do
        local child_path="${all_wt_paths[$j]}"
        local child_branch="${all_wt_branches[$j]}"
        local child_dir_name=$(basename "$child_path")

        if [[ "$child_dir_name" == "${wt_dir_name}-"* && "$child_path" != "$wt_path" ]]; then
          local already_listed=false
          for entry in "${removable[@]}"; do
            [[ "${entry%%|*}" == "$child_path" ]] && already_listed=true && break
          done
          [[ "$already_listed" == false ]] && removable+=("$child_path|$child_branch|child of $wt_branch")
        fi
      done
    fi
  done

  if [[ ${#removable[@]} -gt 0 ]]; then
    echo ""
    echo "Merged worktrees (branch already in $main_branch):"
    for entry in "${removable[@]}"; do
      local wt_path=$(echo "$entry" | cut -d'|' -f1)
      local wt_branch=$(echo "$entry" | cut -d'|' -f2)
      local reason=$(echo "$entry" | cut -d'|' -f3)
      echo "  $wt_branch → $wt_path ($reason)"
    done

    local do_remove=false
    if [[ "$mode" == "batch" ]]; then
      do_remove=true
    else
      echo ""
      read -p "Remove these worktrees and delete their branches? (y/n) " -n 1 -r
      echo ""
      [[ $REPLY =~ ^[Yy]$ ]] && do_remove=true
    fi

    if [[ "$do_remove" == true ]]; then
      for (( i=${#removable[@]}-1; i>=0; i-- )); do
        local entry="${removable[$i]}"
        local wt_path=$(echo "$entry" | cut -d'|' -f1)
        local wt_branch=$(echo "$entry" | cut -d'|' -f2)

        local normalized="${wt_branch//\//-}"
        normalized="${normalized//./_}"
        tmux kill-session -t "${repo_name}-${normalized}" 2>/dev/null

        git -C "$main_wt" worktree remove "$wt_path" --force 2>/dev/null
        git -C "$main_wt" branch -d "$wt_branch" 2>/dev/null
        echo "✓ Removed $wt_branch ($wt_path)"
        ((cleaned++))
      done
    else
      echo "Skipped merged worktree cleanup."
    fi
  fi

  return $cleaned
}

# __pds_migrate_siblings - detect and migrate old sibling-format worktrees into .worktrees/
# Args: $1 = main worktree path
function __pds_migrate_siblings() {
  local main_wt="$1"
  local repo_name=$(basename "$main_wt")
  local parent_dir=$(dirname "$main_wt")
  local migratable=()

  # Find sibling dirs that are worktrees of this repo
  while IFS= read -r wt_line; do
    local wt_path=$(echo "$wt_line" | awk '{print $1}')
    local wt_branch=$(echo "$wt_line" | awk '{print $NF}' | tr -d '[]')

    [[ "$wt_path" == "$main_wt" ]] && continue

    # Check if it's a sibling (lives in parent dir, not in .worktrees/)
    local wt_parent=$(dirname "$wt_path")
    if [[ "$wt_parent" == "$parent_dir" ]]; then
      migratable+=("$wt_path|$wt_branch")
    fi
  done < <(git -C "$main_wt" worktree list 2>/dev/null)

  if [[ ${#migratable[@]} -eq 0 ]]; then
    return 0
  fi

  echo ""
  echo "Old-format sibling worktrees found:"
  for entry in "${migratable[@]}"; do
    local wt_path=$(echo "$entry" | cut -d'|' -f1)
    local wt_branch=$(echo "$entry" | cut -d'|' -f2)
    echo "  $(basename "$wt_path") → branch: $wt_branch"
  done
  echo ""
  read -p "Migrate to .worktrees/ inside the repo? (y/n) " -n 1 -r
  echo ""

  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Skipped migration."
    return 0
  fi

  mkdir -p "${main_wt}/.worktrees"

  # Auto-add .worktrees/ to .gitignore
  local gitignore="${main_wt}/.gitignore"
  if ! grep -qx '.worktrees/' "$gitignore" 2>/dev/null; then
    echo '.worktrees/' >> "$gitignore"
  fi

  local migrated=0
  for entry in "${migratable[@]}"; do
    local wt_path=$(echo "$entry" | cut -d'|' -f1)
    local wt_branch=$(echo "$entry" | cut -d'|' -f2)
    local new_path="${main_wt}/.worktrees/${wt_branch//\//-}"

    if git -C "$main_wt" worktree move "$wt_path" "$new_path" 2>/dev/null; then
      echo "✓ Migrated $wt_branch → .worktrees/${wt_branch//\//-}"

      # Update tmux session path if active
      local repo_name=$(basename "$main_wt")
      local normalized="${wt_branch//\//-}"
      normalized="${normalized//./_}"
      local session_name="${repo_name}-${normalized}"
      if tmux has-session -t "$session_name" 2>/dev/null; then
        # Update all panes in the session to the new path
        local panes=$(tmux list-panes -t "$session_name" -F "#{pane_id}" 2>/dev/null)
        while IFS= read -r pane_id; do
          tmux send-keys -t "$pane_id" "cd '$new_path'" Enter 2>/dev/null
        done <<< "$panes"
        echo "  ↳ Updated tmux session: $session_name"
      fi

      ((migrated++))
    else
      echo "✗ Failed to migrate $wt_branch"
    fi
  done

  echo ""
  echo "✓ Migrated $migrated worktree(s)"
}

# wtc - clean up stale worktrees and orphaned tmux sessions
#       Usage: wtc        - clean current repo
#              wtc --all  - end-of-day cleanup across all repos
function wtc() {
  if [[ "$1" == "--all" ]]; then
    __pds_wtc_all
    return $?
  fi

  local main_wt=$(git worktree list 2>/dev/null | head -1 | awk '{print $1}')

  if [[ -z "$main_wt" ]]; then
    echo "Not in a git repository."
    return 1
  fi

  echo "🔍 Scanning for stale worktrees and orphaned sessions..."
  echo ""

  # Migrate old sibling worktrees if found
  __pds_migrate_siblings "$main_wt"

  __pds_repo_cleanup "$main_wt"
  local cleaned=$?

  if [[ $cleaned -eq 0 ]]; then
    echo "✅ Nothing to clean up."
  else
    echo ""
    echo "✅ Cleanup complete."
  fi
}

# __pds_wtc_all - end-of-day cleanup across all repos
function __pds_wtc_all() {
  echo ""
  echo "=== PDS End of Day ==="
  echo ""
  echo "Scanning repos..."

  local repos=()
  while IFS= read -r repo; do
    [[ -n "$repo" ]] && repos+=("$repo")
  done < <(__pds_discover_repos)

  if [[ ${#repos[@]} -eq 0 ]]; then
    echo "  No repos with worktrees found."
    echo ""
    echo "Configure scan directories in ~/.pds/eod.conf:"
    echo '  SCAN_DIRS="$HOME/dev $HOME/work"'
    return 0
  fi

  # Phase 1: Scan and summarize
  local total_wt=0
  local ready_to_remove=0
  local needs_resolution=0
  local repo_summaries=()

  for main_wt in "${repos[@]}"; do
    local repo_name=$(basename "$main_wt")
    local repo_summary="REPO: $repo_name ($main_wt)"
    local repo_wt_lines=""

    while IFS= read -r wt_line; do
      local wt_path=$(echo "$wt_line" | awk '{print $1}')
      local wt_branch=$(echo "$wt_line" | awk '{print $NF}' | tr -d '[]')

      [[ "$wt_path" == "$main_wt" ]] && continue
      ((total_wt++))

      local flags=$(__pds_scan_worktree "$wt_path")
      local main_branch=$(git -C "$main_wt" symbolic-ref --short HEAD 2>/dev/null || echo "main")
      local is_merged=$(git -C "$main_wt" branch --merged "$main_branch" 2>/dev/null | sed 's/^[* ]*//' | grep -qx "$wt_branch" && echo "yes" || echo "no")

      # Determine display path (prefer relative .worktrees/ form)
      local display_path="$wt_path"
      if [[ "$wt_path" == "${main_wt}/.worktrees/"* ]]; then
        display_path=".worktrees/$(basename "$wt_path")"
      else
        display_path="$(basename "$wt_path")"
      fi

      local status_str=""
      if [[ "$flags" == "clean" && "$is_merged" == "yes" ]]; then
        status_str="CLEAN (merged) — ready to remove"
        ((ready_to_remove++))
      elif [[ "$flags" == "clean" ]]; then
        status_str="clean (unmerged)"
      else
        local detail_parts=()
        [[ "$flags" == *dirty* ]] && detail_parts+=("uncommitted changes")
        [[ "$flags" == *unpushed* ]] && detail_parts+=("unpushed commits")
        [[ "$flags" == *no_upstream* ]] && detail_parts+=("no upstream")
        [[ "$flags" == *open_pr* ]] && detail_parts+=("open PR")
        [[ "$flags" == *conflicts* ]] && detail_parts+=("merge conflicts")
        local IFS=', '
        status_str="${detail_parts[*]}"
        ((needs_resolution++))
      fi

      repo_wt_lines="${repo_wt_lines}  ${display_path}  ${status_str}\n"
    done < <(git -C "$main_wt" worktree list 2>/dev/null)

    # Also check for old sibling worktrees
    local parent_dir=$(dirname "$main_wt")
    while IFS= read -r wt_line; do
      local wt_path=$(echo "$wt_line" | awk '{print $1}')
      [[ "$wt_path" == "$main_wt" ]] && continue
      local wt_parent=$(dirname "$wt_path")
      if [[ "$wt_parent" == "$parent_dir" ]]; then
        local wt_branch=$(echo "$wt_line" | awk '{print $NF}' | tr -d '[]')
        repo_wt_lines="${repo_wt_lines}  $(basename "$wt_path")  ⚠ old sibling format (migrate with wtc)\n"
      fi
    done < <(git -C "$main_wt" worktree list 2>/dev/null)

    if [[ -n "$repo_wt_lines" ]]; then
      repo_summaries+=("${repo_summary}\n${repo_wt_lines}")
    fi
  done

  echo "  ${#repos[@]} repos found ($total_wt worktrees)"
  echo ""

  # Display summaries
  for summary in "${repo_summaries[@]}"; do
    echo -e "$summary"
  done

  if [[ $total_wt -eq 0 ]]; then
    echo "No secondary worktrees found."
    return 0
  fi

  echo "Summary:"
  echo "  $ready_to_remove ready to remove | $needs_resolution need resolution"
  echo ""

  # Phase 2: Resolution for dirty worktrees
  if [[ $needs_resolution -gt 0 ]]; then
    echo "[Entering resolution phase...]"
    echo ""

    local skipped=()

    for main_wt in "${repos[@]}"; do
      local repo_name=$(basename "$main_wt")

      while IFS= read -r wt_line; do
        local wt_path=$(echo "$wt_line" | awk '{print $1}')
        local wt_branch=$(echo "$wt_line" | awk '{print $NF}' | tr -d '[]')

        [[ "$wt_path" == "$main_wt" ]] && continue

        local flags=$(__pds_scan_worktree "$wt_path")
        [[ "$flags" == "clean" ]] && continue

        # Show resolution menu
        local display_path="$wt_path"
        if [[ "$wt_path" == "${main_wt}/.worktrees/"* ]]; then
          display_path=".worktrees/$(basename "$wt_path")"
        fi

        while true; do
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          echo "RESOLVE: $repo_name / $display_path (branch: $wt_branch)"

          if [[ "$flags" == *dirty* ]]; then
            echo "  Uncommitted files:"
            git -C "$wt_path" status --porcelain 2>/dev/null | while read line; do
              echo "    $line"
            done
          fi
          [[ "$flags" == *unpushed* ]] && echo "  Unpushed commits to upstream"
          [[ "$flags" == *no_upstream* ]] && echo "  No upstream branch set"
          [[ "$flags" == *open_pr* ]] && echo "  Open pull request"
          [[ "$flags" == *conflicts* ]] && echo "  Unresolved merge conflicts"
          echo ""
          echo "  [c] Commit and push    [s] Stash changes"
          echo "  [o] Open in tmux       [d] Discard (destructive)"
          echo "  [k] Skip (keep)        [q] Quit"
          echo ""
          read -p "  Choice: " -n 1 -r
          echo ""

          case "$REPLY" in
            c)
              echo "  Committing..."
              git -C "$wt_path" add -A
              git -C "$wt_path" commit -m "wip: end-of-day save"
              if git -C "$wt_path" rev-parse --abbrev-ref '@{upstream}' &>/dev/null; then
                git -C "$wt_path" push
              else
                git -C "$wt_path" push -u origin "$wt_branch" 2>/dev/null || \
                  echo "  ⚠ Push failed — no remote or branch not pushed. Push manually."
              fi
              echo "  ✓ Committed and pushed"
              break
              ;;
            s)
              git -C "$wt_path" stash push -m "eod: $(date +%Y-%m-%d)"
              echo "  ✓ Stashed changes"
              break
              ;;
            o)
              echo "  Opening tmux session... (cleanup pauses until you detach)"
              local normalized="${wt_branch//\//-}"
              normalized="${normalized//./_}"
              local session_name="${repo_name}-${normalized}"
              if ! tmux has-session -t "$session_name" 2>/dev/null; then
                tmux new-session -d -s "$session_name" -c "$wt_path"
              fi
              if [[ -n "$TMUX" ]]; then
                tmux switch-client -t "$session_name"
              else
                tmux attach -t "$session_name"
              fi
              # Re-scan after returning
              flags=$(__pds_scan_worktree "$wt_path")
              [[ "$flags" == "clean" ]] && echo "  ✓ Resolved" && break
              echo "  Still has outstanding work, showing menu again..."
              ;;
            d)
              echo ""
              read -p "  ⚠ This will DISCARD all uncommitted changes. Are you sure? (yes/no) " confirm
              if [[ "$confirm" == "yes" ]]; then
                git -C "$wt_path" checkout -- . 2>/dev/null
                git -C "$wt_path" clean -fd 2>/dev/null
                echo "  ✓ Changes discarded"
                break
              else
                echo "  Cancelled."
              fi
              ;;
            k)
              skipped+=("$repo_name/$display_path ($wt_branch)")
              echo "  Skipped."
              break
              ;;
            q)
              echo ""
              echo "Cleanup aborted."
              return 0
              ;;
            *)
              echo "  Invalid choice. Try again."
              ;;
          esac
        done
        echo ""
      done < <(git -C "$main_wt" worktree list 2>/dev/null)
    done

    if [[ ${#skipped[@]} -gt 0 ]]; then
      echo ""
      echo "⚠ Skipped (still have outstanding work):"
      for s in "${skipped[@]}"; do
        echo "  $s"
      done
      echo ""
    fi
  fi

  # Phase 3: Batch cleanup of clean/merged worktrees + migration
  echo "[Cleaning up merged worktrees...]"
  echo ""

  local total_cleaned=0
  for main_wt in "${repos[@]}"; do
    local repo_name=$(basename "$main_wt")

    # Migrate old siblings first
    __pds_migrate_siblings "$main_wt"

    # Clean up merged worktrees (batch mode — no prompts)
    __pds_repo_cleanup "$main_wt" "batch"
    local repo_cleaned=$?
    ((total_cleaned += repo_cleaned))
  done

  echo ""
  if [[ $total_cleaned -eq 0 ]]; then
    echo "✅ End of day complete. No merged worktrees to remove."
  else
    echo "✅ End of day complete. Cleaned $total_cleaned item(s)."
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

# pds-init - install PDS skills to current project
# Downloads .claude/ config from the repo
# Handles collisions by placing files in .pds-incoming/ for manual merge
function pds-init() {
  local repo_url="https://raw.githubusercontent.com/rmzi/portable-dev-system/main"
  local skills=(bump commit debug design eod ethos quickref reset-tmux review test worktree)
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

  # Add .worktrees/ to .gitignore for worktree containment
  if [[ "$has_collision" != true ]]; then
    local gitignore=".gitignore"
    if ! grep -qx '.worktrees/' "$gitignore" 2>/dev/null; then
      echo '.worktrees/' >> "$gitignore"
      echo "  ✓ Added .worktrees/ to .gitignore"
    fi
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
function pds-machine() {
  local repo_url="https://raw.githubusercontent.com/rmzi/portable-dev-system/main"
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
}

function pds-update() {
  local repo_url="https://raw.githubusercontent.com/rmzi/portable-dev-system/main"

  if [[ "$1" == "--system" ]] || [[ "$1" == "-s" ]]; then
    pds-machine
    return $?
  fi

  # Project update - update .claude/skills/
  local skills=(bump commit debug design eod ethos quickref reset-tmux review test worktree)

  # Check if PDS is installed in this project
  if [[ ! -f ".claude/.pds-version" ]]; then
    echo "❌ PDS not installed in this project."
    echo ""
    echo "Options:"
    echo "  pds-init          - install PDS skills to this project"
    echo "  pds-machine       - update system shell helpers"
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
# Use --git-common-dir to get the true repo name (--show-toplevel returns worktree path)
git_common=$(cd "$(git rev-parse --git-common-dir 2>/dev/null)" 2>/dev/null && pwd)
repo=$(basename "$(dirname "$git_common")" 2>/dev/null || echo "unknown")
branch-tone "$branch" --repo "$repo" --pad --chorus --steps 5 -d 800 -v 0.2
HOOK
      chmod +x "$HOME/.pds/branch-tone-hook.sh"

      # Add Stop and PermissionRequest hooks to Claude settings
      local settings_file="$HOME/.claude/settings.json"
      local hook_cmd="$HOME/.pds/branch-tone-hook.sh"
      local hook_entry='{"hooks":[{"type":"command","command":"'"$hook_cmd"'","async":true}]}'

      if [[ -f "$settings_file" ]]; then
        local tmp_file=$(mktemp)
        local added=()

        # Add hooks that don't already exist
        cp "$settings_file" "$tmp_file"
        for event in Stop PermissionRequest; do
          if jq -e ".hooks.$event" "$tmp_file" &>/dev/null; then
            echo "⚠️  $event hook already exists in settings.json - skipping"
          else
            jq --arg event "$event" --argjson hook "[$hook_entry]" \
              '.hooks = (.hooks // {}) + {($event): $hook}' "$tmp_file" > "${tmp_file}.new" && \
              mv "${tmp_file}.new" "$tmp_file"
            added+=("$event")
          fi
        done

        if [[ ${#added[@]} -gt 0 ]]; then
          mv "$tmp_file" "$settings_file"
          echo "✓ Added hooks to ~/.claude/settings.json: ${added[*]}"
        else
          rm -f "$tmp_file"
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

      # Remove branch-tone hooks from Claude settings
      local settings_file="$HOME/.claude/settings.json"
      if [[ -f "$settings_file" ]] && command -v jq &>/dev/null; then
        local tmp_file=$(mktemp)
        cp "$settings_file" "$tmp_file"
        local removed=false
        for event in Stop PermissionRequest; do
          if jq -e ".hooks.$event" "$tmp_file" &>/dev/null; then
            jq "del(.hooks.$event) | if .hooks == {} then del(.hooks) else . end" "$tmp_file" > "${tmp_file}.new" && \
              mv "${tmp_file}.new" "$tmp_file"
            removed=true
          fi
        done
        if [[ "$removed" == true ]]; then
          mv "$tmp_file" "$settings_file"
          echo "✓ Removed branch-tone hooks from settings.json"
        else
          rm -f "$tmp_file"
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
