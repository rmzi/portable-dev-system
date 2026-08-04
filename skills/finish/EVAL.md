---
skill: finish
---
# Eval: /pds:finish

## Scenarios

### Scenario: Stale branch with messy history
**Setup:** Feature branch is 12 commits behind main. Has 3 fixup commits ("fix typo", "oops", "actually fix"). Tests pass on the branch but main has moved.
**Prompt:** Prepare this branch for merge.
**Expected:**
- [ ] Runs `/verify` before anything else (step 1)
- [ ] Rebases onto current main (step 2)
- [ ] Cleans commit history — squashes fixup commits (step 3)
- [ ] Runs tests again after rebase (step 4)
- [ ] Creates or updates PR with summary and acceptance criteria
**Anti-patterns:**
- [ ] Skips rebase — merges directly with stale base
- [ ] Skips post-rebase test run
- [ ] Leaves fixup commits in history
- [ ] Pushes without running `/verify` first

### Scenario: Post-rebase test failure
**Setup:** Branch rebased onto main. Rebase succeeded without conflicts. But a test that passed before rebase now fails due to a subtle interaction with a main change.
**Prompt:** Continue the finish protocol after discovering the failure.
**Expected:**
- [ ] Detects failure in step 4 (post-rebase tests)
- [ ] Investigates and fixes the interaction
- [ ] Re-runs full test suite after fix
- [ ] Does not proceed to PR creation until tests pass
**Anti-patterns:**
- [ ] Ignores the failure and creates the PR anyway
- [ ] Blames the test and skips it
- [ ] Pushes with `--no-verify`

### Scenario: Evolving-body rewrite at ship time (`PDS_EVOLVING_BODY=1`)
**Setup:** Branch `feat/42-add-thing` ships. Issue #42 exists with a populated 7-section kickoff body (created via `/pds:ticket`'s current template) — Decisions, Risks, and Acceptance Criteria have real content; Dev Diary and Full Conversation are still the kickoff placeholder text.
**Prompt:** Finish this branch with `PDS_EVOLVING_BODY=1` set.
**Expected:**
- [ ] Fetches issue #42's current body before doing anything else
- [ ] Posts the current body as a comment titled `### Kickoff (preserved)` (first rewrite for this issue)
- [ ] Only after that comment succeeds, overwrites the issue body
- [ ] New body carries forward Decisions, Risks, and Acceptance Criteria verbatim from the old body — no fabricated or dropped items
- [ ] TL;DR is recomputed as the final outcome, not left as the kickoff intent
- [ ] Dev Diary is populated with real chronology/well/wrong content (no longer the placeholder)
- [ ] Full Conversation is populated (embedded if small, linked to `docs/conversations/` if it exceeds the size threshold)
- [ ] PR body (step 7d) uses the slim template with `Closes #42`, not `--fill`
**Anti-patterns:**
- [ ] Overwrites the body without posting the preserve-comment first
- [ ] Silently drops the old Decisions/Risks/Acceptance-Criteria content during the rewrite
- [ ] Also runs the `PDS_DIARY` comment pipeline in the same invocation (double-posts the same dev-diary content)
- [ ] Proceeds with the body overwrite when the preserve-comment post failed

### Scenario: Second rewrite on the same issue (already went through one finish before)
**Setup:** Issue #42 already has the `<!-- pds:finish-writeup-applied -->` marker from a prior `/pds:finish` run. A follow-up PR ships against the same issue.
**Prompt:** Finish this second branch with `PDS_EVOLVING_BODY=1` set.
**Expected:**
- [ ] Detects the existing marker and titles the preserve-comment `### Snapshot (preserved) — <date>`, not `### Kickoff (preserved)`
- [ ] Does not duplicate the `<!-- pds:finish-writeup-applied -->` marker in the new body
**Anti-patterns:**
- [ ] Mislabels a second rewrite as a "Kickoff" preservation
- [ ] Fails to detect the marker and treats every rewrite as the first

## Baseline
Without `/finish`, agents typically push the branch as-is. Rebase, history cleanup, and post-rebase testing are rarely done spontaneously. The PR often has messy commit history and may be based on a stale main. Without the evolving-body step specifically, the issue body freezes at kickoff intent while the PR description (built via `--fill`) becomes the de facto record of what actually happened — exactly the drift that produced a stale PR #160 description mid-session, the motivating incident for ADR 0009.
