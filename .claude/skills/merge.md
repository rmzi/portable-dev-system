---
description: Merge subtask worktrees back into a coordinator branch
disable-model-invocation: true
---
# /merge — Subtask Worktree Coordination

Merge work from parallel subtask worktrees back into a coordinator branch using rebasing for clean history.

## When to Use

- Subtask worktrees need to merge back into a coordinator branch
- Multiple agents completed parallel work off a shared base

---

## Single Subtask Merge

1. Subtask completes work (`/commit`), rebases onto coordinator: `git rebase coordinator-branch`
2. Run tests to verify rebase
3. Coordinator reviews (`/review`)
4. Fast-forward merge: `git merge --ff-only subtask-branch`
5. Clean up: `git worktree remove .worktrees/subtask && git branch -d subtask-branch`

---

## N Subtask Merge

### Setup

```bash
git worktree add .worktrees/feature-big -b feature/big-feature
git worktree add .worktrees/subtask-1 -b feature/big-feature/subtask-1 feature/big-feature
git worktree add .worktrees/subtask-2 -b feature/big-feature/subtask-2 feature/big-feature
```

### Workflow

1. **Establish merge order** — foundational changes first, then by size (smaller first)
2. **First subtask merges** — rebase onto coordinator, run tests, `git merge --ff-only` from coordinator
3. **Remaining subtasks rebase** onto updated coordinator, resolve their own conflicts, run tests
4. **Repeat** until all subtasks merged
5. **Final verification** — full test suite on coordinator branch

### The Pattern

```
Round 1: S1 rebases + merges → S2..SN rebase
Round 2: S2 rebases + merges → S3..SN rebase
...
Round N: SN rebases + merges → Done.
```

---

## Conflict Resolution

**The merging subtask owns their conflicts.** Resolve, test, continue. If too complex, discuss with coordinator before proceeding.

---

## Review Strategy

### Before Merge
- Subtask provides clear summary of changes
- Spot-check critical paths: auth, data handling, public APIs, config

### During Merge
- Run tests after each merge
- Check for unintended interactions in shared state

### After All Merges
- Full test suite on coordinator branch
- Review combined diff against base
- Trust but verify: passing tests + coherent diff = sound work

Git commands: See `/quickref`

---

## Anti-Patterns

| Avoid | Instead |
|-------|---------|
| Merge commits instead of rebase | Rebase then fast-forward merge |
| Skipping tests between merges | Test after every rebase and merge |
| All subtasks merging simultaneously | Follow established merge order |
| Coordinator resolving subtask conflicts | Subtask owner resolves their own |
| Merging without a summary | Require clear change summaries |
| Leaving worktrees after merge | Remove worktrees and branches post-merge |
| Rebasing onto outdated coordinator | Fetch/pull coordinator before rebasing |
