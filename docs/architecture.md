# PDS Plugin Architecture

Structural reference for the Portable Development System. Maps files to runtime behavior.

For philosophy, see `philosophy.md`. For the swarm workflow, see `/pds:swarm`. For agent roles, see `/pds:team`. This doc covers **how the pieces wire together**.

## Plugin Layout

```
pds/
├── .claude-plugin/
│   └── plugin.json              # {name, version, description, repository}
├── .claude/
│   └── settings.json            # Merged into user/project settings at install
├── hooks/
│   ├── hooks.json               # Event → script registry
│   └── scripts/                 # Shell scripts that hooks execute
├── agents/
│   ├── shared-rules.md          # Behavioral rules inherited by all agents
│   ├── orchestrator.md          # Team lead (opus, 100 turns)
│   ├── worker.md                # Implementation (sonnet, 50 turns)
│   ├── validator.md             # Merge + test (sonnet, 40 turns)
│   ├── researcher.md            # Codebase exploration (sonnet, 30 turns)
│   ├── reviewer.md              # Code review (sonnet, 25 turns)
│   ├── documenter.md            # Documentation (sonnet, 30 turns)
│   ├── scout.md                 # Meta-improvement (haiku, 15 turns)
│   └── auditor.md               # Tech debt scan (sonnet, 30 turns)
├── skills/
│   └── <name>/SKILL.md          # 28 skills, each a /pds:<name> command
├── scripts/                     # Utility scripts (eval, telemetry, export)
├── docs/                        # This file and others
└── install.sh                   # Plugin + project installer
```

Claude Code loads the plugin from `~/.claude/plugins/pds/`. On load:
- `hooks/hooks.json` registers event handlers
- `agents/*.md` become available for `Task(agent-type)` spawning
- `skills/*/SKILL.md` become available as `/pds:<name>` commands
- `.claude/settings.json` is merged into the session's settings

---

## 1. Hook System

Hooks wire Claude Code lifecycle events to shell scripts. Defined in `hooks/hooks.json`.

### Structure

```json
{
  "hooks": {
    "<EventName>": [
      {
        "matcher": "<ToolPattern>",    // optional — scopes by tool name
        "hooks": [
          {
            "type": "command",         // "command" or "prompt"
            "command": "path/to/script.sh",
            "timeout": 10              // seconds
          }
        ]
      }
    ]
  }
}
```

- **Matcher**: pipe-separated regex on tool name (e.g., `"Bash"`, `"Write|Edit"`, `"Skill|Agent"`). Omit to fire on all tools.
- **Exit codes**: `0` = allow, `2` = block (stderr message shown to agent).
- **`$ARGUMENTS`**: Claude Code passes context (tool input, command text) as environment.

### Hook Registry

Events fire in this order during a session:

#### Session Lifecycle

| Event | Script | Behavior | Blocks? |
|-------|--------|----------|---------|
| `SessionStart` | `session-start.sh` | Inject PDS version, skill hints, worktree state into context | No |
| `InstructionsLoaded` | `instructions-telemetry.sh` | Log instruction loading to telemetry | No |
| `Stop` | _(prompt hook)_ | Verify agent tested code before stopping | Yes |

#### User Interaction

| Event | Script | Behavior | Blocks? |
|-------|--------|----------|---------|
| `UserPromptSubmit` | `skill-hint.sh` | Suggest relevant `/pds:*` skills based on prompt keywords | No |
| `UserPromptSubmit` | `health-check.sh` | Remind user to take breaks (30m/60m/120m thresholds) | No |

#### Tool Execution

| Event | Matcher | Script | Behavior | Blocks? |
|-------|---------|--------|----------|---------|
| `PreToolUse` | `Bash` | `secret-scrub.sh` | Rewrite commands that may leak secrets through sed pipeline | No (rewrites) |
| `PostToolUse` | _(all)_ | `mcp-secret-scrub.sh` | Scrub secret patterns from MCP tool output | No (scrubs) |
| `PostToolUse` | `Write\|Edit` | `file-telemetry-log.sh` | Log file modifications to telemetry | No |
| `PostToolUse` | `Skill\|Agent` | `telemetry-log.sh` | Log skill/agent invocations to telemetry | No |

#### Agent Coordination

