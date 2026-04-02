#!/usr/bin/env bash
# efficiency-chart.sh — Value stream visualization for PDS sessions.
# Reads telemetry events, produces color-coded ASCII efficiency charts,
# classifies waste by TPS category, and calculates efficiency ratio (η).
#
# Usage:
#   scripts/efficiency-chart.sh                    # current project telemetry
#   scripts/efficiency-chart.sh --user             # user-level (all sessions)
#   scripts/efficiency-chart.sh --session <id>     # filter to specific session
#   scripts/efficiency-chart.sh --repo <name>      # filter to specific repo
#   scripts/efficiency-chart.sh --last <N>         # last N sessions
#   scripts/efficiency-chart.sh <file>             # custom telemetry file
#
# Framework: Value Stream Mapping (Ohno, 1988)
# Requires: jq

set -euo pipefail

# --- Colors (ANSI) ---
C_VALUE="\033[42m"       # Green background — value-creating
C_WAITING="\033[41m"     # Red — waiting (blocked, idle)
C_TRANSPORT="\033[43m"   # Yellow — transport (context rebuild)
C_OVERPROC="\033[45m"    # Magenta — over-processing (re-reads)
C_DEFECT="\033[101m"     # Bright red — defects (failed validation)
C_MOTION="\033[46m"      # Cyan — motion (permission prompts)
C_RESET="\033[0m"
C_DIM="\033[2m"
C_BOLD="\033[1m"

# --- Parse args ---
TELEMETRY_FILE=".claude/telemetry.jsonl"
SESSION_FILTER=""
REPO_FILTER=""
LAST_N=""
USE_COLOR=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user)
      TELEMETRY_FILE="${HOME}/.claude/telemetry/sessions.jsonl"
      shift ;;
    --session)
      SESSION_FILTER="$2"; shift 2 ;;
    --repo)
      REPO_FILTER="$2"; shift 2 ;;
    --last)
      LAST_N="$2"; shift 2 ;;
    --no-color)
      USE_COLOR=0; shift ;;
    *)
      TELEMETRY_FILE="$1"; shift ;;
  esac
done

if [ ! -f "$TELEMETRY_FILE" ]; then
  echo "No telemetry file at $TELEMETRY_FILE"
  echo "Enable: PDS_TELEMETRY=1"
  echo "User-level: --user flag reads ~/.claude/telemetry/sessions.jsonl"
  exit 1
fi

command -v jq &>/dev/null || { echo "Error: jq required"; exit 1; }

[ "$(wc -l < "$TELEMETRY_FILE" | tr -d ' ')" -eq 0 ] && { echo "Empty telemetry."; exit 0; }

# --- Build jq filter ---
JQ_FILTER='select(.ts != null)'
[ -n "$SESSION_FILTER" ] && JQ_FILTER="$JQ_FILTER | select(.session == \"$SESSION_FILTER\")"
[ -n "$REPO_FILTER" ] && JQ_FILTER="$JQ_FILTER | select(.repo == \"$REPO_FILTER\")"

# Extract events: ts, agent, event, session
EVENTS=$(jq -r "$JQ_FILTER | [.ts, (.agent // \"main\"), (.event // \"unknown\"), (.session // \"unknown\")] | @tsv" "$TELEMETRY_FILE" 2>/dev/null | sort)

[ -z "$EVENTS" ] && { echo "No matching events."; exit 0; }

# If --last N, get the last N unique sessions
if [ -n "$LAST_N" ]; then
  SESSIONS=$(echo "$EVENTS" | awk -F'\t' '{print $4}' | sort -u | tail -n "$LAST_N")
  EVENTS=$(echo "$EVENTS" | awk -F'\t' -v sessions="$SESSIONS" 'BEGIN{split(sessions,s,"\n"); for(i in s) ok[s[i]]=1} ok[$4]')
fi

