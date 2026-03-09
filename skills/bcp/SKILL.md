---
description: Finalize work — bump version, commit, push. Use when work is complete and ready to ship.
disable-model-invocation: true
---
# /bcp — Bump, Commit, Push

Quick finalization workflow. Ships work with a version bump in one command.

## Invocation

```
/bcp patch                          # Bump patch + commit + push
/bcp minor                          # Bump minor + commit + push
/bcp major                          # Bump major + commit + push
/bcp patch "feat: add scoring"      # Explicit commit message for work changes
```

## Workflow

### 1. Commit Work

If uncommitted changes exist (staged or unstaged):

- Stage changes: `git add` relevant files (not `-A` — be deliberate)
- Commit with provided message, or derive from branch name and changes
- Use conventional commit format: `<type>(<scope>): <subject>`

If working tree is clean, skip to step 2.

### 2. Bump Version

Follow `/pds:bump` protocol:

1. Detect version file (VERSION, package.json, etc.)
2. Calculate new version based on bump type
3. Update version file(s) + CHANGELOG.md
4. Commit: `chore: bump version to X.Y.Z`

### 3. Push

```bash
git push origin HEAD
```

### 4. PR

Create or update a PR targeting main:

```bash
gh pr create --fill    # Create if none exists
gh pr view             # Show existing PR
```

## Rules

1. **Bump type is required** — no default. Forces intentional versioning.
2. **Work commit is separate from bump commit** — clean git history.
3. **No `git add -A`** — stage files deliberately to avoid committing secrets or artifacts.
4. **Push includes both commits** — work + version bump ship together.

## When to Use

| Situation | Skill |
|-----------|-------|
| Quick ship: work done, bump and push | `/bcp` |
| Formal ship: rebase, squash, verify, PR | `/finish` |
| Version bump only (no push) | `/bump` |
| Verify before shipping | `/verify` then `/bcp` |

## See Also

- `/pds:bump` — version bump details
- `/pds:finish` — formal branch completion protocol
- `/pds:verify` — completion self-check
