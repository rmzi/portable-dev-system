---
description: Focused rebase against a target branch. Use when you need to update a feature branch with upstream changes. Stops on conflicts — does not auto-resolve. Extended mode adds autonomous conflict resolution and test-fix loop.
---
# /rebase — Branch Rebase

Focused rebase of the current branch against a target. Lists conflicts and stops if any are found. Does NOT run tests, read code, or do anything beyond the rebase operation unless explicitly asked.

## When to Use

- Before creating a PR (to ensure branch is up to date)
- When upstream changes may conflict with your work
- As part of `/pds:finish` branch completion protocol

## Protocol

### 1. Fetch
```bash
git fetch origin
```

### 2. Check Status
Ensure working tree is clean before rebasing:
```bash
git status
```
If there are uncommitted changes, commit or stash them first. Do not proceed with a dirty working tree.

### 3. Rebase
```bash
git rebase origin/<target-branch>
```
Default target: `main`. Use the branch specified by the user if provided.

### 4. Handle Conflicts

**If conflicts occur — STOP.**

List each conflict clearly:
```
## Rebase Conflicts
- `path/to/file.ts` — conflict between local change and upstream
- `path/to/other.ts` — both sides modified the same function
```

Do NOT attempt to resolve conflicts automatically. Report them and wait for instructions.

To abort if needed:
```bash
git rebase --abort
```

### 5. Report
When rebase completes successfully (no conflicts):
```bash
git log --oneline origin/<target-branch>..HEAD
```
Show the rebased commits to confirm the result.

## What This Skill Does NOT Do

- **No tests.** Does not run the test suite (use `/pds:verify` for that).
- **No code reading.** Does not analyze code changes (use `/pds:verify` or the reviewer agent).
- **No conflict resolution.** Stops and reports if conflicts exist.
- **No force push.** Reports that a force push may be needed but does not execute it.

## Invocation

```
/rebase                 # rebase against main (standard mode)
/rebase develop         # rebase against develop
/rebase origin/release  # rebase against specific remote branch
/rebase --fix           # autonomous rebase-test-fix loop (see below)
/rebase --fix develop   # autonomous loop against develop
```

---

## Autonomous Mode (`--fix`)

When invoked with `--fix`, the rebase skill enters an autonomous loop that resolves conflicts, runs tests, and fixes failures iteratively. Use when you want hands-off rebase resolution.

### Loop Protocol

```
Cycle 1:
  1. Rebase (steps 1-3 above)
  2. If conflicts → attempt resolution
  3. Run test suite
  4. If tests pass → done
  5. If tests fail → fix failures

Cycle 2-3:
  Repeat steps 2-5

Cycle 4 (max):
  If still failing → STOP and escalate
```

### Conflict Resolution (autonomous)

For each conflicted file:
1. Read both sides of the conflict
2. Understand the intent of each change
3. Resolve preserving both intents where possible
4. If a conflict is ambiguous (both sides changed the same logic for different reasons), mark it for human review and abort
5. After resolving all conflicts: `git rebase --continue`

### Test-Fix Cycle

After successful rebase (or conflict resolution):
1. Run the project's test suite
2. If all tests pass — rebase is complete, report `git log`
3. If tests fail:
   - Analyze each failure using `/pds:bugfix` methodology
   - Fix the interaction between rebased changes and upstream
   - Re-run tests
   - If still failing, count as one cycle iteration

### Limits

- **Max 3 fix cycles.** After 3 iterations of test-fix, stop and escalate.
- **Abort on ambiguous conflicts.** If conflict resolution requires design decisions (not just mechanical merges), abort and report.
- **No modifying upstream tests.** If upstream added tests that fail due to your changes, fix your code to be compatible — do not modify the upstream tests.

### Escalation

When the loop exhausts its cycles:
```
## Rebase-Fix Escalation
### Attempted
- Cycle 1: [what was tried, what failed]
- Cycle 2: [what was tried, what failed]
- Cycle 3: [what was tried, what failed]
### Remaining failures
- `test_name` — `path:line` — [error description]
### Recommendation
[What a human should look at to resolve this]
```

## See Also

- `/pds:finish` — Full branch completion protocol (includes rebase as step 2)
- `/pds:verify` — Run tests after rebase to confirm nothing broke
- `/pds:bugfix` — Test-first bug fix methodology (used in fix cycles)