# --- Classify events by TPS waste category ---
classify_event() {
  local event="$1"
  case "$event" in
    skill_invoked|agent_spawned|file_modified|task_completed)
      echo "value" ;;
    permission_*|denied)
      echo "motion" ;;          # Permission prompt friction
    context_rebuild|file_reread)
      echo "overproc" ;;        # Re-reading already-analyzed files
    validation_failed|test_failed)
      echo "defect" ;;          # Failed validation cycle
    agent_idle|waiting|blocked)
      echo "waiting" ;;         # Blocked on dependency or approval
    context_serialized|context_lost)
      echo "transport" ;;       # Context loss between agents
    *)
      echo "waiting" ;;         # Default: unclassified idle
  esac
}

color_for() {
  [ "$USE_COLOR" -eq 0 ] && return
  case "$1" in
    value)     printf "$C_VALUE" ;;
    waiting)   printf "$C_WAITING" ;;
    transport) printf "$C_TRANSPORT" ;;
    overproc)  printf "$C_OVERPROC" ;;
    defect)    printf "$C_DEFECT" ;;
    motion)    printf "$C_MOTION" ;;
  esac
}

char_for() {
  case "$1" in
    value)     echo "█" ;;
    waiting)   echo "░" ;;
    transport) echo "▒" ;;
    overproc)  echo "▓" ;;
    defect)    echo "✗" ;;
    motion)    echo "·" ;;
  esac
}

# --- Header ---
echo ""
echo "${C_BOLD}## Value Stream Analysis${C_RESET}"
echo "${C_DIM}Framework: Value Stream Mapping (Ohno, 1988)${C_RESET}"
echo ""

FIRST_TS=$(echo "$EVENTS" | head -1 | cut -f1)
LAST_TS=$(echo "$EVENTS" | tail -1 | cut -f1)
TOTAL_EVENTS=$(echo "$EVENTS" | wc -l | tr -d ' ')
UNIQUE_SESSIONS=$(echo "$EVENTS" | awk -F'\t' '{print $4}' | sort -u | wc -l | tr -d ' ')
echo "Time range: $FIRST_TS → $LAST_TS"
echo "Events: $TOTAL_EVENTS across $UNIQUE_SESSIONS session(s)"
echo ""

# --- Legend ---
echo "${C_BOLD}Legend:${C_RESET}"
printf "  $(color_for value)█${C_RESET} Value   "
printf "  $(color_for waiting)░${C_RESET} Waiting   "
printf "  $(color_for transport)▒${C_RESET} Transport   "
printf "  $(color_for overproc)▓${C_RESET} Over-processing   "
printf "  $(color_for defect)✗${C_RESET} Defect   "
printf "  $(color_for motion)·${C_RESET} Motion"
echo ""
echo ""

# --- Per-agent chart ---
AGENTS=$(echo "$EVENTS" | awk -F'\t' '{print $2}' | sort -u)
CHART_WIDTH=50

TOTAL_VALUE=0
TOTAL_ALL=0
declare -A WASTE_COUNTS 2>/dev/null || true
W_WAITING=0; W_TRANSPORT=0; W_OVERPROC=0; W_DEFECT=0; W_MOTION=0

