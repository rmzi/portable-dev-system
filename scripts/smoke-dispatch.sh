#!/usr/bin/env bash
# PDS — live dispatch smoke test.
#
# WHY THIS EXISTS
#
# Twice now, PDS has shipped a release in which the orchestrator could not
# spawn a single agent — #170 (WorktreeCreate returned no path, so every
# pds:worker spawn died) and #181 (the Task(...) allowlist used bare names
# instead of pds:-namespaced ones, so the spawn roster resolved empty and
# every spawn died). Both passed the full static test suite. Both were
# invisible until a human tried to run a swarm.
#
# Static checks cannot catch this class of bug, because the contract being
# broken is Claude Code's, not PDS's. The only thing that proves dispatch
# works is dispatching. This script does that: it drives a real headless
# orchestrator against a real throwaway git repo and asserts that each agent
# type actually spawns, reading ground truth out of the stream-json tool
# results rather than trusting the model's own summary of what happened.
#
# REQUIREMENTS: network, an authenticated `claude`, and the PDS plugin
# installed and enabled. It cannot run in an offline CI sandbox — see
# `install.sh --test` for the static guards that can.
#
# USAGE
#   scripts/smoke-dispatch.sh            # fast path: researcher + worker
#   scripts/smoke-dispatch.sh --all      # every spawnable agent type
#   scripts/smoke-dispatch.sh pds:scout  # a specific type
#
# EXIT: 0 = every probed type spawned. 1 = at least one failed.

set -uo pipefail

RED=$'\033[1;31m'; GREEN=$'\033[1;32m'; YELLOW=$'\033[1;33m'; BLUE=$'\033[1;34m'; NC=$'\033[0m'

# researcher exercises the plain spawn path; worker exercises the worktree
# path (isolation: worktree). Between them they cover both known failure
# modes, which is why they are the default pair.
FAST_TYPES=(pds:researcher pds:worker)
ALL_TYPES=(pds:researcher pds:worker pds:validator pds:reviewer pds:documenter pds:scout pds:auditor pds:shepherd)

case "${1:-}" in
  --all) TYPES=("${ALL_TYPES[@]}") ;;
  "")    TYPES=("${FAST_TYPES[@]}") ;;
  *)     TYPES=("$@") ;;
esac

command -v claude >/dev/null 2>&1 || { echo "${RED}✗${NC} \`claude\` not on PATH"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "${RED}✗${NC} python3 required"; exit 1; }

# Throwaway git repo. Worker-tier agents need a real repo for worktree
# isolation, and we must never create worktrees inside the repo under test.
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/pds-smoke-dispatch.XXXXXX")"
cleanup() {
  if [ -d "$SANDBOX" ]; then
    git -C "$SANDBOX" worktree prune >/dev/null 2>&1 || true
    rm -rf "$SANDBOX"
  fi
}
trap cleanup EXIT

git init --quiet "$SANDBOX"
git -C "$SANDBOX" config user.email "smoke@pds.local"
git -C "$SANDBOX" config user.name "PDS Smoke"
printf '# smoke\n' > "$SANDBOX/README.md"
git -C "$SANDBOX" add -A
git -C "$SANDBOX" commit --quiet -m "init"

# Reads stream-json off stdin and classifies what actually happened to the
# Agent tool call. Prints exactly one verdict line.
read -r -d '' PARSER <<'PY' || true
import json, sys

spawned = False
failures = []

for line in sys.stdin:
    line = line.strip()
    if not line.startswith("{"):
        continue
    try:
        event = json.loads(line)
    except Exception:
        continue
    if event.get("type") != "user":
        continue
    content = event.get("message", {}).get("content")
    if not isinstance(content, list):
        continue
    for block in content:
        if block.get("type") != "tool_result":
            continue
        text = json.dumps(block.get("content"))
        if "agentId" in text or "launched successfully" in text:
            spawned = True
        elif "not found. Available agents" in text:
            failures.append("AGENT_TYPE_UNRESOLVED (roster empty or name not namespaced — see #181)")
        elif "has been denied by permission rule" in text:
            failures.append("AGENT_TYPE_DENIED (missing from the orchestrator Task(...) allowlist)")
        elif "WorktreeCreate hook failed" in text:
            failures.append("WORKTREE_CREATE_FAILED (hook returned no path — see #170/#182)")
        elif "Subagent nesting limit" in text:
            failures.append("NESTING_LIMIT")

if spawned and not failures:
    print("PASS")
elif failures:
    print("FAIL " + failures[0])
else:
    print("FAIL NO_SPAWN_ATTEMPTED (the orchestrator never called the Agent tool)")
PY

echo ""
echo "${BLUE}>${NC} PDS dispatch smoke test — ${#TYPES[@]} agent type(s)"
echo "${BLUE}>${NC} sandbox repo: $SANDBOX"
echo ""

pass=0
fail=0

for agent_type in "${TYPES[@]}"; do
  printf '  %-18s ' "$agent_type"

  prompt="Spawn exactly one agent and nothing else: Agent(subagent_type='${agent_type}', prompt='Reply with exactly SMOKE_OK. Do not read files, write files, or run commands.', run_in_background=false). Do not run /pds:swarm. Do not create tasks. Do not create a ticket."

  verdict="$(
    cd "$SANDBOX" && claude -p \
      --agent pds:orchestrator \
      --permission-mode bypassPermissions \
      --output-format stream-json \
      --verbose \
      "$prompt" 2>/dev/null | python3 -c "$PARSER"
  )"

  if [ "$verdict" = "PASS" ]; then
    echo "${GREEN}✓ spawned${NC}"
    pass=$((pass + 1))
  else
    echo "${RED}✗ ${verdict#FAIL }${NC}"
    fail=$((fail + 1))
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$fail" -eq 0 ]; then
  echo "  ${GREEN}✓${NC} dispatch healthy — $pass/$((pass + fail)) agent types spawned"
  exit 0
fi

echo "  ${RED}✗${NC} DISPATCH BROKEN — $fail/$((pass + fail)) agent types cannot spawn"
echo ""
echo "  ${YELLOW}Swarms will not run.${NC} Check, in order:"
echo "    1. agents/orchestrator.md — is the Task(...) allowlist pds:-namespaced,"
echo "       and does it name every agent you tried to spawn?"
echo "    2. hooks/scripts/sync-worktree-permissions.sh — does it print the"
echo "       created worktree's absolute path to stdout?"
echo "    3. Is the installed plugin actually current? A stale"
echo "       ~/.claude/plugins/cache/ copy will mask a fixed repo."
exit 1
