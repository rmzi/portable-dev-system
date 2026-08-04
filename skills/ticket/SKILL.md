---
description: Associate every PDS task with a GitHub issue. Orchestrator finds or creates the ticket, posts plan and acceptance criteria as a checkbox list, updates it as work progresses. Use at Phase 1 of every swarm.
---
# /ticket — GitHub Issue Enforcement

Every swarm must be tethered to a GitHub issue. The ticket is the durable record: plan, acceptance criteria, progress, and final PR link. The orchestrator owns this — workers, validators, reviewers, scout, and shepherd reference the ticket but do not manage it.

## Why

- **Traceability.** Every change maps to a ticket, PR, and closed criterion checklist — not just a commit.
- **Handoff across swarms.** A resumed swarm reads the ticket body to recover plan + criteria even if `.claude/swarm/` was cleared.
- **Human visibility.** Progress is visible outside the terminal. Acceptance criteria flip from `[ ]` to `[x]` as the validator confirms them.
- **PR hygiene.** PRs link back with `Closes #<num>` so merging closes the ticket automatically.

## Protocol

### 1. Find or create — at Phase 1 of every swarm

After `/pds:grill` produces a plan + acceptance criteria, the orchestrator searches for an existing ticket:

```bash
# Search open and recently-closed issues for title/body keywords from the task
gh issue list --state all --limit 20 --search "<task keywords>" --json number,title,state,body
```

Rules:
- If exactly one open issue matches the task's intent, **reuse it** — append to the body (don't overwrite).
- If zero matches, **create one** using the 7-section evolving-body template (`skills/ticket/templates/issue-body.md` — see `docs/adr/0009-evolving-body-issue-and-slim-pr-format.md` for why this shape, not a new one invented per-skill):
  ```bash
  cp skills/ticket/templates/issue-body.md /tmp/issue-body.md
  # Fill placeholders from grill + plan output — every section gets real content at
  # kickoff, not just Acceptance Criteria:
  #   {{TLDR}}                — one paragraph: what this task is and why, from grill
  #   {{DECISIONS}}            — numbered list, architectural choices grill/plan already
  #                              made with rationale (why this shape, not another)
  #   {{RISKS}}                — numbered list, each ending `[ ] open` or `[x] mitigated`
  #                              — from grill's risk-surfacing step, not invented here
  #   {{ACCEPTANCE_CRITERIA}}  — lettered groups (A, B, C…), numbered items (A1, A2…),
  #                              checkboxes — mechanically verifiable, same bar as before
  #   {{FULL_PLAN}}            — phase-structured (Phase 0, Phase 1, …) narrative;
  #                              anticipated phases as well as actual, retroactive
  #                              sub-phases (4a, 4b) added if Phase 4 surfaces new work
  # Dev Diary and Full Conversation stay as the template's placeholder text — nothing
  # to show yet at kickoff. /pds:finish populates them when this branch ships.
  sed -i '' \
    -e "s/{{TLDR}}/<one paragraph from grill>/" \
    -e "s/{{ACCEPTANCE_CRITERIA}}/### A. <group>\n- [ ] A1. <criterion>\n- [ ] A2. <criterion>/" \
    /tmp/issue-body.md
  # (Decisions, Risks, Full Plan are usually multi-line — build them with a heredoc
  # into the file directly rather than sed, then gh issue create --body-file.)
  gh issue create --title "<task summary>" --body-file /tmp/issue-body.md
  ```
- If multiple matches exist, **ask the human** via `AskUserQuestion` with the candidate issue numbers as options + "Create new" + "Other".

Whichever branch is taken (reuse or create), apply the `pds-active-swarm` label so the issue is discoverable by `/pds:resume` without any local state:

```bash
gh issue edit <num> --add-label pds-active-swarm
```

Create the label first if it doesn't exist yet (`gh label create pds-active-swarm --color BFD4F2 --description "A PDS swarm is actively working this issue" 2>/dev/null || true` — ignore the error if it already exists).

### 2. Store the issue number (or fallback marker)

Write the resolved issue number to `.claude/swarm/ticket`:

```bash
echo "<issue-number>" > .claude/swarm/ticket
```

If fallback was taken (see section 4), write a **human-readable marker** instead:

```bash
echo "none (<reason>)" > .claude/swarm/ticket
# e.g. "none (no github remote, gh unauthenticated)"
```

All subsequent phases read this file. The invariant is: **the file always exists after Phase 1.** Downstream checks distinguish a real ticket from a fallback marker by the content — if it matches `^[0-9]+$`, it's an issue number; otherwise it's a fallback marker and ticket operations are skipped.

### 3. Update as we go

Mechanical, narrow edits to the body are fine mid-flight — they toggle or append a line without touching the plan/reasoning narrative. **Do not rewrite whole sections mid-flight** (that's `/pds:finish`'s job at ship time, via the evolving-body mechanic — see section 5).

