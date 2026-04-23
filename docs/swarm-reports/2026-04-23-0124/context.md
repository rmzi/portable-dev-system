# Swarm Context: Ship All 30 Open Issues

## Plan Summary
Ship all 30 open GitHub issues in one consolidated PR. ~15 issues are already implemented and need verify-and-close. 8 SDLC phase gap issues (#101-108) are the core work — improving the 6-phase swarm model. 3 research issues produce design docs only.

## Tier
Heavy — crosses 4+ architecture boundaries, modifies core SDLC phase model.

## Key Decisions
1. **Auditor per-phase** — orchestrator can skip only if truly unnecessary
2. **Cleanup is a sub-phase of Phase 6** — not a new Phase 7
3. **Artifact archival** → `docs/swarm-reports/<timestamp>/`
4. **Implement-where-easy** for hooks — if < 50 lines, implement; otherwise document only
5. **One consolidated PR** for all SDLC + docs + research changes
6. **worker-2 owns ALL skill + agent .md files** — no other worker touches them

## Acceptance Criteria
- Each SDLC phase in SKILL.md reflects its issue's proposed solution
- Agent .md files reference new protocols
- No broken cross-references between SKILL.md and agent files
- Phase 6 includes cleanup sub-phase
- Checkpoint protocol documented with JSON schema
- Whitepaper known-gaps updated to "implemented"
- Research docs have: problem, analysis, recommendations, next steps
- At least 12 of 15 verify-close issues actually closed with evidence

## File Ownership
- **worker-1**: GitHub issues only (no file edits)
- **worker-2**: skills/swarm/SKILL.md, agents/*.md
- **worker-3**: hooks/scripts/*.sh, hooks/hooks.json, .claude/settings.json
- **worker-4**: docs/whitepaper.md, CLAUDE.md, README.md
- **researcher**: docs/*.md (new research files only)