| Event | Script | Behavior | Blocks? |
|-------|--------|----------|---------|
| `SubagentStart` | `roster-check.sh` | Warn on unknown agent types not in PDS roster | No |
| `TaskCompleted` | `task-completed-gate.sh` | Run test suite; block if tests fail | Yes |
| `TeammateIdle` | `teammate-idle-gate.sh` | Block idle if uncommitted changes exist | Yes |

#### Context Management

| Event | Script | Behavior | Blocks? |
|-------|--------|----------|---------|
| `PreCompact` | `pre-compact-snapshot.sh` | Save swarm phase + tier before context compaction | No |
| `PostCompact` | `post-compact-inject.sh` | Restore swarm context after compaction | No |

#### Worktree

| Event | Script | Behavior | Blocks? |
|-------|--------|----------|---------|
| `WorktreeCreate` | `worktree-telemetry.sh` | Log worktree creation | No |
| `WorktreeCreate` | `sync-worktree-permissions.sh` | Symlink `settings.local.json` from repo root | No |

#### Orchestrator-Only Hooks (defined in `orchestrator.md` frontmatter)

| Event | Matcher | Script | Behavior | Blocks? |
|-------|---------|--------|----------|---------|
| `PreToolUse` | `Bash` | `orchestrator-pr-gate.sh` | Block `gh pr create` unless phase >= consolidate + reports exist | Yes |
| `PreToolUse` | `TeamDelete` | `orchestrator-teardown-gate.sh` | Block cleanup unless phase = knowledge + all reports + worktrees clean | Yes |

---

## 2. Agent Roster

Agents are markdown files with YAML frontmatter. Claude Code reads the frontmatter to configure the agent at spawn time.

### Frontmatter Schema

```yaml
---
name: agent-name            # Used in Task(agent-name) and SendMessage(to=)
description: one-liner      # Shown in /help and agent selection
inherits: shared-rules      # Behavioral rules (all agents inherit this)
model: opus|sonnet|haiku    # Default model (overridable at spawn via model= param)
tools:                      # Allowed tools (explicit allowlist)
  - Read
  - Write
  - Task(worker, validator) # Typed spawn — can only create these agent types
  - SendMessage
permissionMode: default|acceptEdits|plan  # How tool permissions are handled
skills:                     # Available /pds:<name> commands
  - pds:verify
color: green                # UI color for this agent's output
maxTurns: 50                # Hard limit on conversation turns
isolation: worktree         # Optional — creates isolated git worktree
memory: project             # Optional — persistent project-level memory
hooks:                      # Agent-specific hook overrides
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "path/to/gate.sh"
---
```

### Roster

| Agent | Model | Mode | Turns | Isolation | Role |
|-------|-------|------|-------|-----------|------|
| **orchestrator** | opus | default | 100 | — | Plans, decomposes, dispatches, consolidates. Owns the phase state machine. |
| **worker** | sonnet | acceptEdits | 50 | worktree | Implements scoped tasks. Commits frequently. Self-claims next task. |
| **validator** | sonnet | acceptEdits | 40 | — | Merges branches, runs tests, writes structured validation report. |
| **researcher** | sonnet | plan | 30 | — | Read-only codebase exploration. Produces context for orchestrator. |
| **reviewer** | sonnet | plan | 25 | — | Code review: quality, security, correctness. Read-only. |
| **documenter** | sonnet | acceptEdits | 30 | — | Updates READMEs, changelogs, API docs after code changes. |
| **scout** | haiku | acceptEdits | 15 | — | PDS meta-improvement: instinct updates, skill evals, telemetry analysis. |
| **auditor** | sonnet | plan | 30 | — | Scans for tech debt, files findings as GitHub issues. |

### Tier Overrides

Tiers control model selection at dispatch. Set during Phase 1, stored in `.claude/swarm/tier`.

| Agent | Lite | Med | Heavy |
|-------|------|-----|-------|
| orchestrator | sonnet | opus | opus |
| researcher | _(skip)_ | sonnet | opus |
| worker | haiku | sonnet | sonnet |
| validator | haiku | sonnet | sonnet |
| reviewer | _(skip)_ | sonnet | opus |
| documenter | _(skip)_ | sonnet | sonnet |
| scout | haiku | haiku | sonnet |
| auditor | _(skip)_ | _(skip)_ | sonnet |

