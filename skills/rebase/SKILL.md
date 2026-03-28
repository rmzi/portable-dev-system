---
description: Focused rebase against a target branch. Use when you need to update a feature branch with upstream changes. Stops on conflicts — does not auto-resolve.
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
/rebase                 # rebase against main
/rebase develop         # rebase against develop
/rebase origin/release  # rebase against specific remote branch
```

## See Also

- `/pds:finish` — Full branch completion protocol (includes rebase as step 2)
- `/pds:verify` — Run tests after rebase to confirm nothing broke
