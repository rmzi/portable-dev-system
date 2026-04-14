---
description: Save a checkpoint — bump version, commit, push. Use when work is complete and ready to ship without the full finish protocol.
---
# /checkpoint — Save Point

Quick finalization workflow. Ships work with a version bump in one command. Use when the full `/finish` protocol (rebase, squash, verify) isn't needed — the work is already clean and tested.

## Invocation

```
/checkpoint                          # Auto-detect bump type + commit + push
/checkpoint patch                    # Bump patch + commit + push
/checkpoint minor                    # Bump minor + commit + push
/checkpoint major                    # Bump major + commit + push
/checkpoint patch "feat: add scoring"  # Explicit commit message for work changes
```

## Workflow

### 1. Commit Work

If uncommitted changes exist (staged or unstaged):

- Stage changes: `git add` relevant files (not `-A` — be deliberate)
- Commit with provided message, or derive from branch name and changes
- Use conventional commit format: `<type>(<scope>): <subject>`

If working tree is clean, skip to step 3.

### 2. Detect Bump Type (if not specified)

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

- If multiple rules match, use the highest precedence (major > minor > patch).
- If no conventional commits are found, default to **patch** (most conservative).
- Only ask the user for clarification if the log contains a mix that makes intent genuinely ambiguous.

### 3. Bump Version

Follow `/pds:bump` protocol:

1. Detect version file (VERSION, package.json, etc.)
2. Calculate new version based on bump type
3. Update version file(s) + CHANGELOG.md
4. Commit: `chore: bump version to X.Y.Z`

### 4. Push

**Protected branch check.** Before pushing, check if the target branch is protected:

1. Read CLAUDE.md for a `Protected Branches` section listing branch patterns (e.g., `main`, `release/*`)
2. If the current branch or push target matches a protected pattern, **prompt the user** for confirmation before pushing. Do not silently block — explain which branch is protected and ask to proceed.
3. If no `Protected Branches` section exists in CLAUDE.md, no branches are protected — push freely.

```bash
git push origin HEAD
```

### 5. PR

Create or update a PR targeting main:

```bash
gh pr create --fill    # Create if none exists
gh pr view             # Show existing PR
```

## Rules

1. **Bump type is optional** — omit to auto-detect from conventional commits; patch is the conservative default.
2. **Work commit is separate from bump commit** — clean git history.
3. **No `git add -A`** — stage files deliberately to avoid committing secrets or artifacts.
4. **Push includes both commits** — work + version bump ship together.

## When to Use

| Situation | Skill |
|-----------|-------|
| Quick ship: work done, bump and push | `/checkpoint` |
| Formal ship: rebase, squash, verify, PR | `/finish` |
| Version bump only (no push) | `/bump` |
| Verify before shipping | `/verify` then `/checkpoint` |

## After Checkpoint

After shipping, consider running `/pds:pause` — shipping is a natural break point. It saves session state so you can resume cleanly in the next session.

## See Also

- `/pds:bump` — version bump details
- `/pds:finish` — formal branch completion protocol
- `/pds:verify` — completion self-check
- `/pds:pause` — save session state before stepping away
