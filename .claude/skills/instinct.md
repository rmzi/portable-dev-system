---
description: Record, review, and promote engineering patterns (instincts)
---
# /instinct — Pattern Lifecycle

Instincts are lightweight engineering patterns — observations that accumulate confidence and promote to skills when mature. They live in `.claude/instincts.md` as the project's persistent lexicon.

## Record an Instinct

When you observe a recurring pattern during work:

1. Read `.claude/instincts.md`
2. Check if the pattern already exists — if so, bump `Times seen` and adjust `Confidence`
3. If new, append an entry under `## Instincts`:

```markdown
### [descriptive title]
- **Observed**: [YYYY-MM-DD]
- **Times seen**: 1
- **Confidence**: low
- **Context**: [where/when — e.g., "during API integration swarms"]
- **Pattern**: [what happens — e.g., "workers duplicate auth setup across worktrees"]
- **Action**: [what to do — e.g., "extract shared auth config to a setup script"]
- **Status**: active
```

## Confidence Levels

| Level | Criteria | Next step |
|-------|----------|-----------|
| `low` | Seen 1 time, single context | Validate in future work |
| `medium` | Seen 2 times across different contexts | Continue tracking |
| `high` | Seen 3+ times, consistent pattern | Propose skill promotion |

## Validate Instincts

During post-swarm analysis (Phase 6) or `/scout` runs:

1. Read `.claude/instincts.md`
2. For each `active` instinct, check if it was re-observed
3. If yes: increment `Times seen`, upgrade `Confidence` if threshold met
4. If contradicted: mark `Status: retired` with a note
5. Propose new instincts for patterns not yet captured

## Promote to Skill

When an instinct reaches `high` confidence:

1. Scout flags it in the meta-improvement report under `### Instincts`
2. Scout drafts a skill file in `.claude/skills/` (plan mode — human must approve)
3. After skill is merged, update the instinct: `Status: promoted`
4. Add a note: `Promoted to /skill-name on YYYY-MM-DD`

## Retire an Instinct

Mark `Status: retired` when:
- The pattern was wrong (contradicted by evidence)
- The underlying cause was fixed (pattern no longer occurs)
- The pattern is too context-specific to generalize

## See Also

- `.claude/instincts.md` — instinct storage
- `/swarm` — Phase 6 triggers instinct review
- Scout agent — automates the lifecycle
