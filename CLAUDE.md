# Portable Development System

Terminal-first, AI-assisted dev methodology using worktrees for isolation.

## Skills System (MANDATORY)

**CRITICAL: Skills in `.claude/skills/` contain workflow patterns and requirements. Skipping relevant skills leads to inconsistent implementations and rework.**

### Workflow

1. **At session start**:
   - Check `.claude/.pds-version` against https://raw.githubusercontent.com/rmzi/portable-dev-system/main/VERSION
   - If outdated: run `pds-update`, commit the changes, and create a PR (or add to existing PR)
   - Scan `.claude/skills/*.md` to understand available capabilities
2. **Before any task**: Check if the task matches a skill (commit, review, debug, test, design, etc.)
3. **During work**: Read and follow the skill documentation before performing the action
4. **When stuck**: Read `/ethos` for principles, `/debug` for systematic troubleshooting

### Rule

**Before performing ANY action, check if a skill exists for it. If a relevant skill exists, read it FIRST.**

### Available Skills

| Skill | When to Use |
|-------|-------------|
| `/ethos` | Starting work, when stuck, need principles |
| `/commit` | Before any git commit |
| `/review` | Before submitting or reviewing PRs |
| `/debug` | When troubleshooting issues |
| `/test` | Writing or running tests |
| `/design` | Architecture decisions, new features |
| `/worktree` | Branch isolation, parallel work |
| `/merge` | Merging subtask worktrees back to coordinator |
| `/bump` | Version bump and changelog update |
| `/quickref` | Command reference |

---

## Key Commands

- `wt` - Pick worktree, open in tmux layout
- `wt -b feature/x` - Create new worktree + branch
- `wts` - Global session picker (from anywhere)
- `clauder` - Resume Claude session for current directory

---

## Rules

**NEVER clone the repository.** Always use git worktrees for isolation:
- Need a new branch? Use `git worktree add` or `wt -b branch`
- Need to work on existing branch? Use `git worktree add` or `wt branch`
- Cloning creates disconnected copies. Worktrees share git history and stay in sync.

**NEVER use /tmp for code or worktrees.** Worktrees go in the project's parent directory:
- Correct: `../project-feature-branch/`
- Wrong: `/tmp/project/` or `/tmp/feature-work/`
- /tmp is only for temporary files (downloads, build artifacts, large files that shouldn't persist)
