# Skills Catalog

Skills encode team knowledge and workflows. Claude reads and follows them automatically.

## Core Skills

| Skill | Purpose | When to Use |
|-------|---------|-------------|
| `/ethos` | Development principles, MECE | Starting work, when stuck, design decisions |
| `/commit` | Semantic commit format | Before any git commit |
| `/review` | Code review checklist | Before submitting or reviewing PRs |
| `/debug` | Systematic debugging process | Troubleshooting issues |
| `/test` | Test strategy and patterns | Writing or running tests |
| `/design` | Architecture decision records | New features, significant changes |
| `/worktree` | Git worktree workflow | Branch isolation, parallel work |
| `/merge` | Merging subtask worktrees back | After subtask branches are ready to consolidate |
| `/permission-router` | Permission hook routing policy | Subagent permission requests, hook configuration |
| `/quickref` | PDS skills, agents, conventions | Quick reference |
| `/swarm` | Multi-agent team workflow with file-based coordination | Launching multi-agent parallel work |
| `/team` | Agent roster and coordination | Agent roles, permissions, file protocol |
| `/trim` | Context efficiency maintenance | Reducing skill/agent token footprint |
| `/instinct` | Pattern capture and lifecycle | Recording, reviewing, and promoting engineering patterns |
| `/audit-config` | Configuration security audit | After install, periodic review, team onboarding |
| `/bump` | Version and changelog updates | Releasing new versions |

---

## Creating Custom Skills

See [docs/teams.md](teams.md) for skill format, frontmatter schema, and examples.
