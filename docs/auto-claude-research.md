# Auto-Claude Research — Issue #80
*Researcher: auto-generated, April 2, 2026*

---

## Problem Statement

Issue #80 asks: does Claude's scheduled/background agent capability ("auto-claude") provide a path for running PDS swarms on a schedule? Could it replace plugins like `subtask` or `ralph-loop`? What is its relationship to PDS's existing headless dispatch mode?

---

## What "Auto-Claude" Actually Is

"Auto-claude" is not an official product name. The capability it refers to is Claude Code's **scheduled tasks** feature — Anthropic's answer to cron-driven autonomous agent execution. As of April 2026, three scheduling mechanisms exist:

### 1. Cloud Scheduled Tasks (Primary)

Available at `claude.ai/code/scheduled`. Tasks run on Anthropic-managed infrastructure.

**Key characteristics:**
- Runs on a cron cadence (hourly, daily, weekdays, weekly; custom cron via `/schedule update`)
- Minimum interval: **1 hour** — no sub-hourly execution
- Runs **without requiring your machine to be on**
- Operates **autonomously** — no permission prompts
- Accesses repositories via **fresh git clone** on each run — no local file access
- Creates `claude/`-prefixed branches for changes
- Each run appears as a full session you can inspect and resume
- Supports MCP connectors (Slack, Linear, Google Drive, etc.)
- Model is configurable per task
- Managed via `claude.ai/code/scheduled`, Desktop app Schedule page, or CLI `/schedule`

**Limitations:**
- Cannot access local files, local tools, or unreleased branches (fresh clone only)
- No sub-hourly frequency
- No access to local MCP servers (only cloud connectors)
- Each run starts fresh — no persistent state between runs except via git/MCP

### 2. Desktop Scheduled Tasks

Run on your local machine via the Desktop app's Schedule page.

- Can access local files, local MCP servers, local tools
- Minimum interval: 1 minute
- Requires machine to be awake
- Configured per-task with granular permission control

### 3. `/loop` (Session-Scoped)

In-session scheduling via the `/loop` command. Described in the PDS dispatch skill under `CronCreate`.

- Runs on a recurring interval within a session
- Dies when the session ends
- Inherits full session context, local files, all MCP servers

### Feature Flags in Source (March 2026 leak)

The source analysis identified three relevant flags:
- `AGENT_TRIGGERS` — scheduled/event-driven agent runs
- `AGENT_TRIGGERS_REMOTE` — remote trigger execution (CI/CD integration)
- `WORKFLOW_SCRIPTS` — custom workflow automation
- `BG_SESSIONS` — background session management
- `KAIROS` — "always-on background agent" with `autoDream` memory consolidation (heavily gated, unclear timeline)

These flags suggest Anthropic is actively investing in autonomous background execution. Cloud scheduled tasks is likely `AGENT_TRIGGERS` + `AGENT_TRIGGERS_REMOTE` shipped.

---

## Relationship to PDS Headless Dispatch

PDS's `/pds:dispatch` skill already defines a **headless mode** with three mechanisms:

| PDS Headless Mechanism | Cloud Equivalent | Overlap? |
|------------------------|-----------------|----------|
| `CronCreate(schedule=...)` | Cloud scheduled tasks | **Yes** — `CronCreate` is the native API for this |
| `run_in_background` | Background session (`BG_SESSIONS`) | **Yes** — covers long-running background work |
| `SessionStart/Stop` hooks | N/A (local only) | **No** — hooks are local only |

**Conclusion:** PDS's headless dispatch mode already covers the `CronCreate` use case. Cloud scheduled tasks are a cloud-hosted variant of the same capability — no new PDS category is needed. The key difference is persistence: cloud tasks survive machine restarts; PDS `CronCreate` does not.

---

## Could It Replace `subtask` or `ralph-loop`?

### `ralph-loop` (Repeated Prompt Execution)

`ralph-loop` describes a plugin that re-executes a prompt on a loop. Cloud scheduled tasks provide this natively — you write a prompt once and it runs on cadence. **Cloud scheduled tasks are a direct replacement for ralph-loop patterns.** No need to build or maintain a plugin.

**Recommended PDS action:** Document cloud scheduled tasks as the canonical approach for recurring prompt execution. Deprecate any internal ralph-loop equivalent.

