---
skill: grill
---
# Eval: /pds:grill

Grill is an interactive Q&A skill. In eval (non-interactive pipe mode), the agent gets one turn — no human responds. Criteria test the quality of that first turn: does the agent propose concrete analysis AND ask clarifying questions? "Proposes and asks" is a PASS. "Produces vague analysis without questions" is a FAIL.

## Scenarios

### Scenario: Vague performance request
**Setup:** User says "make the API faster" with no metrics, no specific endpoints, no load profile.
**Prompt:** Interrogate this requirement before planning implementation.
**Expected:**
- [ ] Proposes a concrete restatement of the problem (not just echoing "make it faster")
- [ ] Proposes a scope boundary and asks the human to confirm (which endpoints, what "faster" means)
- [ ] Proposes candidate acceptance criteria (e.g., "p99 < 200ms") — even as assumptions to validate
- [ ] Lists assumptions and asks the human to challenge them
- [ ] Describes what to search for in a scope enumeration (which files, patterns, endpoints to investigate)
**Anti-patterns:**
- [ ] Accepts "make it faster" and starts profiling or implementing immediately
- [ ] Only asks questions without proposing any concrete analysis
- [ ] Produces criteria like "should be noticeably faster" (not verifiable)
- [ ] Skips boundary definition — scope is unbounded

### Scenario: Feature with missing edge cases
**Setup:** "Add a delete button to user profiles. Clicking it deletes the user." No mention of: confirmation dialog, admin vs self-delete, cascade behavior, undo.
**Prompt:** Validate these requirements before implementation.
**Expected:**
- [ ] Identifies missing edge cases (confirmation, authorization, cascading) and asks the human about them
- [ ] Asks about error states: what if deletion fails mid-cascade? What partial state? Recovery path?
- [ ] Proposes in-scope/out-of-scope lists for human confirmation
- [ ] Proposes priority ranking (must/should/could) and asks if it matches human priorities
- [ ] Does NOT start implementing — stays in analysis/question mode throughout
**Anti-patterns:**
- [ ] Implements the delete button without questioning the spec
- [ ] Identifies gaps but doesn't propose verifiable acceptance criteria
- [ ] Skips error-state analysis for the deletion operation
- [ ] Produces analysis without asking any clarifying questions

### Scenario: Tier selection for cross-module feature
**Setup:** User says "add user notification preferences — a new preferences table, API endpoints for CRUD, and a settings page in the React frontend that reads/writes preferences." Express.js API with PostgreSQL, React frontend. 12 existing features follow this pattern (CRUD + UI).
**Prompt:** Interrogate these requirements and recommend execution strategy.
**Expected:**
- [ ] Identifies multiple architecture boundaries (API + DB + frontend)
- [ ] Produces swarm recommendation (not no-swarm) — crosses module boundaries
- [ ] Recommends a tier with rationale referencing boundary count and pattern analysis
- [ ] Rationale is consistent with the skill's tier criteria
- [ ] Asks confirming questions about existing patterns (e.g., "Do all 12 features follow the same CRUD + UI pattern?")
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
- [ ] Describes scope enumeration approach (search for ORM imports, query builder calls, migration files)
- [ ] Asks about error-state risks: what happens if migration fails partway through?
**Anti-patterns:**
- [ ] Recommends lite or no-swarm for a 40+ file core refactor
- [ ] Fails to identify the ORM as a shared dependency
- [ ] Skips risk assessment for a migration affecting all data access
- [ ] Skips scope enumeration entirely (no mention of what to search for)

### Scenario: Plan mode enforcement
**Setup:** User provides a clear, well-defined task: "Add input validation to the /api/users POST endpoint — reject requests missing email field with 400."
**Prompt:** Validate this requirement using /grill before implementation.
**Expected:**
- [ ] Works through grill steps in order (restate, boundary, success, constraints, assumptions, risks, priority, MECE, scope enumeration, swarm decision)
- [ ] Produces visible output for each step (steps may be grouped but each must appear)
- [ ] Proposes concrete criteria and asks the human to confirm them
- [ ] Does NOT create files, write code, or make edits during the grill
- [ ] Asks about error states: what happens if validation logic throws? What response does the client get?
**Anti-patterns:**
- [ ] Skips directly to implementation after a brief acknowledgment
- [ ] Produces a single-paragraph summary instead of step-by-step analysis
- [ ] Creates or edits files during the grill process
- [ ] Completes all steps without asking the human a single question

## Baseline
Without `/grill`, agents accept requirements at face value and begin implementation. Edge cases surface during coding (expensive) rather than during planning (cheap). Without tier selection, all swarms run at med cost regardless of complexity. Without error-state analysis, failure modes are discovered in production. Without scope enumeration, changes are applied to some but not all occurrences. Without Q&A, the agent's assumptions go unchallenged until they cause rework.
