---
description: Contributing to PDS itself — workflow changes, skills, agents, docs
---
# /contribute — PDS Contribution Workflow

Process for modifying PDS itself. PDS is a living system — skills, agents, and the whitepaper co-evolve. Changes to one often require updates to others.

## When to Use

- Adding or modifying skills
- Changing agent definitions or coordination patterns
- Updating SDLC phases or workflow structure
- Any change that affects how PDS operates

## Checklist

### 1. Read the whitepaper
Read `docs/whitepaper.md` before changing workflow. The whitepaper is the source of truth for the Agentic SDLC model. Your change must align with it — or update it.

### 2. Make your changes
Implement the feature, fix, or improvement.

### 3. Update the whitepaper if needed
If your change affects any of these, update `docs/whitepaper.md`:
- **SDLC phases** — phase descriptions, inputs, outputs, transitions
- **Agent model** — roles, tiers, spawning guidance, phase mappings
- **Coordination patterns** — task DAGs, communication, file protocol
- **Instruction architecture** — how context reaches agents (passive vs explicit)
- **Glossary** — new terms or changed definitions

Not every PDS change needs a whitepaper update. Skip it for:
- Bug fixes that don't change behavior
- Cosmetic/formatting changes
- Settings or permissions tweaks
- Changes to tooling that don't affect the model

### 4. Update cross-references
When adding a skill or agent, update all reference points:
- `CLAUDE.md` — skills table
- `README.md` — skills table
- `/team` — if agent changes
- `/swarm` — if workflow phase changes
- `docs/skills.md` — skills catalog
- Glossary in `docs/whitepaper.md` — if new terms introduced

### 5. Bump version
Run `/bump` with the appropriate level:
- **patch** — bug fixes, minor doc updates
- **minor** — new skills, agent changes, whitepaper updates
- **major** — breaking changes to skill interfaces or agent contracts

## See Also

- `/bump` — Version bump and changelog
- `/commit` — Semantic commit format
- `/review` — Code review before PR
