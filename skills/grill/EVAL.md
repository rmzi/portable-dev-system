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
**Anti-patterns:**
- [ ] Accepts "make it faster" and starts profiling immediately
- [ ] Produces criteria like "should be noticeably faster" (not verifiable)
- [ ] Skips boundary definition — scope is unbounded

### Scenario: Feature with missing edge cases
**Setup:** "Add a delete button to user profiles. Clicking it deletes the user." No mention of: confirmation dialog, admin vs self-delete, cascade behavior, undo.
**Prompt:** Validate these requirements before implementation.
**Expected:**
- [ ] Identifies missing edge cases (confirmation, authorization, cascading)
- [ ] Asks about error states (what if deletion fails mid-cascade?)
- [ ] Produces in-scope/out-of-scope lists
- [ ] Ranks requirements by priority (must/should/could)
**Anti-patterns:**
- [ ] Implements the delete button without questioning the spec
- [ ] Identifies gaps but doesn't produce verifiable acceptance criteria
- [ ] Skips MECE check

### Scenario: Tier selection for routine task
**Setup:** User says "add a new /health endpoint that returns 200 with uptime" in a REST API with 20 existing endpoints following the same pattern.
**Prompt:** Interrogate these requirements and recommend execution strategy.
**Expected:**
- [ ] Identifies this as pattern-following work (similar endpoints exist)
- [ ] Produces swarm recommendation with tier: lite
- [ ] Rationale references: single boundary, clear pattern, low ambiguity
- [ ] Does NOT recommend med or heavy for simple addition
**Anti-patterns:**
- [ ] Recommends heavy tier for routine work
- [ ] Omits tier from swarm recommendation
- [ ] Recommends no-swarm when 3+ files are affected (endpoint, route, test, docs)

### Scenario: Tier selection for complex refactor
**Setup:** User says "refactor the auth system from session-based to JWT, update all API endpoints, add refresh token flow, update frontend auth context, and add integration tests."
**Prompt:** Interrogate these requirements and recommend execution strategy.
**Expected:**
- [ ] Identifies deep cross-boundary coupling (API + DB + frontend + tests)
- [ ] Produces swarm recommendation with tier: heavy
- [ ] Rationale references: 15+ files, new architectural pattern, high complexity
- [ ] Includes decomposition outline with task count and boundaries
**Anti-patterns:**
- [ ] Recommends lite for a major refactor
- [ ] Skips risk assessment for auth changes
- [ ] Fails to identify the scope as heavy-tier

## Baseline
Without `/grill`, agents typically accept requirements at face value and begin implementation. Edge cases surface during coding (expensive) rather than during planning (cheap). Without tier selection, all swarms run at med cost regardless of complexity.
