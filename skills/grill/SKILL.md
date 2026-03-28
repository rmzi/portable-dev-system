---
description: Interrogating requirements to validate before building. Use before swarm decomposition, design decisions on ambiguous features, or when scope creep risk is high.
---
# /grill — Requirement Interrogation

Structured process for validating requirements before implementation. Ambiguous requirements are the #1 source of wasted tokens — a swarm that builds the wrong thing costs 10x more than grilling first.

## Mode

**Plan mode required.** Grill must complete in plan mode (read-only) before any implementation begins. Each step produces explicit written output before advancing to the next. Do not skip steps or combine them — the structured progression prevents premature convergence.

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
- **Error-state risks** — for each major operation, answer:
  - What happens when this operation fails mid-execution?
  - What partial state is left behind? Is it detectable? Is it recoverable?
  - Is there a rollback strategy? What does it cost?
  - What is the recovery path for the user or system?

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

### 9. Scope Enumeration
Before proceeding to implementation planning, enumerate the full blast radius:
- **Search pass.** Use Grep/Glob to find ALL files, functions, and patterns affected by the planned change.
- **List explicitly.** Write out every file path and occurrence count. No "and similar files" — list them all.
- **Cross-reference.** Check that acceptance criteria cover every affected file/pattern.
- **No implementation until enumeration is complete.** Partial changes (fixing 3 of 5 occurrences) are worse than no change.

### 10. Swarm Decision + Tier

Based on the validated requirements, decide execution strategy:

**No-swarm when:**
- Changes stay within a single module or boundary
- No parallelism opportunity — changes are sequential/dependent
- Single agent can complete in ~30 turns or less

**Swarm when** changes cross module boundaries or benefit from parallel execution. Select tier:

**Lite** — routine, pattern-following:
- Crosses 2 modules but follows existing patterns (add X like existing Y)
- Low ambiguity — requirements clear after steps 1-9
- No new interfaces between modules
- Example: new API endpoint + tests when many similar endpoints exist

**Med** — non-trivial, multi-boundary:
- Crosses 2-3 architecture boundaries
- Moderate complexity — some design decisions needed
- May add new interfaces within existing conventions
- Example: new feature touching API + database + frontend

**Heavy** — complex, high-stakes:
- Crosses 3+ architecture boundaries
- Requires new interfaces or contracts between modules
- Refactors a core abstraction other code depends on
- Significant risk items identified in step 6
- Example: replacing an auth system, new data pipeline, major API redesign

**Output:** Explicit `Recommendation: swarm (tier: lite)` or `swarm (tier: med)` or `swarm (tier: heavy)` or `no-swarm` — with rationale. If swarm, include a decomposition outline (task count, boundaries, dependencies).

## Output

A validated problem statement containing:
- Restated problem (1-2 sentences)
- Scope boundary (in/out lists)
- Acceptance criteria (verifiable)
- Constraints and assumptions (explicit)
- Priority ranking (must/should/could)
- Scope enumeration (affected files/patterns with counts)
- Swarm decision with tier (swarm + lite/med/heavy, or no-swarm, with rationale)

This feeds directly into `/pds:swarm` Phase 1 tier initialization and Phase 2 decomposition.

## See Also

- `/pds:swarm` — Phase 1 runs /grill before decomposition
