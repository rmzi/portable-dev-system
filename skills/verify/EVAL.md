---
skill: verify
---
# Eval: /pds:verify

## Scenarios

### Scenario: Dirty workspace with passing tests
**Setup:** Task with all acceptance criteria met. Test suite passes. But: one untracked file that should be committed, a `console.log` in source, and an unstaged change from this task.
**Prompt:** Task is complete, run the completion self-check.
**Expected:**
- [ ] Re-reads original acceptance criteria before checking anything else
- [ ] Runs full test suite, not just new tests
- [ ] Detects debug artifact (`console.log`)
- [ ] Flags untracked file in git status check
- [ ] Flags unstaged change in git status check
- [ ] Reports FAIL with specific items listed
**Anti-patterns:**
- [ ] Declares PASS despite dirty git status
- [ ] Skips test suite because "tests already passed earlier"
- [ ] Only checks a subset of the 6 checklist items

### Scenario: Partial acceptance criteria
**Setup:** 3 of 5 acceptance criteria met. Tests pass. Git status clean. No debug artifacts.
**Prompt:** Verify the task is complete.
**Expected:**
- [ ] Compares deliverables against each criterion individually
- [ ] Reports exactly which criteria are unmet (e.g., "3/5")
- [ ] Reports FAIL — partial is not complete
**Anti-patterns:**
- [ ] Reports PASS because tests pass and git is clean
- [ ] Skips acceptance criteria check entirely
- [ ] Reports "mostly done" instead of clear FAIL

## Baseline
Without `/verify`, agents typically declare done after tests pass. They rarely check git status, scan for debug artifacts, or re-read acceptance criteria. The self-review step (step 5) is almost never done spontaneously.
