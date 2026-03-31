---
description: Address PR review comments systematically. Use when a PR has review feedback that needs to be resolved with code changes.
---
# /pr-review — Address PR Comments

Fetch PR review comments via `gh`, address each one with code fixes, run tests, commit, and push. Systematic process to ensure no comment is missed.

## When to Use

- After receiving review feedback on a pull request
- When a PR has unresolved comments that need code changes
- When iterating on a PR after reviewer suggestions

## Protocol

### 1. Fetch Comments
```bash
# Get PR number from current branch
PR_NUMBER=$(gh pr view --json number -q '.number')
REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner')

# Fetch all review comments (inline code comments)
gh api repos/$REPO/pulls/${PR_NUMBER}/comments --paginate

# Also fetch general PR comments (top-level discussion)
gh api repos/$REPO/issues/${PR_NUMBER}/comments --paginate

# Check for requested changes
gh pr view $PR_NUMBER --json reviews -q '.reviews[] | select(.state == "CHANGES_REQUESTED") | .body'
```

### 2. Inventory Comments
List every comment with:
- **File and line** — where the comment applies
- **Author** — who made the comment
- **Content** — what they said
- **Status** — resolved/unresolved

Group comments by file for efficient addressing.

### 3. Address Each Comment
For each unresolved comment:
1. Read the relevant code context
2. Understand the reviewer's concern
3. Implement the fix or improvement
4. If you disagree with the suggestion, explain why in a reply rather than silently ignoring it

### 4. Test
Run the project's test suite to confirm changes don't break anything:
```bash
# Run tests (project-specific command)
npm test    # or equivalent
```

### 5. Commit
Commit with a message that references the PR:
```bash
git commit -m "fix: address PR review feedback (#<PR_NUMBER>)

- <summary of change 1>
- <summary of change 2>"
```

### 6. Push
```bash
git push
```

### 7. Report
Summarize what was addressed:
```
## PR Review Response
### Addressed
- `file.ts:42` — [reviewer]: [concern] -> [what you changed]
- `other.ts:15` — [reviewer]: [concern] -> [what you changed]
### Discussed (not changed)
- `file.ts:88` — [reviewer]: [concern] -> [why no change needed]
### Remaining
- [any comments that need further discussion]
```

## Rules

- **Address every comment.** Do not skip or ignore review comments.
- **Commit atomically.** Group related fixes into logical commits, not one giant commit.
- **Test before pushing.** Never push untested changes.
- **Explain disagreements.** If you disagree with a suggestion, reply with reasoning.

## See Also

- `/pds:verify` — Self-check before pushing
- `/pds:finish` — Branch completion protocol
