#!/usr/bin/env bash
# PDS Secret Guard — PreToolUse hook for Bash commands
# Blocks commands that leak credentials via environment or process inspection.
# Defense-in-depth: complements static deny rules (file paths) with pattern blocks (env access).
#
# Vectors covered:
# 1. Full env dumps: env, printenv, set, export (no args), compgen -v
# 2. Echo/printf of secret vars: echo $AWS_SECRET_ACCESS_KEY, printf "$TOKEN"
# 3. Process environ reads: /proc/*/environ, ps eww
# 4. Curl with inline secrets: curl -H "Authorization: Bearer $TOKEN"
#
# Exit 0 = allow, Exit 2 = block (with stderr message)

set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$COMMAND" ] && exit 0

# --- 1. Full environment dumps ---
if echo "$COMMAND" | grep -qE '^\s*(env|printenv|set)\s*$'; then
  echo '{"error":"BLOCKED: Full environment dump exposes credentials. Use specific variable names instead."}' >&2
  exit 2
fi
if echo "$COMMAND" | grep -qE '^\s*export\s*$|^\s*export\s+-p\s*$'; then
  echo '{"error":"BLOCKED: export -p dumps all exported variables including secrets."}' >&2
  exit 2
fi
if echo "$COMMAND" | grep -qE 'compgen\s+-v|compgen\s+-e'; then
  echo '{"error":"BLOCKED: compgen -v/-e lists all variables including secrets."}' >&2
  exit 2
fi

# --- 2. Echo/printf of secret variable patterns ---
SECRET_PATTERN='(\$\{?)(AWS_SECRET|AWS_ACCESS_KEY|API_KEY|API_SECRET|SECRET_KEY|PRIVATE_KEY|AUTH_TOKEN|ACCESS_TOKEN|REFRESH_TOKEN|DATABASE_URL|DB_PASSWORD|OPENAI_API_KEY|ANTHROPIC_API_KEY|GITHUB_TOKEN|GITLAB_TOKEN|NPM_TOKEN|PYPI_TOKEN|SLACK_TOKEN|STRIPE_SECRET|SENDGRID_API_KEY|TWILIO_AUTH|FIREBASE_.*KEY|GCP_.*KEY|AZURE_.*KEY|PASSWORD|PASSWD|_SECRET|_TOKEN|_CREDENTIAL)'
if echo "$COMMAND" | grep -qE "(echo|printf|cat\s*<<<).*${SECRET_PATTERN}"; then
  echo '{"error":"BLOCKED: Command would print a secret variable to terminal output. Use the variable directly in commands without echoing."}' >&2
  exit 2
fi

# --- 3. Process environment reads ---
if echo "$COMMAND" | grep -qE '/proc/[0-9]+/environ|/proc/self/environ|/proc/\*/environ'; then
  echo '{"error":"BLOCKED: Reading /proc/*/environ exposes all process credentials."}' >&2
  exit 2
fi
if echo "$COMMAND" | grep -qE 'ps\s+.*e.*ww|ps\s+.*ww.*e|ps\s+auxe|ps\s+eww'; then
  echo '{"error":"BLOCKED: ps with e flag exposes process environment variables."}' >&2
  exit 2
fi

# --- 4. Curl/wget with inline secret variables ---
if echo "$COMMAND" | grep -qE "(curl|wget|http).*(-H|--header).*${SECRET_PATTERN}"; then
  echo '{"error":"BLOCKED: HTTP request with inline secret variable. Store credentials in a config file or use a credential helper."}' >&2
  exit 2
fi

exit 0
