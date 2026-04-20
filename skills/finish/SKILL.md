---
description: Completing a development branch for merge readiness. Use when implementation and tests pass and the branch needs formal preparation for review and merge.
---
# /finish — Branch Completion Protocol

The gap between "code works" and "branch is ready" is where quality lives. This protocol ensures branches are clean, tested, and reviewable.

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

### 6. Extract Knowledge

If `.claude/swarm/` exists in the current worktree, preserve ephemeral state as its own commit before shipping:

1. **Archive artifacts to git.** Copy all `*.md` files from `.claude/swarm/` to `docs/swarm-reports/<YYYY-MM-DD-HHmm>/`:
   ```bash
   REPORT_DIR="docs/swarm-reports/$(date +%Y-%m-%d-%H%M)"
   mkdir -p "$REPORT_DIR"
   cp .claude/swarm/*.md "$REPORT_DIR/"
   git add "$REPORT_DIR"
   git commit -m "chore: archive swarm artifacts to docs/swarm-reports"
   ```
2. **Distill to auto-memory.** Review the archived artifacts and write **1-2** auto-memory entries (project or feedback type) capturing:
   - WHY key decisions were made and what alternatives were rejected
   - Surprising findings or constraints discovered during the swarm
   - Skip anything derivable from code, git history, or existing docs

Auto-memory writes happen outside git (under `~/.claude/projects/`) and survive worktree removal automatically.

Extraction lives here — after the branch is clean and audited, before ship — so the archive commit is atomic and reviewable in the PR, never mixed into a verify/rebase/clean step. If `.claude/swarm/` does not exist, skip to Step 7.

### 7. Ship

Bump, commit, push, and create/update PR.

**Protected branch check.** Before pushing, check if the target branch is protected:

1. Read CLAUDE.md for a `Protected Branches` section listing branch patterns (e.g., `main`, `release/*`)
2. If the current branch or push target matches a protected pattern, **prompt the user** for confirmation before pushing
3. If no `Protected Branches` section exists in CLAUDE.md, no branches are protected — push freely

#### 7a. Commit Work

If uncommitted changes exist (staged or unstaged):
- Stage changes: `git add` relevant files (not `-A` — be deliberate)
- Commit with provided message, or derive from branch name and changes
- Use conventional commit format: `<type>(<scope>): <subject>`

If working tree is clean, skip to 7b.

#### 7b. Detect Bump Type (if not specified)

If no bump type was passed, scan git log since the last version tag:

```bash
git log $(git describe --tags --abbrev=0 2>/dev/null)..HEAD --oneline 2>/dev/null || git log --oneline
```

Apply the highest-precedence rule found:

| Commit prefix | Bump type |
|---------------|-----------|
| `BREAKING CHANGE` in body, or `!` after type (e.g. `feat!:`) | major |
| `feat:` | minor |
| `fix:`, `perf:`, `refactor:`, etc. | patch |

Default to **patch** if no conventional commits found.

#### 7c. Bump Version

Follow `/pds:bump` protocol:
1. Detect version file (VERSION, package.json, etc.)
2. Calculate new version based on bump type
3. Update version file(s) + CHANGELOG.md
4. Commit: `chore: bump version to X.Y.Z`

#### 7d. Push and PR

```bash
git push origin HEAD
gh pr create --fill    # Create if none exists
gh pr view             # Show existing PR
```

Work commit is separate from bump commit — clean git history.

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
| Quick ship: bump, commit, push | `/pds:checkpoint` |
| Version bump only (no push) | `/pds:bump` |
| Verify before shipping | `/pds:verify` then `/finish` |

## After Shipping

After shipping, consider running `/pds:pause` — shipping is a natural break point. It saves session state so you can resume cleanly in the next session.

## See Also

- `/pds:bump` — version bump details
- `/pds:verify` — completion self-check (step 1)
- `/pds:pause` — save session state before stepping away