### Shared Rules

All agents inherit `shared-rules.md`. Key behaviors:

- **Commit frequently** — progress lives in commits, not context
- **Use SendMessage** — plain text output is invisible to teammates
- **Read `context.md` on init** — if `.claude/swarm/context.md` exists, read it first
- **Self-validate** — run `/pds:verify` before declaring done
- **Task claiming** — after completing a task, check `TaskList` and claim next unblocked (lowest ID first)
- **Escalate after 2 failures** — don't retry blindly, report to orchestrator
- **Exponential backoff** — for polling: 5s → 15s → 30s → 60s cap, max 5 empty polls

### Communication

Agents communicate via `SendMessage(to="name", message="text")`. Direct text output is only visible to the user, not to other agents. Key patterns:

- Worker → Orchestrator: blocker reports, task completion
- Orchestrator → Worker: re-activation on idle, task reassignment
- Validator → Orchestrator: merge conflicts, test failures
- `to="*"`: broadcast to all teammates (expensive, use sparingly)

---

## 3. Skill System

Skills are documentation files that define workflow patterns. No executable code — Claude reads the skill and follows the instructions.

### Format

```
skills/<name>/
├── SKILL.md       # Skill documentation (frontmatter + markdown)
└── EVAL.md        # Optional test scenarios for skill evaluation
```

**SKILL.md frontmatter:**
```yaml
---
description: One-line description shown in /help
---
```

### Discovery

Claude Code discovers skills by **directory name**: `skills/swarm/SKILL.md` becomes `/pds:swarm`. The `pds:` prefix comes from the plugin name in `plugin.json`.

### Categories

| Category | Skills | Purpose |
|----------|--------|---------|
| Swarm workflow | `swarm`, `grill`, `verify`, `finish`, `team` | 6-phase coordination lifecycle |
| Shipping | `bcp`, `bump` | Version bump, commit, push |
| Fixing | `bugfix`, `merge`, `rebase` | Test-first fixes, branch management |
| Team ops | `dispatch`, `worktree`, `allow`, `sandbox` | Agent dispatch, isolation, permissions |
| Meta | `audit-config`, `eval`, `ethos`, `instinct`, `trim`, `telemetry`, `contribute`, `triage` | Self-improvement, pattern capture |
| Admin | `pause`, `inspect`, `preflight`, `pr-review`, `export` | Session management, environment validation |
| Deprecated | `permission-router` | Replaced by `sandbox` in v4.6.0 |

### EVAL.md

Optional test scenarios for statistical skill evaluation via `scripts/run-eval.sh`. Each scenario defines an input prompt, expected behavior, and grading criteria. The scout agent runs evals during Phase 6 of a swarm.

---

## 4. Swarm Runtime

The swarm runtime is a set of files in `.claude/swarm/` that coordinate the 6-phase workflow. These files are created at runtime by the orchestrator and consumed by other agents.

### Phase State Machine

```
plan → decompose → dispatch → validate → consolidate → knowledge
```

**Forward-only.** The orchestrator tracks the current phase in `.claude/swarm/phase` (a plain text file containing one word). Each transition writes the next phase name before proceeding.

```bash
# Initialize
mkdir -p .claude/swarm && echo "plan" > .claude/swarm/phase

# Advance
echo "decompose" > .claude/swarm/phase
```

### Artifacts

| File | Written In | By | Consumed By | Format |
|------|-----------|-----|-------------|--------|
| `phase` | All phases | Orchestrator | PR gate, teardown gate | Plain text: phase name |
| `tier` | Phase 1 | Orchestrator | Dispatch (model selection) | Plain text: `lite`, `med`, or `heavy` |
| `plan.md` | Phase 2 | Orchestrator | — | Markdown: decomposition strategy, work units |
| `context.md` | Phase 2 | Orchestrator | Workers (on init) | Markdown: plan summary, research, criteria, decisions, contracts |
| `contracts.md` | Phase 2 | Orchestrator | Workers (cross-boundary) | Markdown: interface definitions |
| `checkpoint.json` | All transitions | Orchestrator | Restart recovery | JSON: phase, tier, tasks, assignments, timestamp |
| `validation-report.md` | Phase 4 | Validator | PR gate, teardown gate | Markdown with JSON-checkable fields |
| `review-report.md` | Phase 5 | Reviewer | PR gate, teardown gate | Markdown: review findings |
| `scout-report.md` | Phase 6 | Scout | Teardown gate | Markdown: patterns, evals, promotions |