**On each acceptance-criterion completion** (Phase 4, when the validator confirms a criterion):

```bash
# Fetch current body, flip the matching checkbox, write back
gh issue view <num> --json body --jq '.body' \
  | sed 's/- \[ \] <matching criterion text>/- [x] <matching criterion text>/' \
  > /tmp/ticket-body.md
gh issue edit <num> --body-file /tmp/ticket-body.md
```

**On a new risk or decision surfacing mid-swarm**, append a numbered item to the existing Risks or Decisions section (don't rewrite the section, add to it) — same mechanical-edit exception as checkbox flips.

**On phase transitions** (Phase 2, 3, 4, 5, 6 start), post a short comment:

```bash
gh issue comment <num> --body "Phase: <phase-name>. <one-line summary>"
```

**On PR creation** (Phase 5), use the slim PR template (`skills/ticket/templates/pr-body.md`) — `Closes #<num>` plus a link to the issue for full context, not a duplicate of the issue body. Not enforced by the PR gate — the gate only checks phase state + validation/review reports. Omitting `Closes` won't block the PR, but it will break GitHub's auto-close-on-merge and leave the ticket orphaned.

**On swarm completion** (Phase 6, after scout report), post a completion comment with a link to `docs/swarm-reports/<YYYY-MM-DD-HHmm>/` if archived, then remove the `pds-active-swarm` label (`gh issue edit <num> --remove-label pds-active-swarm`) — the swarm is no longer in-flight, so it should drop out of `/pds:resume`'s discovery search.

### 4. Fallback — no GitHub available

If any of these are true, the orchestrator warns and proceeds **without** a ticket, recording the reason in `scout-report.md` AND writing a fallback marker to `.claude/swarm/ticket` (see section 2):
- `gh` CLI is not installed or not authenticated
- The repo has no GitHub remote (`git remote -v` shows no `github.com` origin)
- The user explicitly opts out for this swarm (via Phase 1 approval prompt)

Never block work solely on ticket unavailability. A warning in the swarm report + fallback marker in `.claude/swarm/ticket` is sufficient.

Downstream phases (4, 5, 6) check the ticket file content: if it's numeric, run the ticket update (`gh issue edit`, `gh issue comment`); if it's a fallback marker, skip ticket operations silently.

### 5. Evolving body — the issue is the source of truth, the PR just links to it

The 7-section body created in step 1 is not static. At `/pds:finish` (ship time), the *current* body is preserved as a dated comment (`### Kickoff (preserved)` the first time, `### Snapshot (preserved) — <date>` on any later ship from the same issue), then the body itself is replaced with a finish-writeup in the same 7-section shape — TL;DR hoisted to the final outcome, Decisions/Risks/Acceptance Criteria/Full Plan updated to reflect what actually happened, Dev Diary and Full Conversation populated for the first time. This is `/pds:finish`'s job (see its own protocol), not `/pds:ticket`'s — this skill only ever creates the kickoff body and makes the narrow mid-flight edits above. See `docs/adr/0009-evolving-body-issue-and-slim-pr-format.md`.

## Orchestrator Checklist

- [ ] Phase 1: search for existing ticket; create if none using the 7-section template; resolve ambiguity via `AskUserQuestion`
- [ ] Phase 1: apply `pds-active-swarm` label
- [ ] Phase 1: write issue number to `.claude/swarm/ticket`
- [ ] Phase 2: append acceptance-criteria checklist to ticket body (if newly created)
- [ ] Phase 3: comment on ticket when workers dispatch (tier + worker count)
- [ ] Phase 4: flip criterion checkboxes as validator confirms; comment on validation result
- [ ] Phase 5: create the PR from the slim template (`Closes #<num>` + link to issue, not a duplicate body); comment on ticket linking the PR
- [ ] Phase 6: post completion comment; if archive path exists, link it; remove `pds-active-swarm` label
- [ ] Ship (`/pds:finish`, not this skill): preserve current body as a dated comment, then rewrite it into the finish-writeup — see section 5

## User-Facing Register

The orchestrator speaks terse to the user (see `/pds:voice`) — the ticket body itself is **normal register**, not terse. The ticket is for human and future-agent readability; full prose belongs there. Voice applies to the orchestrator's inline status narration, not to the artifacts it writes.

## See Also

- `/pds:swarm` — Phases reference this skill at 1, 2, 4, 5, 6
- `/pds:finish` — owns the evolving-body rewrite at ship time (section 5); this skill only creates the kickoff body
- `/pds:triage` — downstream skill for converting swarm findings into new tickets
- `/pds:resume` — discovers in-flight swarms via the `pds-active-swarm` label this skill applies
- `docs/adr/0009-evolving-body-issue-and-slim-pr-format.md` — why this 7-section shape, and why the PR stays slim
