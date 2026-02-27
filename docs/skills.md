# Skills Catalog

Skills encode team knowledge and workflows. Claude reads and follows them automatically. PDS skills are namespaced with `pds:` prefix.

## Plugin Skills (16)

| Skill | Purpose | When to Use |
|-------|---------|-------------|
| `/pds:ethos` | Development principles, MECE | Starting work, when stuck, design decisions |
| `/pds:swarm` | Multi-agent team workflow (6-phase Agentic SDLC) | Launching multi-agent parallel work |
| `/pds:team` | Agent roster and coordination | Agent roles, permissions, file protocol |
| `/pds:grill` | Requirement interrogation | Before decomposition, ambiguous features |
| `/pds:verify` | Completion self-check | Before declaring tasks done, creating PRs |
| `/pds:finish` | Branch completion protocol | When branch needs preparation for merge |
| `/pds:merge` | Merging subtask worktrees back | After subtask branches are ready to consolidate |
| `/pds:worktree` | Git worktree workflow | Branch isolation, parallel work |
| `/pds:instinct` | Pattern capture and lifecycle | Recording, reviewing, and promoting engineering patterns |
| `/pds:sandbox` | OS-level sandbox configuration | Filesystem confinement, network restrictions |
| `/pds:permission-router` | Permission hook routing policy | Subagent permission requests |
| `/pds:audit-config` | Configuration security audit | After install, periodic review |
| `/pds:trim` | Context efficiency maintenance | Reducing skill/agent token footprint |
| `/pds:contribute` | PDS contribution workflow | Before modifying PDS artifacts |
| `/pds:bugfix` | Test-first bug fix loop | When a bug needs a verified fix |
| `/pds:bump` | Version and changelog updates | Releasing new versions |

---

## Creating Custom Skills

See [docs/teams.md](teams.md) for skill format, frontmatter schema, and examples.
