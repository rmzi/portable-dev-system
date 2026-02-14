---
description: Merge subtask worktrees back into a coordinator branch
disable-model-invocation: true
---
# /merge — Subtask Worktree Coordination

Merge work from parallel subtask worktrees back into a coordinator branch, one at a time, with rebasing to keep history clean.

## Why a Merge Skill?

When a coordinator kicks off multiple subtasks as worktrees, getting their work back together is the hardest part. Without a consistent methodology:
- Merge conflicts compound unpredictably
- Integration issues hide until the end
- No one knows whose turn it is to merge
- The coordinator can't review every line from every subagent

This skill provides an ordered, rebasing-first approach that keeps the coordinator branch clean and catches integration issues early.


##When to Use

- A coordinator branch has spawned subtask worktrees that need to merge back
- Multiple agents have completed parallel work on branches off a shared base
- You need to integrate work from one or more subtasks into a parent branch


##Concepts

| Term | Meaning |
|------|---------|
| **Coordinator branch** | The base branch that subtasks branch from and merge back into |
| **Subtask branch** | A worktree/branch created for isolated parallel work off the coordinator |
| **Merge order** | The agreed sequence in which subtasks merge back |
| **Rebase round** | After each merge, all remaining subtasks rebase onto the updated coordinator |


##Single Subtask Merge

The simple case: one subtask merging back into the coordinator.

### Workflow

1. **Subtask completes work** and ensures all commits are clean (`/commit`)
2. **Subtask rebases onto coordinator**
   ```bash
   # In the subtask worktree
   git fetch origin
   git rebase origin/coordinator-branch
   # or if working locally:
   git rebase coordinator-branch
   ```
3. **Run tests** to verify nothing broke during rebase
4. **Coordinator reviews** the subtask's changes (`/review`)
5. **Fast-forward merge** into the coordinator branch
   ```bash
   # In the coordinator worktree
   git merge --ff-only subtask-branch
   ```
6. **Clean up** the subtask worktree
   ```bash
   REPO_ROOT="$(git rev-parse --path-format=absolute --git-common-dir | sed 's|/.git$||')"
   git worktree remove "$REPO_ROOT/.worktrees/subtask-branch"
   git branch -d subtask-branch
   ```


##N Subtask Merge

The complex case: multiple subtasks merging back in sequence.

### Setup

The coordinator creates a base branch. Subtasks branch off from it as worktrees:

```bash
REPO_ROOT="$(git rev-parse --path-format=absolute --git-common-dir | sed 's|/.git$||')"

# Coordinator creates the base
git worktree add "$REPO_ROOT/.worktrees/feature-big" -b feature/big-feature

# Subtasks branch off the coordinator
git worktree add "$REPO_ROOT/.worktrees/subtask-1" -b feature/big-feature/subtask-1 feature/big-feature
git worktree add "$REPO_ROOT/.worktrees/subtask-2" -b feature/big-feature/subtask-2 feature/big-feature
git worktree add "$REPO_ROOT/.worktrees/subtask-3" -b feature/big-feature/subtask-3 feature/big-feature
```

### Workflow

1. **Establish merge order** before anyone starts merging
   - Subtasks agree on a sequence (e.g., subtask-1, subtask-2, subtask-3)
   - Order by dependency: foundational changes first, dependent work later
   - If no dependency, order by size: smaller changes first (less conflict surface)

