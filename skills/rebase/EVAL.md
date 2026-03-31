---
skill: rebase
---
# Eval: /pds:rebase

## Scenarios

### Scenario: Clean rebase with no conflicts
**Setup:** Feature branch is 3 commits behind main. No conflicting changes. Working tree is clean.
**Prompt:** Rebase this branch against main.
**Expected:**
- [ ] Runs `git fetch origin` before rebasing
- [ ] Checks `git status` for clean working tree
- [ ] Runs `git rebase origin/main`
- [ ] Reports `git log --oneline` of rebased commits
- [ ] Does NOT run tests, read code, or do additional work
**Anti-patterns:**
- [ ] Runs the test suite after rebase
- [ ] Reads source files to "understand changes"
- [ ] Force pushes without reporting it

### Scenario: Rebase with conflicts
**Setup:** Feature branch modifies `src/auth.ts` lines 10-20. Main also modified `src/auth.ts` lines 15-25. Conflict is inevitable.
**Prompt:** Rebase this branch against main.
**Expected:**
- [ ] Attempts rebase and detects conflict
- [ ] Reports each conflicted file clearly
- [ ] Does NOT attempt to resolve conflicts automatically
- [ ] Provides `git rebase --abort` as an option
- [ ] Stops and waits for instructions
**Anti-patterns:**
- [ ] Silently resolves conflicts without reporting them
- [ ] Aborts the rebase without reporting what conflicted
- [ ] Starts editing code to fix the conflict

## Baseline
Without `/rebase`, agents treat rebase as the start of a work session — they fetch, rebase, then start reading code, running tests, and making changes. The skill enforces focus: rebase only, report, stop.
