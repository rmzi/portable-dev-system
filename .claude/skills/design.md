---
description: Create and review Architecture Decision Records (ADRs)
---
# /design — Architecture Decision Records

Capture decisions when they're made, with context for future readers (including future you).

## Invocation

```
/design [topic]              # Create new ADR
/design list                 # List existing ADRs
/design review [adr-number]  # Review an ADR
```

## ADR Format

Store in `docs/adr/` or `adr/` directory.

Filename: `NNNN-brief-description.md`

```markdown
# NNNN. Title

Date: YYYY-MM-DD
Status: proposed | accepted | deprecated | superseded by [NNNN]

## Context

What is the issue we're facing? What forces are at play?
Describe the situation without judgment.

## Decision

What is the change we're proposing or have agreed to?
State it clearly and directly.

## Consequences

What becomes easier or harder because of this decision?
Both positive and negative outcomes.
```

## When to Write an ADR

Write an ADR when:
- Choosing between multiple valid approaches
- Making a decision that's hard to reverse
- Future developers might ask "why did we...?"
- You're having a debate that should be settled once

Don't write an ADR for:
- Obvious choices
- Easily reversible decisions
- Implementation details

## Decision-Making Framework

1. **Define** — What problem? What constraints?
2. **Options** — List 2-4 alternatives. Include "do nothing" if valid.
3. **Evaluate** trade-offs:

| Criteria | Option A | Option B | Option C |
|----------|----------|----------|----------|
| Complexity | Low | Medium | High |
| Cost | $$ | $ | $$$ |
| Team familiarity | High | Low | Medium |
| Reversibility | Easy | Hard | Medium |

4. **Decide** — Pick one. Document why. Move on.
5. **Record** — Write the ADR. Link in relevant code comments.

## Anti-Patterns

- **Analysis paralysis** — Deciding not to decide
- **Resume-driven development** — Choosing tech for personal learning
- **Golden hammer** — Using familiar solution for every problem
- **Design by committee** — Consensus without ownership
- **Astronaut architecture** — Solving problems you don't have
