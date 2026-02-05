#!/bin/bash
# =============================================================================
# Portable Dev System - Claude Status Line
# Red accent for Claude context
# =============================================================================

# Red color palette for branch variation
# Muted reds: 131 (af5f5f), 167 (d75f5f), 174 (d78787), 138 (af8787)
RED_COLORS=("131" "167" "174" "138" "95" "130")

input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
cd "$cwd" 2>/dev/null || exit 0

# Get branch for color hashing
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")

# Hash branch name to pick red variant
hash=$(printf "%s" "$branch" | cksum | cut -d" " -f1)
color_idx=$((hash % ${#RED_COLORS[@]}))
red_code="${RED_COLORS[$color_idx]}"

# ANSI codes for our red accent
RED="\033[38;5;${red_code}m"
BOLD_RED="\033[1;38;5;${red_code}m"
RESET="\033[0m"
DIM="\033[2m"
BOLD="\033[1m"

# Red indicator for Claude context
printf "${BOLD_RED}◆${RESET} "

# Directory (abbreviated)
dir=$(echo "$cwd" | awk -F'/' '{n=NF; if(n<=3) print $0; else print "~/" $(n-2) "/" $(n-1) "/" $n}' | sed 's|^/Users/rmzi|~|')
printf "${DIM}%s${RESET}" "$dir"

# Git info
if git rev-parse --git-dir >/dev/null 2>&1; then
    printf " on ${BOLD_RED}%s${RESET}" "$branch"

    # Git status
    untracked=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
    modified=$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')
    staged=$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')

    status=""
    upstream=$(git rev-parse --abbrev-ref @{upstream} 2>/dev/null)
    if [ -n "$upstream" ]; then
        ahead=$(git rev-list --count @{upstream}..HEAD 2>/dev/null || echo 0)
        behind=$(git rev-list --count HEAD..@{upstream} 2>/dev/null || echo 0)
        [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ] && status+="⇕⇡${ahead}⇣${behind}"
        [ "$ahead" -gt 0 ] && [ "$behind" -eq 0 ] && status+="⇡${ahead}"
        [ "$behind" -gt 0 ] && [ "$ahead" -eq 0 ] && status+="⇣${behind}"
    fi
    [ "$untracked" -gt 0 ] && status+="?${untracked}"
    [ "$modified" -gt 0 ] && status+="!${modified}"
    [ "$staged" -gt 0 ] && status+="+${staged}"

    [ -n "$status" ] && printf " ${RED}%s${RESET}" "$status"
fi

# Context window remaining
remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
if [ -n "$remaining" ]; then
    if [ "$(echo "$remaining < 20" | bc -l 2>/dev/null || echo 0)" -eq 1 ]; then
        ctx_color="\033[1;31m"
    elif [ "$(echo "$remaining < 50" | bc -l 2>/dev/null || echo 0)" -eq 1 ]; then
        ctx_color="\033[1;33m"
    else
        ctx_color="${DIM}"
    fi
    printf " ${ctx_color}ctx:%.0f%%${RESET}" "$remaining"
fi
