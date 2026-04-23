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
- If zero matches, **create one**:
  ```bash
  gh issue create --title "<task summary>" --body "$(cat <<'EOF'
  ## Plan
  <plan summary from grill>

  ## Acceptance Criteria
  - [ ] <criterion 1>
  - [ ] <criterion 2>
  - [ ] <criterion 3>

  ## Swarm Context
  - **Tier:** <lite | med | heavy>
  - **Swarm started:** <YYYY-MM-DD>
  - **Artifacts:** `.claude/swarm/` (ephemeral; archived to `docs/swarm-reports/` on teardown)
  EOF
  )"
  ```
- If multiple matches exist, **ask the human** via `AskUserQuestion` with the candidate issue numbers as options + "Create new" + "Other".

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

**On each acceptance-criterion completion** (Phase 4, when the validator confirms a criterion):

```bash
# Fetch current body, flip the matching checkbox, write back
gh issue view <num> --json body --jq '.body' \
  | sed 's/- \[ \] <matching criterion text>/- [x] <matching criterion text>/' \
  > /tmp/ticket-body.md
gh issue edit <num> --body-file /tmp/ticket-body.md
```

**On phase transitions** (Phase 2, 3, 4, 5, 6 start), post a short comment:

```bash
gh issue comment <num> --body "Phase: <phase-name>. <one-line summary>"
```

**On PR creation** (Phase 5), include `Closes #<num>` in the PR body. Not enforced by the PR gate — the gate only checks phase state + validation/review reports. Omitting `Closes` won't block the PR, but it will break GitHub's auto-close-on-merge and leave the ticket orphaned.

**On swarm completion** (Phase 6, after scout report), post a completion comment with a link to `docs/swarm-reports/<YYYY-MM-DD-HHmm>/` if archived.

### 4. Fallback — no GitHub available

If any of these are true, the orchestrator warns and proceeds **without** a ticket, recording the reason in `scout-report.md` AND writing a fallback marker to `.claude/swarm/ticket` (see section 2):
- `gh` CLI is not installed or not authenticated
- The repo has no GitHub remote (`git remote -v` shows no `github.com` origin)
- The user explicitly opts out for this swarm (via Phase 1 approval prompt)

Never block work solely on ticket unavailability. A warning in the swarm report + fallback marker in `.claude/swarm/ticket` is sufficient.

Downstream phases (4, 5, 6) check the ticket file content: if it's numeric, run the ticket update (`gh issue edit`, `gh issue comment`); if it's a fallback marker, skip ticket operations silently.

## Orchestrator Checklist

- [ ] Phase 1: search for existing ticket; create if none; resolve ambiguity via `AskUserQuestion`
- [ ] Phase 1: write issue number to `.claude/swarm/ticket`
- [ ] Phase 2: append acceptance-criteria checklist to ticket body (if newly created)
- [ ] Phase 3: comment on ticket when workers dispatch (tier + worker count)
- [ ] Phase 4: flip criterion checkboxes as validator confirms; comment on validation result
- [ ] Phase 5: include `Closes #<num>` in PR body; comment on ticket linking the PR
- [ ] Phase 6: post completion comment; if archive path exists, link it

## User-Facing Register

The orchestrator speaks terse to the user (see `/pds:voice`) — the ticket body itself is **normal register**, not terse. The ticket is for human and future-agent readability; full prose belongs there. Voice applies to the orchestrator's inline status narration, not to the artifacts it writes.

## See Also

- `/pds:swarm` — Phases reference this skill at 1, 2, 4, 5, 6
- `/pds:triage` — downstream skill for converting swarm findings into new tickets
