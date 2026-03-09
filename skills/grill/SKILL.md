---
description: Interrogating requirements to validate before building. Use before swarm decomposition, design decisions on ambiguous features, or when scope creep risk is high.
---
# /grill — Requirement Interrogation

Structured process for validating requirements before implementation. Ambiguous requirements are the #1 source of wasted tokens — a swarm that builds the wrong thing costs 10x more than grilling first.

## When to Use

- Before `/pds:swarm` decomposition (Phase 1 references this)
- Before architecture decisions on ambiguous features
- When a task description feels incomplete or assumes too much
- When scope creep risk is high
- When debugging: write your hypothesis before investigating (what you think is happening, evidence that would confirm/disprove)

## Protocol

### 1. Restate
What is the actual problem? Restate in your own words. If you can't, the requirement isn't clear enough.

### 2. Boundary
What's in scope? What's explicitly out? Write both lists. Unstated boundaries become scope creep.

### 3. Success
How will we know it's done? Define verifiable acceptance criteria. "Works correctly" is not a criterion — "returns 200 with valid JWT for registered users" is.

### 4. Constraints
Hard limits that shape the solution:
- Technology (language, framework, existing patterns)
- Time (deadline, token budget)
- Resources (which agents, how many workers)
- Compatibility (APIs, versions, existing interfaces)

### 5. Assumptions
What are we taking for granted? List each assumption explicitly, then challenge it:
- "The database schema won't change" — will it?
- "Tests already cover the adjacent code" — do they?
- "The API contract is stable" — is it documented?

### 6. Risks
What could make this fail?
- Technical risks (integration complexity, performance)
- Requirement risks (ambiguity, missing stakeholder input)
- Dependency risks (blocked by other work, external services)

### 7. Priority
If we can't do everything, what matters most? Rank requirements as:
- **Must** — ship is blocked without this
- **Should** — expected but deferrable
- **Could** — nice to have

### 8. MECE Check
Requirements don't overlap (mutually exclusive) and all cases are covered (collectively exhaustive). Look for:
- Gaps: what happens when X and Y are both true?
- Overlaps: do two requirements contradict each other?
- Edge cases: empty inputs, concurrent access, error states

### 9. Swarm Decision
Based on the validated requirements, decide whether to use a multi-agent swarm or single-agent execution:

**Swarm when:**
- 3+ files across different modules or architecture boundaries
- Parallel-independent subtasks that don't share state
- Multiple architecture boundaries (frontend + backend, API + DB, etc.)

**No-swarm when:**
- 2 or fewer files to modify
- No parallelism opportunity — changes are sequential/dependent
- Single agent can complete in ~30 turns or less

**Output:** Explicit `Recommendation: swarm | no-swarm` with rationale. If swarm, include a decomposition outline (task count, boundaries, dependencies).

## Output

A validated problem statement containing:
- Restated problem (1-2 sentences)
- Scope boundary (in/out lists)
- Acceptance criteria (verifiable)
- Constraints and assumptions (explicit)
- Priority ranking (must/should/could)
- Swarm decision (swarm/no-swarm with rationale)

This feeds directly into `/pds:swarm` Phase 2 decomposition.

## See Also

- `/pds:swarm` — Phase 1 runs /grill before decomposition
