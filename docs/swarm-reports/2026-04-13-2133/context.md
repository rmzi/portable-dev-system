# Swarm Context: crush-issues

## Plan Summary

Crushing 5 open GitHub issues for `rmzi/portable-dev-system` in a single heavy swarm on the `crush-issues` branch. The repo is a Claude Code plugin providing skills, agents, hooks, and an installer.

## Work Units

1. **worker-health** (Issue #128): Fix cumulative session timer in `hooks/scripts/health-check.sh` by resetting the marker file in `hooks/scripts/session-start.sh`.
2. **worker-sandbox** (Issue #132): Add tmux socket path `/private/tmp/tmux-*/` to sandbox write allowlist in `.claude/settings.json`.
3. **worker-prune** (Issue #131 Phase 1): Delete 11 deprecated/thin skill directories, move ethos to `docs/ethos.md`, update CLAUDE.md skill table and count, update session-start.sh context string.
4. **worker-consolidate** (Issue #131 Phase 2): Fold `/merge` into `/swarm`, `/dispatch` into `/team`, `/bcp` into `/finish`. Update CLAUDE.md, agent defs, session-start.sh.
5. **worker-hooks** (Issue #131 Phase 3): Verify hook wiring completeness. `secret-guard.sh` is ALREADY wired in hooks.json. Handle `status-line.sh` (already wired via settings.json statusLine), handle `secret-scrub.EVAL.md`, audit all scripts.
6. **worker-agents** (Issue #131 cleanup): Update agent definitions after prune+consolidate. BLOCKED by workers 3 and 4.
7. **documenter** (Issue #117): Draft `docs/human-factors.md` on human factors in AI development.

## Key Files

- `CLAUDE.md` — Project instructions, skill table (28 skills listed)
- `hooks/hooks.json` — Hook wiring config (all current hooks)
- `hooks/scripts/session-start.sh` — SessionStart hook, line 96 has CONTEXT string
- `hooks/scripts/health-check.sh` — UserPromptSubmit hook with timer bug
- `.claude/settings.json` — Sandbox config, permissions, status line
- `.claude-plugin/plugin.json` — Plugin manifest (version 4.14.0)
- `agents/*.md` — 8 agent definitions + shared-rules.md
- `skills/` — 28 skill directories

## Research Findings

### Health check bug (Issue #128)
- `health-check.sh:13` uses `$TMPDIR/pds-session-start` as marker
- `health-check.sh:17-19` creates marker on first invocation
- `session-start.sh` NEVER resets this marker, so `$TMPDIR` persistence across macOS sessions causes inflated timers
- Fix: Add `rm -f "${TMPDIR:-/tmp}/pds-session-start"` early in `session-start.sh`

### Sandbox/tmux (Issue #132)
- `.claude/settings.json` has `sandbox.network.allowAllUnixSockets: false`
- No filesystem write allowlist for `/private/tmp/tmux-*/`
- The settings.json sandbox section controls OS-level sandbox behavior
- Need to add tmux socket path to sandbox write allowlist

### Hook wiring status
- `secret-guard.sh` — ALREADY wired as PreToolUse > Bash (hooks.json:58-64)
- `status-line.sh` — ALREADY wired via settings.json statusLine command (line 168)
- `secret-scrub.EVAL.md` — Eval metadata, not a hook. Should move to `docs/` or delete.
- All other scripts in `hooks/scripts/` are accounted for in hooks.json

### Skills to prune (11 total)
Directories to delete: `permission-router`, `telemetry`, `inspect`, `instinct`, `trim`, `export`, `allow`, `sandbox`, `audit-config`, `preflight`, `ethos`

### Skills to consolidate (3 fold-ins)
- `/merge` content -> `/swarm` Phase 5 section
- `/dispatch` content -> `/team` agent definitions
- `/bcp` content -> `/finish` as quick-ship mode

### Agent skill references (current state)
- `worker.md`: skills `pds:bugfix`, `pds:verify`
- `orchestrator.md`: skills `pds:team`, `pds:worktree`, `pds:swarm`, `pds:finish`
- `validator.md`: skills `pds:verify`, `pds:merge` (merge being folded into swarm)
- `reviewer.md`: skills `pds:verify`
- `researcher.md`: skills `pds:grill`
- `documenter.md`: skills `pds:finish`
- `scout.md`: skills `pds:ethos`, `pds:instinct`, `pds:trim`, `pds:eval`, `pds:telemetry` (ethos/instinct/trim/telemetry being pruned)
- `auditor.md`: skills `pds:audit-config` (audit-config being pruned)

## Key Decisions

1. Workers 1 (health), 2 (sandbox), and 7 (documenter) are independent — dispatch immediately.
2. Workers 3 (prune) and 4 (consolidate) edit overlapping files (CLAUDE.md, session-start.sh) — they need worktree isolation.
3. Worker 5 (hooks) is independent of 3/4 — can run in parallel, but hooks.json editing is isolated.
4. Worker 6 (agents) is BLOCKED by workers 3 and 4 completing — must wait.
5. `secret-guard.sh` is already wired — worker 5 needs to verify this and focus on completeness audit.
6. `status-line.sh` is wired via settings.json, not hooks.json — it is accounted for.

## Acceptance Criteria

See individual task descriptions for mechanically verifiable checklists.
