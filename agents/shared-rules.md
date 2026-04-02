---
name: shared-rules
description: Common behavioral rules inherited by all PDS agents. Not a standalone agent — referenced via `inherits: shared-rules` in agent frontmatter.
---
# Shared Rules

Behavioral rules that apply to all PDS agents. Individual agent definitions inherit these via `inherits: shared-rules` in their frontmatter.

## Progress

- **Commit frequently.** Progress lives in commits, not context. Commit after each meaningful change with a descriptive message.
- **Use absolute paths.** Agent working directories reset between tool calls. Always use absolute file paths.

## Communication

- **Plain text is invisible to teammates.** Always use `SendMessage` to communicate with other agents. Direct output is only visible to the user.
- **Report blockers immediately.** Commit current progress, update task status, send details to the orchestrator via `SendMessage`.

## Error Escalation

- **Fix specific issues, don't retry blindly.** Diagnose the root cause before attempting a fix.
- **Escalate after 2 failed attempts.** If the same approach fails twice, report the issue to the orchestrator rather than continuing to iterate.
- **Never fabricate.** If you don't know something, say so. Check docs, read code, or ask — don't guess.

## Context Efficiency

- **Read context file first.** If `.claude/swarm/context.md` exists, read it on init — it contains the orchestrator's plan, research findings, acceptance criteria, and key decisions. This avoids re-discovering context the orchestrator already gathered.
- **Read before writing.** Understand existing code and patterns before making changes.
- **Match codebase style.** Follow existing conventions, naming patterns, and file structures.
- **Minimal reads.** Read only the files relevant to your task. Use Grep/Glob to find files before reading them.

## Async Polling

When polling for results (test runs, CI status, external processes):

1. **Exponential backoff.** Wait 5s, then 15s, then 30s, then cap at 60s between polls.
2. **Max 5 empty polls.** After 5 consecutive polls with no new results, stop polling.
3. **3-minute timeout.** If no results after 3 minutes total, stop and escalate to the human with a summary of what was attempted.
4. **Never use `sleep` loops.** Prefer `run_in_background` for long-running commands, or check once and report status.

## Task Claiming

After completing a task, check `TaskList` for available work:

1. Look for tasks with status `pending`, no owner, and empty `blockedBy`.
2. Prefer tasks in **ID order** (lowest first) — earlier tasks often set up context for later ones.
3. Claim with `TaskUpdate(taskId, owner="your-name", status="in_progress")`.
4. Read the full task via `TaskGet` before starting work.
5. If you discover additional work during implementation, create new tasks with `TaskCreate`.

## Efficiency

- **Log phase transitions.** When starting and completing significant phases of work (reading context, implementing, testing, validating), the timestamps in telemetry capture value-creating vs. idle time. Keep work focused and avoid unnecessary re-reads of already-analyzed files.

## Completion

1. **Self-validate.** Run `/pds:verify` before declaring any task done.
2. **Final commit.** Ensure all changes are committed.
3. **Mark complete.** `TaskUpdate(taskId, status="completed")`.
4. **Report.** Send summary to orchestrator via `SendMessage`.
5. **Claim next.** Check `TaskList` for next available task.
