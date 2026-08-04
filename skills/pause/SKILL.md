---
description: Save session state and pause gracefully. Use when stopping work mid-session to preserve context for later resumption.
---
# /pause — Session Pause

Save-state operation. Commits any in-progress work and records session context so the next session can resume cleanly.

## Invocation

```
/pds:pause                              # Auto-generate note from recent git log
/pds:pause "finished auth, next: tests" # Explicit note about where you left off
```

## Protocol

### 1. Check Working Tree

```bash
git status --short
```

### 2. Commit Uncommitted Changes (if any)

If there are uncommitted changes (staged or unstaged):

```bash
git add <relevant files>   # Be deliberate — not -A
git commit -m "wip: pausing session $(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

If the working tree is clean, skip — do not create an empty commit.

### 3. Save State to `.claude/swarm/pause.json`

Write the following JSON:

```json
{
  "timestamp": "<ISO 8601>",
  "branch": "<current branch>",
  "phase": "<contents of .claude/swarm/phase, or 'none'>",
  "tier": "<contents of .claude/swarm/tier, or 'none'>",
  "uncommitted_files": <count before commit, 0 if clean>,
  "note": "<user-provided string, or summary from recent git log>"
}
```

Read `.claude/swarm/phase` and `.claude/swarm/tier` if they exist; use `"none"` if missing.

For auto-generated notes, use: `git log --oneline -3` — summarize what was recently worked on.

### 4. Check for Active Swarm Agents

If `.claude/swarm/phase` exists and is not empty, print:

```
Note: a swarm may be active. Consider shutting down agents before closing the session.
```

Do not force-stop agents — just surface the suggestion.

### 5. Post pause note to the ticket (if one exists)

Read `.claude/swarm/ticket`. If its content matches `^[0-9]+$` (a real issue number, not a fallback marker — see `/pds:ticket` section 2), post the pause state as a comment:

```bash
gh issue comment <ticket-num> --body "$(cat <<'EOF'
Paused. Branch: <branch>. Phase: <phase>. Tier: <tier>.
<note>
EOF
)"
```

This is what makes the pause portable across machines and people — `/pds:resume` reads this comment thread when no local `.claude/swarm/` state is available. If the ticket file is missing or holds a fallback marker, skip this step silently — no ticket, no comment, no error.

### 6. Print Confirmation

```
Session paused. State saved to .claude/swarm/pause.json. Resume with /pds:resume.
```

## Rules

- Never create an empty commit on a clean working tree.
- Stage files deliberately — no `git add -A`.
- The pause.json write is the only required side effect on a clean tree.
- The ticket comment (step 5) is best-effort — never block the pause on `gh` failing or being unavailable.
- This is a save-state operation, not a workflow — keep it fast and simple.

## See Also

- `/pds:resume` — Reconstructs swarm state from local checkpoint, ticket comment thread, or archived swarm report.
- `/pds:ticket` — Owns the ticket file and comment conventions this skill reuses.