### Phase Gates

Shell scripts enforce the state machine. Defined as `PreToolUse` hooks on the orchestrator agent (in `orchestrator.md` frontmatter, not in `hooks.json`).

**PR Gate** (`orchestrator-pr-gate.sh`)
- Triggers on: `gh pr create` in Bash
- Blocks unless: phase >= `consolidate` AND `validation-report.md` exists AND `review-report.md` exists
- Falls through (allows) if no `.claude/swarm/` directory (non-swarm session)

**Teardown Gate** (`orchestrator-teardown-gate.sh`)
- Triggers on: `TeamDelete` tool call
- Blocks unless: phase = `knowledge` AND all 3 reports exist AND `.worktrees/` clean AND `docs/swarm-reports/` exists
- Falls through if no `.claude/swarm/` directory

**Validator Stop Hook** (prompt hook in `validator.md`)
- Triggers on: validator calling `Stop`
- Blocks unless: structured report written with JSON-checkable fields

### context.md

The bridge between orchestrator and workers. Workers read this on init instead of inheriting fork-level context.

```markdown
## Plan Summary
[What we're building and why]

## Research Findings
[Key codebase facts from researcher]

## Acceptance Criteria
[Mechanically verifiable checklist]

## Key Decisions
[Architectural choices with rationale]

## Contracts
[Interface boundaries between zones]
```

Keep under 200 lines. Factual only.

### checkpoint.json

Written at each phase transition for restart recovery:

```json
{
  "phase": "dispatch",
  "tier": "heavy",
  "tasks": ["1", "2", "3"],
  "assignments": {"1": "worker-auth", "2": "worker-api"},
  "timestamp": "2026-04-07T15:00:00Z"
}
```

If the orchestrator fails mid-swarm, a new orchestrator reads this to resume without re-planning.

### validation-report.md

Must include JSON-checkable fields for mechanical verification:

```json
{
  "merge_status": {"task-1-branch": "merged", "task-2-branch": "conflict"},
  "test_counts": {"total": 42, "passed": 40, "failed": 2, "skipped": 0},
  "criteria_verdicts": [
    {"criterion": "JWT login endpoint at POST /auth/login", "status": "pass", "evidence": "test_auth.py:15"},
    {"criterion": "Token validation middleware", "status": "fail", "evidence": "Missing test coverage"}
  ],
  "overall": "needs_fixes"
}
```

### Task Claiming (Pull Model)

Workers don't wait for assignment after their first task. They self-claim:

1. Complete current task → `/pds:verify` → `TaskUpdate(status="completed")`
2. `TaskList` → find tasks with status `pending`, no owner, empty `blockedBy`
3. Claim lowest ID first: `TaskUpdate(taskId, owner="my-name", status="in_progress")`
4. `TaskGet(taskId)` → read full requirements
5. If discovering more work: `TaskCreate` with dependencies

The orchestrator monitors via `TaskList` and intervenes only on stalls (backpressure via `SendMessage`, or `TaskStop` + reassign after 2x estimated turns).

---

## Tracing a Swarm Lifecycle

A complete trace of which files are touched during a heavy-tier swarm:

### Session Start
```
hooks.json → SessionStart → session-start.sh
  reads: .claude-plugin/plugin.json (version)
  writes: PDS_VERSION, PDS_PLUGIN_ROOT to CLAUDE_ENV_FILE
  outputs: additionalContext with PDS version + skill hints
```

### Phase 1: Plan
```
User invokes /pds:swarm heavy
  skill: skills/swarm/SKILL.md (read by Claude)

Orchestrator spawns:
  agents/orchestrator.md (frontmatter configures model=opus, tools, hooks)
  agents/shared-rules.md (inherited behavioral rules)

Orchestrator creates state:
  .claude/swarm/phase → "plan"
  .claude/swarm/tier → "heavy"
  .claude/swarm/checkpoint.json

Orchestrator spawns researcher:
  agents/researcher.md (model=opus for heavy tier)
  hooks.json → SubagentStart → roster-check.sh (validates agent type)

Orchestrator runs /pds:grill:
  skills/grill/SKILL.md (requirement interrogation)
```

