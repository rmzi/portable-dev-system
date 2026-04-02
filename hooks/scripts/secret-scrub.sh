#!/usr/bin/env bash
# PDS Secret Scrub — PreToolUse hook for Bash
# Rewrites sensitive commands to pipe output through a sed secret scrubber.
# Philosophy: scrub don't block — commands run normally, secrets become [REDACTED].

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$COMMAND" ] && exit 0

# Heuristic: only scrub commands likely to expose secret values in their output
is_sensitive() {
  local cmd="$1"
  # env/printenv commands
  echo "$cmd" | grep -qE '\b(env|printenv)\b' && return 0
  # export -p
  echo "$cmd" | grep -qE '\bexport\s+-p\b' && return 0
  # cat .env files
  echo "$cmd" | grep -qE '\bcat\b.+\.env\b' && return 0
  # network tools (may receive auth tokens in responses)
  echo "$cmd" | grep -qE '\b(curl|wget)\b' && return 0
  # known credential paths
  echo "$cmd" | grep -qF '/.aws' && return 0
  echo "$cmd" | grep -qF '/.ssh' && return 0
  echo "$cmd" | grep -qF '/.netrc' && return 0
  echo "$cmd" | grep -qF '/.npmrc' && return 0
  echo "$cmd" | grep -qF '/.pypirc' && return 0
  echo "$cmd" | grep -qF '/.git-credentials' && return 0
  echo "$cmd" | grep -qF '/.config/gcloud' && return 0
  echo "$cmd" | grep -qF '/.config/gh' && return 0
  # echo/printf of secret variable patterns
  echo "$cmd" | grep -qE '(echo|printf)\s+.*\$\{?(SECRET|TOKEN|KEY|PASSWORD|API_KEY|ACCESS_KEY|CREDENTIAL)' && return 0
  return 1
}

! is_sensitive "$COMMAND" && exit 0

# Build sed scrubbing args — each pattern as a separate -e flag
# These become part of the rewritten command string (not executed here)
SED_ARGS="-E"
SED_ARGS="$SED_ARGS -e 's/sk-[a-zA-Z0-9]{20,}/[REDACTED]/g'"
SED_ARGS="$SED_ARGS -e 's/ghp_[a-zA-Z0-9]{36}/[REDACTED]/g'"
SED_ARGS="$SED_ARGS -e 's/gho_[a-zA-Z0-9]{36}/[REDACTED]/g'"
SED_ARGS="$SED_ARGS -e 's/github_pat_[a-zA-Z0-9_]{82}/[REDACTED]/g'"
SED_ARGS="$SED_ARGS -e 's/AKIA[A-Z0-9]{16}/[REDACTED]/g'"
SED_ARGS="$SED_ARGS -e 's/xoxb-[a-zA-Z0-9-]+/[REDACTED]/g'"
SED_ARGS="$SED_ARGS -e 's/xoxp-[a-zA-Z0-9-]+/[REDACTED]/g'"
SED_ARGS="$SED_ARGS -e 's/eyJ[a-zA-Z0-9_-]+\\.eyJ[a-zA-Z0-9_-]+/[REDACTED]/g'"
SED_ARGS="$SED_ARGS -e 's/SG\\.[a-zA-Z0-9_-]+/[REDACTED]/g'"
SED_ARGS="$SED_ARGS -e 's/sk_live_[a-zA-Z0-9]+/[REDACTED]/g'"
SED_ARGS="$SED_ARGS -e 's/rk_live_[a-zA-Z0-9]+/[REDACTED]/g'"
SED_ARGS="$SED_ARGS -e 's/^([A-Z_]*(SECRET|TOKEN|KEY|PASSWORD|CREDENTIAL)[A-Z_]*=).+$/\\1[REDACTED]/'"

# Wrap original command in a subshell to safely handle existing pipes, redirects,
# and multi-line commands. 2>&1 ensures stderr (e.g. auth error messages) is also scrubbed.
REWRITTEN="( ${COMMAND} 2>&1 ) | sed ${SED_ARGS}"

# Telemetry — encrypted if age is available, metadata-only otherwise
log_scrub() {
  local cmd="$1"
  local ts cmd_name
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  cmd_name=$(echo "$cmd" | awk '{print $1}')
  local pds_dir="$HOME/.config/pds"
  mkdir -p "$pds_dir" 2>/dev/null || true
  [ -d "$pds_dir" ] || return 0

  if command -v age >/dev/null 2>&1; then
    local key_file="$pds_dir/scrub.key"
    if [ ! -f "$key_file" ]; then
      age-keygen -o "$key_file" 2>/dev/null || true
    fi
    if [ -f "$key_file" ]; then
      local pub
      pub=$(grep '^# public key:' "$key_file" | awk '{print $NF}' 2>/dev/null || true)
      if [ -n "$pub" ]; then
        printf '{"ts":"%s","command":%s,"session":"%s"}\n' \
          "$ts" \
          "$(printf '%s' "$cmd" | jq -Rs '.')" \
          "${CLAUDE_SESSION_ID:-unknown}" \
          | age -r "$pub" -a >> "$pds_dir/scrub-telemetry.age" 2>/dev/null || true
      fi
    fi
  fi

  # Always log metadata (no secrets — command name only)
  printf '{"ts":"%s","cmd":"%s","session":"%s"}\n' \
    "$ts" "$cmd_name" "${CLAUDE_SESSION_ID:-unknown}" \
    >> "$pds_dir/scrub-telemetry.jsonl"
}

log_scrub "$COMMAND"

# Return rewritten command — Claude Code will execute this instead of the original
jq -n --arg cmd "$REWRITTEN" \
  '{"hookSpecificOutput":{"hookEventName":"PreToolUse","updatedInput":{"command":$cmd}}}'
