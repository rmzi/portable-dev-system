---
description: Reconstruct swarm state after a pause, a crash, or a handoff to a different machine or person. Use when starting a session that should continue prior swarm work instead of starting fresh.
---
# /resume — Swarm State Reconstruction

Rebuilds `.claude/swarm/` state (phase, tier, tasks) and native `TaskCreate` entries so work can continue where it left off. Tries the cheapest, most complete source first and falls back only as needed — most resumes are same-machine and need nothing beyond a local file read.

## Invocation

```
/pds:resume              # auto-discover: local state, then ticket, then label search
/pds:resume 42           # explicit ticket number — skips discovery, goes straight to reconstruction
```

## Why This Exists

Claude Code's native Task-tool state (`~/.claude/tasks/`) and team config (`~/.claude/teams/`) are local to the machine that created them — no cross-device sync, and per Claude Code's own docs, `/resume`/`/rewind` do not restore in-process teammates. `.claude/swarm/*` is gitignored — local-only. The one thing that *is* durable and cross-machine is the GitHub ticket `/pds:ticket` maintains. This skill treats the ticket (and, failing that, the archived swarm report) as the recovery source of truth, in priority order from cheapest/most-precise to most expensive/coarsest.

**Platform constraint, not a bug**: a previous session's in-process workers cannot be reattached, on any path below. This skill reconstructs *task and phase state*, not live agent processes. Phase 3's normal pull-model redispatch picks the work back up.

## Protocol

### 1. Same-machine fast path

Check first, before anything else:

```bash
ls .claude/swarm/checkpoint.json .claude/swarm/pause.json 2>/dev/null
```

If either exists, read it — phase, tier, tasks, and assignments are already there (see the Checkpoint Protocol in `agents/orchestrator.md` and the pause.json format in `/pds:pause`). Read `.claude/swarm/context.md` and `.claude/swarm/plan.md` for the fuller plan/decision narrative if present. This path needs no network access and recovers full fidelity — prefer it whenever it's available, even if a ticket argument was also passed.

Skip to step 4 (in-flight task handling) once state is loaded.

### 2. Cross-machine / cross-person resume (in-progress swarm)

No local `.claude/swarm/` state, but a ticket is known (explicit argument, or resolved via step 5 discovery):

```bash
gh issue view <N> --json comments,body,title | jq -r '.comments[] | "\(.createdAt): \(.body)"'
```

Scan comments newest-first for the most recent pause note (posted by `/pds:pause` step 5) or phase-transition comment (posted by `/pds:ticket` section 3). Reconstruct from whichever is more recent:

- **Phase** and **tier** — read directly from the comment text.
- **Task summary** — read the acceptance-criteria checklist from the issue body (`- [ ]` / `- [x]`). Recreate a native task per unchecked criterion via `TaskCreate`, using the criterion text as the `subject`.

**Accept coarser granularity here.** The ticket carries plan-level acceptance criteria, not the fine-grained per-task decomposition the original session had in `.claude/swarm/plan.md`. A reconstructed task list will usually be coarser than the original — that's the real ceiling on what's durable today, not a bug in this skill. Note this explicitly when reporting the resumed state back to the user.

Write `.claude/swarm/phase`, `.claude/swarm/tier`, and a fresh `.claude/swarm/checkpoint.json` from what was recovered, so subsequent phases and gates see consistent local state again.

### 3. Fully completed, already-archived swarm

If the ticket is closed, or its comment thread shows a Phase 6 completion comment, look for the archive instead of trying to resume a swarm that already finished:

```bash
ls docs/swarm-reports/*/  # find the archive matching the ticket's completion comment link
```

Read `plan.md`, `context.md`, and `checkpoint.json` from the matching `docs/swarm-reports/<YYYY-MM-DD-HHmm>/` directory — already git-tracked, already durable. Use this to answer "what happened and why," not to relaunch work. If the user wants follow-up work on a closed ticket, that's a new swarm (`/pds:swarm`), not a resume.

### 4. In-flight work handling

Whatever the source, any task recovered with status `in_progress` had an owner (a worker) that no longer exists in this session. Recreate it as `pending` with owner cleared:

```
TaskUpdate(taskId="<id>", status="pending", owner=null)
```

Let Phase 3's normal pull-model self-claiming pick it back up when workers spawn. **Do not attempt git-branch inspection to detect partial completion in v1** — rely on the worker's own git hygiene (frequent commits) when it re-claims the task and reads its branch. If this proves insufficient in practice, that's a v2 follow-up, not something to improvise here.

### 5. Discovery (no local state, no ticket argument)

Try in order, stopping at the first hit:

1. **Explicit argument** — `/pds:resume <issue-number>` was given. Use it directly.
2. **Branch-name inference** — `/pds:worktree` encodes the issue number in branch names:
   ```bash
   git branch -a | grep -oE '[0-9]+' # refine against the actual branch-naming pattern in use
   ```
3. **Label search** — issues labeled `pds-active-swarm` (applied by `/pds:ticket` at creation/reuse, removed at Phase 6 teardown) are swarms still in flight:
   ```bash
   gh issue list --label pds-active-swarm --state open --json number,title,updatedAt
   ```

If more than one candidate surfaces across these, disambiguate via `AskUserQuestion` with the candidate issue numbers/titles as options (plus "None of these"). Never guess silently when multiple active swarms exist.

## Rules

- **Local state wins.** Never prefer a ticket-comment reconstruction over a present `.claude/swarm/checkpoint.json` — the local file is always higher-fidelity.
- **Never reattach workers.** No tool exists to resume an in-process teammate from a prior session — don't attempt it, don't promise it in status output.
- **Be explicit about fidelity loss.** When reconstructing from a ticket (step 2), tell the user the task list is coarser than the original decomposition — don't present it as a full recovery.
- **A closed ticket is not a resume target.** Route to the archive (step 3) for "what happened," and to `/pds:swarm` for "what's next."
- **Ambiguous discovery escalates, it doesn't guess.** Multiple label matches or branch matches go to `AskUserQuestion`, not a silent pick of the first result.

## See Also

- `/pds:pause` — Writes the local `pause.json` and posts the ticket comment this skill reads.
- `/pds:ticket` — Owns the ticket, the acceptance-criteria checklist, and the `pds-active-swarm` label.
- `/pds:swarm` — The 6-phase workflow that resumes into, once state is reconstructed.
- `docs/adr/0008-task-mobility-via-ticket-not-sub-issues.md` — Why this reads the ticket directly instead of mirroring tasks to GitHub sub-issues.
