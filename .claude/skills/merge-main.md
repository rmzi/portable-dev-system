---
description: Merging approved PRs into the main branch. Use when open PRs are approved and ready to land on main.
disable-model-invocation: true
---
# /merge-main — Merge to Main

Land approved PRs on the main branch safely.

## When to Use

- Open PRs are approved and CI is green
- A release needs to ship
- Cleaning up after a swarm consolidation

## Workflow

1. **Confirm context** — verify current branch and worktree path
2. **List open PRs** — `gh pr list`
3. **For each approved PR**:
   - Check merge status: `gh pr checks <number>`
   - Merge: `gh pr merge <number> --merge` (or `--squash` / `--rebase` per project convention)
4. **Push main** — `git push origin main`
5. **Summarize** — list what was merged

## Safety Checks

- Never force-push main
- Never merge PRs that haven't passed CI
- If conflicts exist, resolve in a separate branch first — never resolve directly on main
- Confirm the worktree is on `main` before pushing

## See Also

- `/merge` — merging subtask worktrees back to coordinator (different scope)
- `/review` — pre-merge code review
- `/commit` — commit format for merge commits
