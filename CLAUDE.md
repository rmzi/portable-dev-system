<!-- PDS:START -->
# Portable Development System

AI-assisted development methodology. Skills for consistency. Agents for scale.

## Skills System (MANDATORY)

**CRITICAL: Skills in `.claude/skills/` contain workflow patterns and requirements. Skipping relevant skills leads to inconsistent implementations and rework.**

### Workflow

1. **At session start**:
   - Check `.claude/.pds-version` against https://raw.githubusercontent.com/rmzi/portable-dev-system/main/VERSION
   - If outdated: re-run `install.sh` (or `pds-update` if available), commit changes, and create a PR (or add to existing PR)
   - Scan `.claude/skills/` to understand available capabilities
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
| `/permission-router` | Permission hook policy, subagent routing |
| `/team` | Agent roster, roles, capabilities |
| `/swarm` | Launch agent team for parallel work |
| `/quickref` | PDS skills, agents, and conventions reference |
| `/instinct` | Record, review, and promote engineering patterns |
| `/grill` | Requirement interrogation before implementation |
| `/contribute` | Contributing to PDS itself — whitepaper alignment |
| `/audit-config` | Verify PDS setup is correct and secure |
| `/trim` | Context efficiency maintenance |


---

## Rules

**NEVER clone the repository.** Always use git worktrees for isolation:
- Need a new branch? Use `git worktree add`
- Cloning creates disconnected copies. Worktrees share git history and stay in sync.

**Send denied commands to the terminal.** When a command is blocked by permissions (force push, etc.) or otherwise requires manual action, don't just print it — send it to the user's terminal pane via `tmux send-keys -t 2 'command' ''` (no Enter, so the user can review before executing).

**Read terminal output to stay current.** After sending commands to tmux or when you need to know the state of the user's environment, read the terminal pane:
- `tmux capture-pane -t 2 -p` — read current visible content from the terminal pane
- Use this after sending a denied command to check if the user executed it and what happened
- Use this when the user references terminal output or you need to verify external state

**NEVER use /tmp for code or worktrees.** Worktrees go inside the repo at `.worktrees/`:
- Correct: `.worktrees/feature-branch/` (inside the main repo)
- Wrong: `/tmp/project/` or `/tmp/feature-work/`
- Wrong: `../project-feature-branch/` (old sibling format — migrate with `git worktree move`)
- /tmp is only for temporary files (downloads, build artifacts, large files that shouldn't persist)

**Read `/contribute` before modifying PDS.** Before changing skills, agents, SDLC phases, or coordination patterns, read `/contribute` for the full checklist — including whitepaper alignment.

**Create or update a PR after pushing.** When commits are pushed to a non-main branch, create a PR (or update the existing one). Don't wait to be asked.
<!-- PDS:END -->
