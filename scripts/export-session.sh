#!/usr/bin/env bash
# export-session.sh — Export a Claude Code session JSONL to human-readable markdown.
#
# Usage:
#   scripts/export-session.sh                           # current/latest session
#   scripts/export-session.sh <session-id>              # specific session
#   scripts/export-session.sh --list                    # list available sessions
#   scripts/export-session.sh <session-id> -o out.md    # write to file
#
# Reads from ~/.claude/projects/<project-hash>/<session-id>.jsonl
# Produces readable markdown with 👤 Human / 🔵 Claude / 🤖 Agent / ⚙️ System roles.
#
# Requires: python3, jq (optional, for --list)

set -euo pipefail

# Find project dir — hash of CWD
PROJECT_DIR=""
for d in ~/.claude/projects/*/; do
  # Check if any session files exist
  if ls "$d"*.jsonl &>/dev/null 2>&1; then
    PROJECT_DIR="$d"
  fi
done

# Try CWD-based project dir
CWD_HASH=$(echo -n "$(pwd)" | tr '/' '-')
if [ -d "$HOME/.claude/projects/$CWD_HASH" ]; then
  PROJECT_DIR="$HOME/.claude/projects/$CWD_HASH"
fi

# Also try with leading dash
if [ -d "$HOME/.claude/projects/-${CWD_HASH}" ]; then
  PROJECT_DIR="$HOME/.claude/projects/-${CWD_HASH}"
fi

if [ -z "$PROJECT_DIR" ]; then
  echo "No session files found for this project."
  exit 1
fi

# Parse args
SESSION_ID=""
OUTPUT=""
LIST_MODE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --list|-l)
      LIST_MODE=true; shift ;;
    -o|--output)
      OUTPUT="$2"; shift 2 ;;
    *)
      SESSION_ID="$1"; shift ;;
  esac
done

# List mode
if [ "$LIST_MODE" = true ]; then
  echo "Available sessions in $PROJECT_DIR:"
  echo ""
  for f in "$PROJECT_DIR"*.jsonl; do
    [ -f "$f" ] || continue
    sid=$(basename "$f" .jsonl)
    size=$(wc -c < "$f" | tr -d ' ')
    lines=$(wc -l < "$f" | tr -d ' ')
    mod=$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$f" 2>/dev/null || stat -c '%y' "$f" 2>/dev/null | cut -d. -f1)
    size_h=$(awk "BEGIN { printf \"%.1f KB\", $size/1024 }")
    echo "  $sid  ($lines msgs, $size_h, $mod)"
  done
  exit 0
fi

# Canonical resolution path: caller (SessionEnd hook, /pds:finish) hands us the
# JSONL path directly via TRANSCRIPT_PATH env var. Skips CWD-hash heuristic entirely.
if [ -n "${TRANSCRIPT_PATH:-}" ] && [ -f "$TRANSCRIPT_PATH" ]; then
  SESSION_FILE="$TRANSCRIPT_PATH"
# Find session file
elif [ -z "$SESSION_ID" ]; then
  # Latest session by modification time
  SESSION_FILE=$(ls -t "$PROJECT_DIR"*.jsonl 2>/dev/null | head -1)
  if [ -z "$SESSION_FILE" ]; then
    echo "No session files found."
    exit 1
  fi
else
  SESSION_FILE="$PROJECT_DIR${SESSION_ID}.jsonl"
  if [ ! -f "$SESSION_FILE" ]; then
    echo "Session not found: $SESSION_FILE"
    echo "Use --list to see available sessions."
    exit 1
  fi
fi

SESSION_ID=$(basename "$SESSION_FILE" .jsonl)
FILTER_BRANCH="${FILTER_BRANCH:-}"

# Convert JSONL to markdown
python3 << 'PYEOF' - "$SESSION_FILE" "$SESSION_ID" "$FILTER_BRANCH"
import json, sys, re
from datetime import datetime

session_file = sys.argv[1]
session_id = sys.argv[2]
filter_branch = sys.argv[3] if len(sys.argv) > 3 else ''

with open(session_file) as f:
    lines = [json.loads(l.strip()) for l in f]

# Optional: filter to entries recorded on a specific branch.
# Entries without gitBranch (e.g. system messages) pass through.
if filter_branch:
    lines = [l for l in lines if not l.get('gitBranch') or l.get('gitBranch') == filter_branch]

out = []

# Find session date from first timestamp
session_date = "unknown"
for entry in lines:
    ts = entry.get('timestamp', '')
    if ts:
        try:
            dt = datetime.fromisoformat(ts.replace('Z', '+00:00'))
            session_date = dt.strftime('%Y-%m-%d')
        except:
            pass
        break

out.append(f"# Session — {session_date}")
out.append("")
out.append(f"> **Session ID**: `{session_id}`")
out.append("")
out.append("---")
out.append("")

def extract_text(content):
    if isinstance(content, str):
        return content.strip()
    if isinstance(content, list):
        parts = []
        for block in content:
            if block.get('type') == 'text':
                parts.append(block['text'].strip())
        return '\n\n'.join(parts)
    return ''

def extract_tools(content):
    if not isinstance(content, list):
        return []
    tools = []
    for block in content:
        if block.get('type') == 'tool_use':
            name = block.get('name', '?')
            inp = block.get('input', {})
            if name in ('Read', 'Glob', 'Grep'):
                detail = inp.get('file_path', inp.get('pattern', inp.get('path', '')))
                if detail and len(detail) > 60:
                    detail = '...' + detail[-57:]
                tools.append(f"`{name}({detail})`")
            elif name == 'Bash':
                cmd = inp.get('command', '')
                if len(cmd) > 80:
                    cmd = cmd[:77] + '...'
                tools.append(f"`$ {cmd}`")
            elif name == 'Edit':
                fp = inp.get('file_path', '').split('/')[-1]
                tools.append(f"`Edit({fp})`")
            elif name == 'Write':
                fp = inp.get('file_path', '').split('/')[-1]
                tools.append(f"`Write({fp})`")
            elif name == 'Agent':
                desc = inp.get('description', '')
                at = inp.get('subagent_type', '')
                tools.append(f"`Agent({at or 'general'}: {desc})`")
            elif name == 'SendMessage':
                to = inp.get('to', '')
                summ = inp.get('summary', '')[:40]
                tools.append(f"`SendMessage({to}: {summ})`")
            elif name == 'Skill':
                tools.append(f"`/{inp.get('skill', '')}`")
            elif name == 'WebSearch':
                q = inp.get('query', '')[:50]
                tools.append(f"`WebSearch: {q}`")
            elif name == 'WebFetch':
                url = inp.get('url', '')
                url = re.sub(r'https://github.com/', '', url)
                if len(url) > 60:
                    url = url[:57] + '...'
                tools.append(f"`WebFetch({url})`")
            elif name in ('TaskUpdate', 'TaskList', 'TaskCreate', 'TaskGet'):
                tools.append(f"`{name}`")
            elif name in ('EnterPlanMode', 'ExitPlanMode'):
                tools.append(f"`{name}`")
            elif name == 'ToolSearch':
                tools.append("`ToolSearch`")
            else:
                tools.append(f"`{name}`")
    return tools

def format_ts(ts):
    try:
        dt = datetime.fromisoformat(ts.replace('Z', '+00:00'))
        return dt.strftime('%H:%M UTC')
    except:
        return ''

for entry in lines:
    etype = entry.get('type')
    subtype = entry.get('subtype', '')
    ts = entry.get('timestamp', '')
    time_str = format_ts(ts) if ts else ''

    if etype in ('permission-mode', 'custom-title', 'agent-name', 'last-prompt',
                 'file-history-snapshot', 'queue-operation', 'attachment'):
        continue
    if etype == 'system' and subtype in ('turn_duration', 'stop_hook_summary'):
        continue

    if etype == 'user':
        content = entry.get('message', {}).get('content', '')
        text = extract_text(content)
        if not text:
            continue

        text = re.sub(r'<system-reminder>.*?</system-reminder>', '', text, flags=re.DOTALL)
        teammate_msgs = re.findall(r'<teammate-message[^>]*summary="([^"]*)"[^>]*>', text)
        text = re.sub(r'<teammate-message[^>]*>.*?</teammate-message>', '', text, flags=re.DOTALL)
        text = re.sub(r'<local-command-caveat>.*?</local-command-caveat>', '', text, flags=re.DOTALL)

        cmd_match = re.search(r'<command-name>(.*?)</command-name>', text)
        text = re.sub(r'<command-name>.*?</command-name>', '', text, flags=re.DOTALL)
        text = re.sub(r'<command-message>.*?</command-message>', '', text, flags=re.DOTALL)
        text = re.sub(r'<command-args>.*?</command-args>', '', text, flags=re.DOTALL)
        stdout_match = re.search(r'<local-command-stdout>(.*?)</local-command-stdout>', text, re.DOTALL)
        text = re.sub(r'<local-command-stdout>.*?</local-command-stdout>', '', text, flags=re.DOTALL)
        text = re.sub(r'<bash-input>.*?</bash-input>', '', text, flags=re.DOTALL)
        text = re.sub(r'<bash-stdout>.*?</bash-stdout>', '', text, flags=re.DOTALL)
        text = re.sub(r'<bash-stderr>.*?</bash-stderr>', '', text, flags=re.DOTALL)
        text = text.strip()

        if teammate_msgs:
            for tm in teammate_msgs:
                out.append(f"**🤖 Agent** _{time_str}_: {tm}")
                out.append("")

        if cmd_match:
            cmd = cmd_match.group(1)
            result = stdout_match.group(1).strip()[:200] if stdout_match else ''
            out.append(f"**👤 Human** _{time_str}_ — `/{cmd}`")
            if result:
                out.append(f"> {result}")
            out.append("")
            if text:
                out.append(text)
                out.append("")
        elif text:
            out.append(f"**👤 Human** _{time_str}_")
            out.append("")
            out.append(text)
            out.append("")

    elif etype == 'assistant':
        content = entry.get('message', {}).get('content', [])
        text = extract_text(content)
        tools = extract_tools(content)

        if not text and not tools:
            continue

        out.append(f"**🔵 Claude** _{time_str}_")
        out.append("")
        if text:
            out.append(text)
            out.append("")
        if tools:
            out.append("📎 " + ' · '.join(tools))
            out.append("")

    elif etype == 'system' and subtype == 'local_command':
        content = entry.get('content', '')
        cmd_match = re.search(r'<command-name>(.*?)</command-name>', content)
        stdout_match = re.search(r'<local-command-stdout>(.*?)</local-command-stdout>', content, re.DOTALL)
        bash_input = re.search(r'<bash-input>(.*?)</bash-input>', content)
        bash_stdout = re.search(r'<bash-stdout>(.*?)</bash-stdout>', content, re.DOTALL)

        if cmd_match:
            cmd = cmd_match.group(1)
            result = stdout_match.group(1).strip()[:200] if stdout_match else ''
            out.append(f"**⚙️ System** `/{cmd}`" + (f" → {result}" if result else ""))
            out.append("")
        elif bash_input:
            cmd = bash_input.group(1).strip()
            result = bash_stdout.group(1).strip()[:200] if bash_stdout else ''
            out.append(f"**⚙️ Shell** `{cmd}`")
            if result:
                out.append("```")
                out.append(result)
                out.append("```")
            out.append("")

out.append("---")
out.append("")
user_count = sum(1 for l in lines if l.get('type') == 'user')
asst_count = sum(1 for l in lines if l.get('type') == 'assistant')
out.append(f"**Session stats:** {len(lines)} messages · {user_count} human · {asst_count} assistant")

result = '\n'.join(out)
result = re.sub(r'\n{4,}', '\n\n', result)
print(result)
PYEOF
