---
description: Completing a development branch for merge readiness. Use when implementation and tests pass and the branch needs formal preparation for review and merge.
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

### 0. Extract Knowledge
If `.claude/swarm/` exists in the current worktree, preserve ephemeral state before it's lost:

1. **Archive artifacts to git.** Copy all `*.md` files from `.claude/swarm/` to `docs/swarm-reports/<YYYY-MM-DD-HHmm>/`:
   ```bash
   REPORT_DIR="docs/swarm-reports/$(date +%Y-%m-%d-%H%M)"
   mkdir -p "$REPORT_DIR"
   cp .claude/swarm/*.md "$REPORT_DIR/"
   git add "$REPORT_DIR"
   ```
2. **Distill to auto-memory.** Review the archived artifacts and write **1-2** auto-memory entries (project or feedback type) capturing:
   - WHY key decisions were made and what alternatives were rejected
   - Surprising findings or constraints discovered during the swarm
   - Skip anything derivable from code, git history, or existing docs
3. The archived reports are included in the finish commit automatically (already staged via `git add`).

If `.claude/swarm/` does not exist, skip to Step 1.

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
Review your commits:

```bash
git log --oneline main..HEAD
```

If there are fixup commits or WIP entries, squash them non-interactively:

```bash
# Squash all branch commits into one clean commit
git reset --soft origin/main
git commit -m "feat(scope): descriptive message"

# Or use autosquash for commits prefixed with fixup!/squash!
git rebase --autosquash origin/main
```

Each commit should be atomic and meaningful. Use conventional commit format: `<type>(<scope>): <subject>`. Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `perf`. Subject in imperative mood, max 72 chars. Body explains *what* and *why*, not *how*.

**Do NOT use `git rebase -i`** — interactive rebase requires terminal input and will hang in agent contexts.

### 4. Run Tests Post-Rebase
Tests must pass *after* rebase, not just before:

```bash
# Run full test suite again
npm test    # or equivalent
```

Rebasing can introduce subtle breakage — verify.

### 5. Permission Audit

Review `.claude/settings.local.json` for permission patterns that should be promoted to `.claude/settings.json`:

1. Read both files
2. Identify glob-style allow patterns in local (e.g., `Bash(git *:*)`, `Bash(gh *:*)`, tool names) that aren't already in project settings
3. Exclude one-off entries (specific file paths, session-specific `rm` commands, temp artifacts)
4. If promotable patterns exist, add them to `.claude/settings.json` `permissions.allow` and remove from `settings.local.json`
5. If no promotable patterns exist, skip — do not modify either file

This ensures permission improvements ship with the code rather than accumulating silently in local settings.

### 6. Ship
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

- `/pds:bcp` — bump, commit, push (step 6)
- `/pds:verify` — completion self-check (step 1)
- `/pds:merge` — merging subtask worktrees to coordinator
