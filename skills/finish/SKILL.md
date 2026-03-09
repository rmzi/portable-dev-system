---
description: Completing a development branch for merge readiness. Use when implementation and tests pass and the branch needs formal preparation for review and merge.
disable-model-invocation: true
---
# /finish — Branch Completion Protocol

The gap between "code works" and "branch is ready" is where quality lives. This protocol ensures branches are clean, tested, and reviewable — then ships via `/bcp`.

## Invocation

```
/finish patch [target-branch]    # Verify, clean, bump patch, ship
/finish minor [target-branch]    # Verify, clean, bump minor, ship
/finish major [target-branch]    # Verify, clean, bump major, ship
```

Default target: main.

## Protocol

### 1. Verify Completeness
Run `/pds:verify` first. Do not proceed until it passes.

### 2. Rebase onto Target
Ensure your branch is current with the target:

```bash
git fetch origin
git rebase origin/main    # or target branch
```

Resolve any conflicts. Each conflict resolution should maintain both sides' intent — don't blindly accept one side.

### 3. Clean Commit History
Review your commits. Squash fixup commits, reword unclear messages:

```bash
git log --oneline main..HEAD
```

Each commit should be atomic and meaningful. Use conventional commit format: `<type>(<scope>): <subject>`. Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `perf`. Subject in imperative mood, max 72 chars. Body explains *what* and *why*, not *how*.

### 4. Run Tests Post-Rebase
Tests must pass *after* rebase, not just before:

```bash
# Run full test suite again
npm test    # or equivalent
```

Rebasing can introduce subtle breakage — verify.

### 5. Ship
Run `/pds:bcp` with the bump type to finalize. Forward the exact bump type from the `/finish` invocation — do not choose a different one:

```
/bcp <bump-type>    # Forward the same bump type from /finish invocation
```

Example: `/finish minor` → `/bcp minor`.

This commits any remaining changes, bumps the version, pushes, and creates/updates the PR.

## Cleanup

After the branch is merged:

- [ ] Remove the worktree: `git worktree remove .worktrees/branch-name`
- [ ] Delete the branch: `git branch -d branch-name`
- [ ] Close related issues
- [ ] Update task status via TaskUpdate if working as a team agent

## When to Use

| Situation | Skill |
|-----------|-------|
| Formal ship: verify, rebase, clean, bump, push | `/finish` |
| Quick ship: bump, commit, push | `/bcp` |

## See Also

- `/pds:bcp` — bump, commit, push (step 5)
- `/pds:verify` — completion self-check (step 1)
- `/pds:merge` — merging subtask worktrees to coordinator
