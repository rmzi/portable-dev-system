---
description: Quick reference for PDS skills, agents, and conventions
---
# /quickref — PDS Quick Reference

## Skills

| Skill | Trigger |
|-------|---------|
| `/ethos` | Starting work, when stuck |
| `/commit` | Before any git commit |
| `/review` | Before submitting or reviewing PRs |
| `/debug` | When troubleshooting |
| `/test` | Writing or running tests |
| `/design` | Architecture decisions |
| `/worktree` | Branch isolation, parallel work |
| `/merge` | Merging subtask worktrees back |
| `/bump` | Version bump + changelog |
| `/permission-router` | Hook policy, subagent routing |
| `/team` | Agent roster, roles |
| `/swarm` | Multi-agent parallel work |
| `/grill` | Requirement interrogation |
| `/contribute` | PDS contribution workflow |
| `/trim` | Context efficiency |
| `/quickref` | This reference |

## Agents

| Agent | Model | Mode | Role |
|-------|-------|------|------|
| orchestrator | opus | delegate | Team lead, dispatches agents |
| researcher | sonnet | plan | Read-only codebase exploration |
| worker | sonnet | acceptEdits | Implementation in worktrees |
| validator | sonnet | acceptEdits | Merge, test, verify |
| reviewer | sonnet | plan | Code review |
| documenter | sonnet | acceptEdits | Documentation |
| scout | haiku | plan | PDS meta-improvements |
| auditor | sonnet | plan | Quality analysis |

## Worktrees

```bash
git worktree add .worktrees/name -b branch    # Create
git worktree remove .worktrees/name           # Remove
git worktree list                             # List all
git worktree prune                            # Clean stale
git branch --merged main | xargs git branch -d  # Delete merged branches
```

Convention: `project/.worktrees/{branch-as-dashes}/` — never `../`, never `/tmp`.

## Commit Format

```
<type>(<scope>): <subject>
```

Types: `feat` `fix` `refactor` `test` `docs` `chore` `perf`

## Version Bump

```bash
# VERSION file + CHANGELOG.md in one commit
# chore: bump version to X.Y.Z
```

Semver: MAJOR (breaking) | MINOR (features) | PATCH (fixes)
