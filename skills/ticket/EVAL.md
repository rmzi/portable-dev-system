---
skill: ticket
---
# Eval: /pds:ticket

## Scenarios

### Scenario: Kickoff — new issue, 7-section evolving-body format
**Setup:** Phase 1 of a new swarm. Grill has produced a plan, acceptance criteria, and at least one identified risk and one architectural decision. No existing issue matches this task.
**Prompt:** Find or create the GitHub ticket for this swarm.
**Expected:**
- [ ] Searches for an existing matching issue before creating one
- [ ] Creates a new issue using `skills/ticket/templates/issue-body.md`, not an ad-hoc body
- [ ] All 7 sections present, in order: TL;DR, Decisions, Risks, Acceptance Criteria, Full Plan, Dev Diary, Full Conversation
- [ ] TL;DR, Decisions, Risks, Acceptance Criteria, Full Plan are populated with real content from grill/plan — not left as `{{PLACEHOLDER}}` text
- [ ] Dev Diary and Full Conversation are left as the explicit "populated by /pds:finish" placeholder — not fabricated
- [ ] Acceptance Criteria uses lettered groups + checkboxes, mechanically verifiable (no "looks good" items)
- [ ] `pds-active-swarm` label applied
- [ ] Issue number written to `.claude/swarm/ticket`
**Anti-patterns:**
- [ ] Reverts to the old "## Plan / ## Acceptance Criteria / ## Swarm Context" shape
- [ ] Leaves any of the 5 populated-at-kickoff sections empty or as raw `{{PLACEHOLDER}}` text
- [ ] Invents Dev Diary or Full Conversation content that doesn't exist yet
- [ ] Skips the existing-issue search and creates a duplicate

### Scenario: Mid-flight — new risk surfaces during Phase 3
**Setup:** Swarm is mid-dispatch. A worker reports a risk not identified during grill (e.g. an unexpected API rate limit).
**Prompt:** Update the ticket to reflect this new risk.
**Expected:**
- [ ] Appends a new numbered item to the existing Risks section
- [ ] Does not rewrite or remove existing Risks entries
- [ ] Does not touch Decisions, Full Plan, or other sections
- [ ] Marked `[ ] open` (not fabricated as already mitigated)
**Anti-patterns:**
- [ ] Rewrites the whole body via `gh issue edit --body-file` with a fully reconstructed body (mid-flight wholesale rewrite — reserved for `/pds:finish`)
- [ ] Posts the new risk only as a comment, never reflected in the body's Risks section (comments are for phase-transition narration, not for content that belongs in a tracked section)

### Scenario: PR creation uses the slim template
**Setup:** Phase 5. Validation and review reports exist. Ticket #42 exists with a populated 7-section body.
**Prompt:** Create the PR for this swarm's work.
**Expected:**
- [ ] PR body built from `skills/ticket/templates/pr-body.md`
- [ ] Contains `Closes #42`
- [ ] Contains a link to issue #42 for full context
- [ ] Does NOT duplicate the issue's TL;DR, Decisions, Risks, Acceptance Criteria, or Full Plan in the PR body
**Anti-patterns:**
- [ ] Uses `gh pr create --fill` (pulls commit messages into a bespoke body instead of the slim template)
- [ ] Copies the issue body's sections into the PR body ("just to be safe")
- [ ] Omits `Closes #<num>` entirely

## Baseline
Without this skill's 7-section discipline, agents typically write ad-hoc issue bodies with a "Context" section blending problem statement and discovery narrative, no separate Decisions or Risks tracking, and PR bodies that re-paste the issue's content — two sources of truth that drift apart over the ticket's life (see PR #160's stale description, the motivating incident for ADR 0009).
