# ADR 0001: Hooks Enforcement for Skills

## Status
Proposed

## Context

PDS skills are currently enforced by convention — agents are instructed to read and follow skills, but nothing mechanically prevents them from skipping steps or ignoring protocols. Issue #77 asks whether PreToolUse/PostToolUse hooks can enforce skill behaviors automatically.

### Current Hook Infrastructure

PDS already uses several hook types:

| Hook | Location | Purpose |
|------|----------|---------|
| SessionStart | hooks.json | Run session-start.sh for initialization |
| PermissionRequest | hooks.json | LLM-as-judge prompt for permission routing |
| Stop | hooks.json | Verify agent completed work before stopping |
| TaskCompleted | hooks.json | Gate task completion quality |
| TeammateIdle | hooks.json | Monitor idle teammates |
| WorktreeCreate | hooks.json | Log worktree lifecycle events |
| InstructionsLoaded | hooks.json | Audit log entry |
| PreToolUse (Bash) | orchestrator.md | PR gate — blocks `gh pr create` unless phase requirements met |
| PreToolUse (TeamDelete) | orchestrator.md | Teardown gate — blocks cleanup unless reports exist |
| PostToolUse (Write/Edit) | worker.md | Post-write checks on worker output |
| Stop | validator.md | Verify validation report completeness |

### Hook Types Available

- **command hooks**: Run a shell script, get stdout. Can block (`{"ok": false, "reason": "..."}`) or allow (`{"ok": true}`).
- **prompt hooks**: LLM evaluates context and responds with JSON. More flexible but more expensive.

## Decision

### Which skill behaviors could be enforced via hooks

| Skill | Enforceable Behavior | Hook Type | Trade-off |
|-------|---------------------|-----------|-----------|
| /grill | Block Write/Edit before grill outputs exist | PreToolUse (Write/Edit) | Could prevent legitimate quick fixes. Need a "grill bypass" flag for trivial tasks. |
| /verify | Block TaskUpdate(completed) unless verify checklist items exist | PreToolUse (TaskUpdate) | Already partially handled by TaskCompleted hook. Tightening would require structured verify output. |
| /rebase | Block `git push` after rebase if conflicts detected | PreToolUse (Bash) | Pattern matching on `git push` is fragile. Better as agent instruction. |
| /preflight | Run automatically on SessionStart | SessionStart | Low cost, high value. Could append preflight output to session-start.sh. |
| /contribute | Block skill/agent file edits unless whitepaper was read | PostToolUse (Write/Edit) | Would need to track "whitepaper read" state. Fragile. |
| /bugfix | Block test file modification during bugfix loop | PreToolUse (Edit) | Context-dependent — would need to know "bugfix mode" is active. |

### Recommended enforcement approach

**Tier 1 — Implement now (mechanical, low risk):**
- Preflight on SessionStart: Extend session-start.sh to run environment checks.
- TaskCompleted gate: Already exists. Tighten to verify acceptance criteria are listed in task completion message.

**Tier 2 — Implement with care (valuable but context-dependent):**
- Grill gate: PreToolUse on Write/Edit that checks for `.claude/swarm/grill-output.md` when in swarm mode. Only active during swarm phases 1-2.
- Verify gate: Strengthen the existing Stop hook to check for structured verify output format.

**Tier 3 — Keep as convention (enforcement cost exceeds benefit):**
- Bugfix test-modification prevention: Too context-dependent for a mechanical hook.
- Contribute whitepaper-read check: Tracking "was the whitepaper read?" requires session state the hook can't access.
- Rebase conflict detection: Better handled by the agent following the skill protocol.

### Design proposal for Tier 1 and 2

```
# Tier 1: Preflight on SessionStart (extend session-start.sh)
# Add to the end of session-start.sh:
echo "[PDS] Running preflight checks..."
# Git status
git status --porcelain | head -5
# Dependency check
test -d node_modules 2>/dev/null || test -d .venv 2>/dev/null || echo "[PDS] No dependencies detected"

# Tier 2: Grill gate (new PreToolUse hook for workers in swarm mode)
# In worker.md hooks section:
PreToolUse:
  - matcher: "Write|Edit"
    hooks:
      - type: command
        command: "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/grill-gate.sh"
        timeout: 5
# grill-gate.sh checks: if .claude/swarm/phase exists AND equals "plan"
# then block writes. Otherwise allow.
```

## Consequences

### Positive
- Mechanical enforcement prevents skill protocol violations
- Reduces reliance on agent compliance (defense-in-depth)
- Hook infrastructure already exists — no new mechanisms needed

### Negative
- Over-enforcement reduces agent flexibility for legitimate edge cases
- Prompt-based hooks add latency and cost per tool call
- False positives can block valid work and frustrate users
- Hook state management is limited — no session-level state tracking

### Recommendation
Start with Tier 1 (low risk, high value). Evaluate Tier 2 after collecting data on how often agents skip grill/verify in practice. Keep Tier 3 as convention — the enforcement cost exceeds the compliance benefit.