for AGENT in $AGENTS; do
  AGENT_EVENTS=$(echo "$EVENTS" | awk -F'\t' -v a="$AGENT" '$2 == a {print $3}')
  COUNT=$(echo "$AGENT_EVENTS" | wc -l | tr -d ' ')
  [ "$COUNT" -lt 1 ] && continue

  VAL=0; WAIT=0; TRANS=0; OVER=0; DEF=0; MOT=0
  while IFS= read -r evt; do
    cat=$(classify_event "$evt")
    case "$cat" in
      value)     VAL=$((VAL+1)) ;;
      waiting)   WAIT=$((WAIT+1)) ;;
      transport) TRANS=$((TRANS+1)) ;;
      overproc)  OVER=$((OVER+1)) ;;
      defect)    DEF=$((DEF+1)) ;;
      motion)    MOT=$((MOT+1)) ;;
    esac
  done <<< "$AGENT_EVENTS"

  TOTAL_VALUE=$((TOTAL_VALUE+VAL))
  TOTAL_ALL=$((TOTAL_ALL+COUNT))
  W_WAITING=$((W_WAITING+WAIT)); W_TRANSPORT=$((W_TRANSPORT+TRANS))
  W_OVERPROC=$((W_OVERPROC+OVER)); W_DEFECT=$((W_DEFECT+DEF)); W_MOTION=$((W_MOTION+MOT))

  PCT=$(awk "BEGIN { printf \"%.0f\", ($VAL / $COUNT) * 100 }")

  # Build proportional color bar
  printf "${C_BOLD}%-14s${C_RESET} " "$AGENT"
  SCALE=$(awk "BEGIN { printf \"%.4f\", $CHART_WIDTH / $COUNT }")
  V_W=$(awk "BEGIN { v=int($VAL * $SCALE + 0.5); if(v<0)v=0; print v }")
  WA_W=$(awk "BEGIN { v=int($WAIT * $SCALE + 0.5); if(v<0)v=0; print v }")
  TR_W=$(awk "BEGIN { v=int($TRANS * $SCALE + 0.5); if(v<0)v=0; print v }")
  OV_W=$(awk "BEGIN { v=int($OVER * $SCALE + 0.5); if(v<0)v=0; print v }")
  DE_W=$(awk "BEGIN { v=int($DEF * $SCALE + 0.5); if(v<0)v=0; print v }")
  MO_W=$(awk "BEGIN { v=int($MOT * $SCALE + 0.5); if(v<0)v=0; print v }")

  for ((i=0; i<V_W; i++)); do printf "$(color_for value)█${C_RESET}"; done
  for ((i=0; i<WA_W; i++)); do printf "$(color_for waiting)░${C_RESET}"; done
  for ((i=0; i<TR_W; i++)); do printf "$(color_for transport)▒${C_RESET}"; done
  for ((i=0; i<OV_W; i++)); do printf "$(color_for overproc)▓${C_RESET}"; done
  for ((i=0; i<DE_W; i++)); do printf "$(color_for defect)✗${C_RESET}"; done
  for ((i=0; i<MO_W; i++)); do printf "$(color_for motion)·${C_RESET}"; done

  printf " η=%s%%\n" "$PCT"
done

echo ""

# --- Overall ---
if [ "$TOTAL_ALL" -gt 0 ]; then
  OVERALL_PCT=$(awk "BEGIN { printf \"%.0f\", ($TOTAL_VALUE / $TOTAL_ALL) * 100 }")
  echo "${C_BOLD}Overall η = ${OVERALL_PCT}%${C_RESET} ($TOTAL_VALUE value / $TOTAL_ALL total)"
  echo ""
fi

# --- Waste breakdown ---
TOTAL_WASTE=$((W_WAITING + W_TRANSPORT + W_OVERPROC + W_DEFECT + W_MOTION))
if [ "$TOTAL_WASTE" -gt 0 ]; then
  echo "${C_BOLD}Waste Breakdown (TPS Categories):${C_RESET}"
  echo ""
  [ "$W_WAITING"   -gt 0 ] && printf "  $(color_for waiting)░${C_RESET} Waiting        %4d events  (blocked, idle, awaiting assignment)\n" "$W_WAITING"
  [ "$W_TRANSPORT" -gt 0 ] && printf "  $(color_for transport)▒${C_RESET} Transport      %4d events  (context loss between agents)\n" "$W_TRANSPORT"
  [ "$W_OVERPROC"  -gt 0 ] && printf "  $(color_for overproc)▓${C_RESET} Over-processing %3d events  (re-reading analyzed files)\n" "$W_OVERPROC"
  [ "$W_DEFECT"    -gt 0 ] && printf "  $(color_for defect)✗${C_RESET} Defects        %4d events  (failed validation cycles)\n" "$W_DEFECT"
  [ "$W_MOTION"    -gt 0 ] && printf "  $(color_for motion)·${C_RESET} Motion         %4d events  (permission prompts, tool denials)\n" "$W_MOTION"
  echo ""
fi

echo "---"
echo "${C_DIM}Source: $TELEMETRY_FILE${C_RESET}"
echo "${C_DIM}Generated by PDS efficiency-chart.sh | Value Stream Mapping (Ohno, 1988)${C_RESET}"