### `subtask` (Parallel Subtask Dispatch)

`subtask` dispatches parallel sub-tasks during a swarm. This is covered by:
- PDS's fork subagent mode (same-context quick tasks)
- Claude Code's built-in `Agent` tool with `run_in_background`
- Agent Teams (experimental, v2.1.32+) for full peer-to-peer coordination

**Cloud scheduled tasks do not replace subtask** — they're time-triggered, not parent-triggered. The subtask use case is already served by existing dispatch mechanisms.

---

## Could Auto-Claude Run PDS Swarms on a Schedule?

**Short answer: desktop tasks yes, cloud tasks no (today).**

### Cloud Tasks — Blocked by Fresh Clone

PDS swarms depend on:
1. Local file context (`.claude/swarm/context.md`, worktrees)
2. Sequential phase dependencies
3. Cross-agent communication via shared task system
4. Git worktree isolation per worker

Cloud tasks start from a **fresh git clone** of the default branch. There is no local state, no worktree setup, no `.claude/swarm/` directory, no MCP local servers.

**A cloud task could trigger a simple single-agent PDS skill** (e.g., `preflight`, `audit-config`, `telemetry`) that doesn't require worktrees or inter-agent coordination. Full 6-phase swarms are not viable in the cloud task environment today.

### Desktop Tasks — Viable with Caveats

Desktop scheduled tasks run on your machine with local file access. A desktop task could:
1. Trigger `claude --print "/pds:swarm [task description]"` headlessly
2. Run `preflight` and report results
3. Trigger a targeted audit or telemetry analysis

The main limitation: desktop tasks require the machine to be awake. For scheduled nightly audits where the machine is on, this works.

### Recommended PDS Pattern for Scheduled Swarms

```bash
# Desktop scheduled task (nightly, machine-local)
# Task prompt:
# "Run /pds:preflight and report results. If preflight passes, 
#  run /pds:telemetry to analyze usage patterns from today."
```

---

## Analysis Summary

| Capability | Cloud Tasks | Desktop Tasks | PDS `/dispatch` |
|------------|-------------|---------------|-----------------|
| No machine required | ✅ | ❌ | ❌ |
| Local file access | ❌ | ✅ | ✅ |
| Sub-hourly schedule | ❌ | ✅ | ✅ |
| Full PDS swarm | ❌ | ✅ (machine on) | ✅ (session) |
| Simple recurring prompt | ✅ | ✅ | ✅ |
| Replaces ralph-loop | ✅ | ✅ | N/A |
| Replaces subtask | ❌ | ❌ | ✅ already |
| Persistent across restarts | ✅ | ✅ | ❌ |

---

## Recommendations

1. **No new PDS primitives needed.** Cloud scheduled tasks are the platform-native version of PDS's `CronCreate`. `/pds:dispatch` already documents this. Update the skill to reference the `/schedule` CLI command explicitly.

2. **Document cloud tasks as the recommended path for ralph-loop patterns.** Any recurring single-prompt automation should use cloud scheduled tasks rather than a plugin.

3. **Add a desktop-task recipe for nightly PDS maintenance.** Document a standard desktop scheduled task for running preflight + telemetry. This gives PDS users an "autonomous health check" without requiring a full swarm.

4. **Do not attempt full swarm execution in cloud tasks.** Fresh clone environment is incompatible with PDS's multi-worktree, multi-agent coordination model. Revisit if Anthropic adds persistent storage to cloud task environments.

5. **Monitor KAIROS.** If autoDream (always-on background agent with memory consolidation) ships, it could provide the persistent state that cloud tasks currently lack — enabling full swarm scheduling in the cloud.

---

## Next Steps

- [ ] Update `/pds:dispatch` skill to explicitly reference `/schedule` CLI command and cloud task option
- [ ] Add a "desktop task recipe" for nightly PDS maintenance to `docs/` or the dispatch skill
- [ ] Watch Anthropic releases for KAIROS / persistent cloud session state
- [ ] Issue #80 can be closed once dispatch skill is updated

---

*Sources: [Claude Code web scheduled tasks docs](https://code.claude.com/docs/en/web-scheduled-tasks) · [Claude Code source analysis](./claude-code-source-analysis.md) · [PDS dispatch skill](../skills/dispatch/SKILL.md)*
