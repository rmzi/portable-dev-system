# Skills Catalog

Skills encode team knowledge and workflows. Claude reads and follows them automatically. PDS skills are namespaced with `pds:` prefix.

## Plugin Skills (28)

| Skill | Purpose | When to Use |
|-------|---------|-------------|
| `/pds:ethos` | Development principles, MECE | Starting work, when stuck, design decisions |
| `/pds:swarm` | Multi-agent team workflow (6-phase Agentic SDLC, lite/med/heavy tiers) | Launching multi-agent parallel work |
| `/pds:team` | Agent roster and coordination | Agent roles, permissions, file protocol |
| `/pds:grill` | Requirement interrogation | Before decomposition, ambiguous features |
| `/pds:verify` | Completion self-check | Before declaring tasks done, creating PRs |
| `/pds:finish` | Branch completion protocol | When branch needs preparation for merge |
| `/pds:merge` | Merging subtask worktrees back | After subtask branches are ready to consolidate |
| `/pds:worktree` | Git worktree workflow | Branch isolation, parallel work |
| `/pds:instinct` | Pattern capture and lifecycle | Recording, reviewing, and promoting engineering patterns |
| `/pds:sandbox` | OS-level sandbox configuration | Filesystem confinement, network restrictions |
| `/pds:permission-router` | **Deprecated** — see /pds:sandbox | — |
| `/pds:audit-config` | Configuration security audit | After install, periodic review |
| `/pds:trim` | Context efficiency maintenance | Reducing skill/agent token footprint |
| `/pds:contribute` | PDS contribution workflow | Before modifying PDS artifacts |
| `/pds:bugfix` | Test-first bug fix loop | When a bug needs a verified fix |
| `/pds:bump` | Version and changelog updates | Releasing new versions |
| `/pds:eval` | Skill evaluation and testing | After skill changes, periodic review, model upgrades |
| `/pds:inspect` | Real-time PDS state inspection | Checking swarm status, telemetry, agent health |
| `/pds:telemetry` | Usage telemetry management | Enabling/disabling telemetry, viewing reports |
| `/pds:bcp` | Finalize work — bump, commit, push | Quick ship: work done, ready to push |
| `/pds:rebase` | Focused branch rebase | Updating feature branch with upstream changes |
| `/pds:pr-review` | Address PR review comments | PR has review feedback to resolve |
| `/pds:preflight` | Environment validation | Session start, before tests, after branch switch |
| `/pds:pause` | Save session state, WIP commit, resume later | Stopping work mid-session, context preservation |
| `/pds:allow` | Sandbox write allowlist management | Adding paths to sandbox allowlist |
| `/pds:export` | Export session to human-readable markdown | Saving, reviewing, or sharing conversation transcripts |
| `/pds:dispatch` | Agent dispatch mode selection | Choosing between team teammate, fork subagent, or headless |
| `/pds:triage` | Triage insights into GitHub issues across repos | After running /insights, converting analysis into tracked work |

---

## Creating Custom Skills

See [docs/teams.md](teams.md) for skill format, frontmatter schema, and examples.
