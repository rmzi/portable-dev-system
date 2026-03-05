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

## Baseline
Without `/finish`, agents typically push the branch as-is. Rebase, history cleanup, and post-rebase testing are rarely done spontaneously. The PR often has messy commit history and may be based on a stale main.