### Phase 2: Decompose
```
.claude/swarm/phase → "decompose"
.claude/swarm/checkpoint.json (updated)
.claude/swarm/plan.md (decomposition strategy)
.claude/swarm/context.md (worker bridge: plan + research + criteria)
.claude/swarm/contracts.md (if cross-boundary work)
```

### Phase 3: Dispatch
```
.claude/swarm/phase → "dispatch"

TeamCreate → ~/.claude/teams/<name>/config.json
TaskCreate → ~/.claude/tasks/<name>/<id>.json (per task)

Worker spawns:
  agents/worker.md (model=sonnet, isolation=worktree)
  hooks.json → SubagentStart → roster-check.sh
  hooks.json → WorktreeCreate → worktree-telemetry.sh
  hooks.json → WorktreeCreate → sync-worktree-permissions.sh

Worker reads:
  .claude/swarm/context.md (first action on init)

Worker writes code:
  hooks.json → PostToolUse (Write|Edit) → file-telemetry-log.sh
  agents/worker.md → PostToolUse (Write|Edit) → post-write-check.sh (lint)

Worker completes task:
  hooks.json → TaskCompleted → task-completed-gate.sh (runs tests)
  Worker claims next: TaskList → TaskUpdate
```

### Phase 4: Validate
```
.claude/swarm/phase → "validate"

Validator spawns:
  agents/validator.md (model=sonnet)
  Validator merges branches, runs tests
  Writes: .claude/swarm/validation-report.md (JSON-checkable fields)

Validator stops:
  agents/validator.md → Stop hook (prompt verifies report quality)
```

### Phase 5: Consolidate
```
.claude/swarm/phase → "consolidate"

Reviewer spawns:
  agents/reviewer.md (model=opus for heavy tier)
  Writes: .claude/swarm/review-report.md

Documenter spawns (if docs affected):
  agents/documenter.md

PR creation:
  agents/orchestrator.md → PreToolUse (Bash) → orchestrator-pr-gate.sh
    checks: phase >= consolidate ✓
    checks: validation-report.md exists ✓
    checks: review-report.md exists ✓
    allows: gh pr create
```

### Phase 6: Knowledge
```
.claude/swarm/phase → "knowledge"

Scout spawns:
  agents/scout.md (model=sonnet for heavy tier)
  Reads: .claude/instincts.md (if exists)
  Runs: /pds:eval on exercised skills
  Writes: .claude/swarm/scout-report.md

Agents shutdown:
  SendMessage(type="shutdown_request") to each agent

Team cleanup:
  agents/orchestrator.md → PreToolUse (TeamDelete) → orchestrator-teardown-gate.sh
    checks: phase = knowledge ✓
    checks: validation-report.md exists ✓
    checks: review-report.md exists ✓
    checks: scout-report.md exists ✓
    checks: .worktrees/ clean ✓
    allows: TeamDelete

Artifact archival:
  .claude/swarm/*.md → docs/swarm-reports/<YYYY-MM-DD-HHmm>/

Branch cleanup:
  git worktree remove .worktrees/<name> (per worker)
  git branch -d <branch> (per merged branch)
```

### Context Compaction (any time)
```
If Claude compacts old turns during a swarm:
  hooks.json → PreCompact → pre-compact-snapshot.sh
    reads: .claude/swarm/phase, .claude/swarm/tier
    writes: .claude/swarm/pre-compact-snapshot.md

  hooks.json → PostCompact → post-compact-inject.sh
    reads: .claude/swarm/pre-compact-snapshot.md
    outputs: additionalContext (re-injects phase + tier)
    deletes: pre-compact-snapshot.md
```

---

## Telemetry Files

Created when `PDS_TELEMETRY=1`:

| File | Scope | Content |
|------|-------|---------|
| `.claude/telemetry.jsonl` | Project | Skill invocations, agent spawns, file modifications |
| `~/.claude/telemetry/sessions.jsonl` | User | Cross-project telemetry (survives worktree cleanup) |
| `~/.config/pds/scrub-telemetry.jsonl` | User | Secret scrubbing audit log (metadata only, no secrets) |

Format: `{"ts":"...","event":"skill_invoked","name":"swarm","agent":"orchestrator","session":"...","repo":"..."}`
