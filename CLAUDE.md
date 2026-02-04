# Portable Development System

Terminal-first, AI-assisted dev methodology using worktrees for isolation.

## Skills System (MANDATORY)

**CRITICAL: Skills in `.claude/skills/` contain workflow patterns and requirements. Skipping relevant skills leads to inconsistent implementations and rework.**

### Workflow

1. **At session start**: Scan `.claude/skills/*.md` to understand available capabilities
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
| `/bootstrap` | New project setup |
| `/quickref` | Command reference |

---

## Key Commands

- `wty` / `wtyg` - Open worktree in tmux layout
- `wta -b feature/x` - Create new worktree + branch
- `clauder` - Resume Claude session for current directory