2. **First subtask merges** (conflict-free since base hasn't changed)
   ```bash
   # In subtask-1 worktree
   git rebase feature/big-feature
   # Run tests

   # In coordinator worktree
   git merge --ff-only feature/big-feature/subtask-1
   ```

3. **Remaining subtasks rebase** onto the updated coordinator
   ```bash
   # In subtask-2 worktree
   git rebase feature/big-feature
   # Resolve any conflicts (subtask-2 owns their conflicts)
   # Run tests

   # In subtask-3 worktree
   git rebase feature/big-feature
   # Resolve any conflicts (subtask-3 owns their conflicts)
   # Run tests
   ```

4. **Next subtask merges**, repeat rebase for remaining
   ```bash
   # In coordinator worktree
   git merge --ff-only feature/big-feature/subtask-2

   # In subtask-3 worktree
   git rebase feature/big-feature
   # Resolve conflicts, run tests
   ```

5. **Last subtask merges**
   ```bash
   # In coordinator worktree
   git merge --ff-only feature/big-feature/subtask-3
   ```

6. **Final verification** — run full test suite on the coordinator branch

7. **Clean up** all subtask worktrees and branches

### The Pattern

```
Merge order: [S1, S2, S3, ... SN]

Round 1: S1 rebases onto coordinator (conflict-free), merges
         S2..SN rebase onto updated coordinator
Round 2: S2 rebases onto coordinator, merges
         S3..SN rebase onto updated coordinator
...
Round N: SN rebases onto coordinator, merges
         Done.
```


##Conflict Resolution

**The subtask that is merging owns their conflicts.**

When a rebase produces conflicts:

1. The subtask developer resolves them — they understand their changes best
2. After resolving, run the full test suite
3. If conflicts are too complex, the subtask developer and coordinator discuss before proceeding
4. Never force through a conflict resolution without testing

```bash
# During rebase, conflicts appear
git rebase feature/big-feature
# CONFLICT in src/module.js

# Resolve the conflict
# Edit the file, choose the right combination

git add src/module.js
git rebase --continue

# Run tests to verify
```


##Review Strategy

A coordinator cannot review every line from every subagent. Instead:

### Before Merge
- **Subtask provides a clear summary** of what changed and why
- **PR descriptions serve as documentation** — they should explain intent, not just list files
- **Spot-check critical paths** — auth, data handling, public APIs, configuration changes

### During Merge
- **Run tests after each merge** — the test suite is your primary integration check
- **Check for unintended interactions** — especially shared state, global config, overlapping file changes

### After All Merges
- **Run the full test suite** one final time on the coordinator branch
- **Review the combined diff** from coordinator branch against its base
- **Trust but verify** — if tests pass and the combined diff looks coherent, the individual work was sound


##Git Commands Reference

```bash
# Rebase subtask onto coordinator
git rebase coordinator-branch

# Interactive rebase to clean up commits before merging
git rebase -i coordinator-branch

# Fast-forward merge (coordinator worktree)
git merge --ff-only subtask-branch

# Abort a rebase if things go wrong
git rebase --abort

# Continue rebase after resolving conflicts
git add <resolved-files>
git rebase --continue

# Check what would conflict before rebasing
git log --oneline coordinator-branch..subtask-branch
git diff coordinator-branch...subtask-branch -- <file>

# Clean up after merge
REPO_ROOT="$(git rev-parse --path-format=absolute --git-common-dir | sed 's|/.git$||')"
git worktree remove "$REPO_ROOT/.worktrees/subtask-branch"
git branch -d subtask-branch
```


##Anti-Patterns

| Avoid | Why | Instead |
|-------|-----|---------|
| Merge commits instead of rebase | Pollutes history, makes bisect harder | Rebase then fast-forward merge |
| Skipping tests between merges | Integration bugs hide and compound | Run tests after every rebase and merge |
| All subtasks merging simultaneously | Conflicts multiply, no clear ownership | Establish and follow merge order |
| Coordinator resolving subtask conflicts | They lack context on the subtask's intent | Subtask owner resolves their own conflicts |
| Merging without a summary | Coordinator can't meaningfully review | Require clear change summaries or PR descriptions |
| Leaving worktrees after merge | Stale worktrees clutter the workspace | Remove worktrees and delete branches after merge |
| Rebasing onto an outdated coordinator | Creates false confidence about conflict-free state | Always fetch/pull coordinator before rebasing |


##Cleanup

After all subtasks are merged:

```bash
REPO_ROOT="$(git rev-parse --path-format=absolute --git-common-dir | sed 's|/.git$||')"

# Remove each subtask worktree
git worktree remove "$REPO_ROOT/.worktrees/subtask-1"
git worktree remove "$REPO_ROOT/.worktrees/subtask-2"
git worktree remove "$REPO_ROOT/.worktrees/subtask-3"

# Delete the subtask branches
git branch -d feature/big-feature/subtask-1
git branch -d feature/big-feature/subtask-2
git branch -d feature/big-feature/subtask-3

# Prune any stale worktree references
git worktree prune
```
