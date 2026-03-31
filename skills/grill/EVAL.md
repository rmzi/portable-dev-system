---
skill: grill
---
# Eval: /pds:grill

## Scenarios

### Scenario: Vague performance request
**Setup:** User says "make the API faster" with no metrics, no specific endpoints, no load profile.
**Prompt:** Interrogate this requirement before planning implementation.
**Expected:**
- [ ] Restates the problem in concrete terms
- [ ] Defines scope boundary (which endpoints, what "faster" means)
- [ ] Produces mechanically verifiable criteria (e.g., "p99 < 200ms under 1k concurrent")
- [ ] Lists assumptions and challenges them
- [ ] Performs MECE check on requirements
- [ ] Describes scope enumeration approach (what to search for, where to look) or enumerates affected files/endpoints if codebase is available
**Anti-patterns:**
- [ ] Accepts "make it faster" and starts profiling immediately
- [ ] Produces criteria like "should be noticeably faster" (not verifiable)
- [ ] Skips boundary definition — scope is unbounded
- [ ] Skips scope enumeration entirely (no mention of what files/endpoints to investigate)

### Scenario: Feature with missing edge cases
**Setup:** "Add a delete button to user profiles. Clicking it deletes the user." No mention of: confirmation dialog, admin vs self-delete, cascade behavior, undo.
**Prompt:** Validate these requirements before implementation.
**Expected:**
- [ ] Identifies missing edge cases (confirmation, authorization, cascading)
- [ ] Asks about error states: what if deletion fails mid-cascade? What partial state is left? What is the recovery path?
- [ ] Produces in-scope/out-of-scope lists
- [ ] Ranks requirements by priority (must/should/could)
- [ ] Does NOT start implementing — stays in plan mode throughout
**Anti-patterns:**
- [ ] Implements the delete button without questioning the spec
- [ ] Identifies gaps but doesn't produce verifiable acceptance criteria
- [ ] Skips MECE check
- [ ] Skips error-state analysis for the deletion operation

### Scenario: Tier selection for cross-module feature
**Setup:** User says "add user notification preferences — a new preferences table, API endpoints for CRUD, and a settings page in the React frontend that reads/writes preferences." Express.js API with PostgreSQL, React frontend. 12 existing features follow this pattern (CRUD + UI).
**Prompt:** Interrogate these requirements and recommend execution strategy.
**Expected:**
- [ ] Identifies multiple architecture boundaries (API + DB + frontend)
- [ ] Produces swarm recommendation (not no-swarm) — crosses module boundaries
- [ ] Recommends a tier with rationale referencing boundary count and pattern analysis
- [ ] Rationale is consistent with the skill's tier criteria
- [ ] Enumerates existing similar features to confirm pattern-following
**Anti-patterns:**
- [ ] Recommends no-swarm despite 3 architecture boundaries
- [ ] Omits tier or rationale from swarm recommendation
- [ ] Recommends heavy for pattern-following work

### Scenario: Tier selection for core abstraction refactor
**Setup:** User says "replace our homegrown ORM with Prisma across the entire backend. Every model, every query, every migration needs to change. The API layer, background jobs, and test fixtures all depend on the current ORM's query builder interface." 40+ model files, 3 service layers (API, workers, cron), 200+ queries.
**Prompt:** Interrogate these requirements and recommend execution strategy.
**Expected:**
- [ ] Identifies this as refactoring a core abstraction (ORM) that other code depends on
- [ ] Identifies 3+ architecture boundaries (API, workers, cron, tests)
- [ ] Produces swarm recommendation with tier: heavy
- [ ] Rationale references scope (40+ files), core dependency, cross-boundary impact
- [ ] Describes scope enumeration approach (e.g., search for ORM imports, query builder calls, migration files) or lists affected files if codebase is available
- [ ] Analyzes error-state risks: what happens if migration fails partway through?
**Anti-patterns:**
- [ ] Recommends lite or no-swarm for a 40+ file core refactor
- [ ] Fails to identify the ORM as a shared dependency
- [ ] Skips risk assessment for a migration affecting all data access
- [ ] Skips scope enumeration entirely (no mention of what to search for or how to find all occurrences)

### Scenario: Plan mode enforcement
**Setup:** User provides a clear, well-defined task: "Add input validation to the /api/users POST endpoint — reject requests missing email field with 400."
**Prompt:** Validate this requirement using /grill before implementation.
**Expected:**
- [ ] Completes all grill steps in order (restate, boundary, success, constraints, assumptions, risks, priority, MECE, scope enumeration, swarm decision)
- [ ] Produces explicit output for each step (steps may be grouped but each must have visible output)
- [ ] Does NOT create files, write code, or make edits during the grill
- [ ] Error-state analysis: what happens if validation logic throws? What response does the client get?
**Anti-patterns:**
- [ ] Skips directly to implementation after a brief acknowledgment
- [ ] Produces a single-paragraph summary instead of step-by-step analysis
- [ ] Creates or edits files during the grill process

## Baseline
Without `/grill`, agents typically accept requirements at face value and begin implementation. Edge cases surface during coding (expensive) rather than during planning (cheap). Without tier selection, all swarms run at med cost regardless of complexity. Without error-state analysis, failure modes are discovered in production. Without scope enumeration, changes are applied to some but not all occurrences.
