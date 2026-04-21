# Skills Catalog

Skills encode team knowledge and workflows. Claude reads and follows them automatically. PDS skills are namespaced with `pds:` prefix.

## Plugin Skills (19)

| Skill | Purpose | When to Use |
|-------|---------|-------------|
| `/pds:swarm` | Multi-agent team workflow (6-phase Agentic SDLC, lite/med/heavy tiers, branch merging) | Launching multi-agent parallel work |
| `/pds:team` | Agent roster, coordination, and dispatch modes | Agent roles, permissions, dispatch mode selection |
| `/pds:grill` | Requirement interrogation | Before decomposition, ambiguous features |
| `/pds:verify` | Completion self-check | Before declaring tasks done, creating PRs |
| `/pds:finish` | Branch completion protocol (includes quick ship) | When branch needs preparation for merge, or quick ship |
| `/pds:checkpoint` | Quick ship: bump, commit, push | Finish protocol overkill — just ship what's ready |
| `/pds:worktree` | Git worktree workflow | Branch isolation, parallel work |
| `/pds:contribute` | PDS contribution workflow | Before modifying PDS artifacts |
| `/pds:bugfix` | Test-first bug fix loop | When a bug needs a verified fix |
| `/pds:bump` | Version and changelog updates | Releasing new versions |
| `/pds:eval` | Skill evaluation and testing | After skill changes, periodic review, model upgrades |
| `/pds:rebase` | Focused branch rebase | Updating feature branch with upstream changes |
| `/pds:pr-review` | Address PR review comments | PR has review feedback to resolve |
| `/pds:pause` | Save session state, WIP commit, resume later | Stopping work mid-session, context preservation |
| `/pds:triage` | Triage insights into GitHub issues across repos | After running /insights, converting analysis into tracked work |
| `/pds:ethos` | Core development principles — grounding ritual | Starting significant work, feeling stuck, needing clarity |
| `/pds:instinct` | Pattern lifecycle — record, validate, promote recurring patterns | Observed a pattern, post-swarm scout review, promotion threshold reached |
| `/pds:export` | Export session to human-readable markdown | Saving, reviewing, or sharing a conversation transcript |
| `/pds:explore` | Structural codebase queries via codebase-memory-mcp index | Orienting in a codebase — prefer over blind Grep when an index exists |

---

## Creating Custom Skills

See [docs/teams.md](teams.md) for skill format, frontmatter schema, and examples.
