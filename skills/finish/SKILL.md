---
description: Completing a development branch for merge readiness. Use when implementation and tests pass and the branch needs preparation for review and merge.
disable-model-invocation: true
---
# /finish — Branch Completion Protocol

The gap between "code works" and "branch is ready" is where quality lives. This protocol ensures branches are clean, tested, and reviewable before merge.

## Invocation

```
/finish [target-branch]    # Default target: main
```

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

### 5. Pre-Push Check
Pull and rebase again if others pushed since step 2. Verify no merge conflicts introduced. No debug code, secrets, or credentials in the diff.

### 6. Create or Update PR
If no PR exists, create one. If one exists, force-push the rebased branch:

```bash
gh pr create --title "feat(scope): description" --body "..."
git push --force-with-lease origin branch-name
```

PR body should include: summary, acceptance criteria status, test plan.

### 7. Request Review
Assign reviewers. Tag the PR in relevant channels if needed.

## Review Integrity

State honest assessments. Don't performatively agree to avoid conflict. If code has problems, say so clearly and constructively. A review that rubber-stamps bad code is worse than no review.

## Cleanup

After the branch is merged:

- [ ] Remove the worktree: `git worktree remove .worktrees/branch-name`
- [ ] Delete the branch: `git branch -d branch-name`
- [ ] Close related issues
- [ ] Update task status via TaskUpdate if working as a team agent

## See Also

- `/pds:verify` — completion self-check (step 1)
- `/pds:merge` — merging subtask worktrees to coordinator
