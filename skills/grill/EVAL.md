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

## Baseline
Without `/grill`, agents typically accept requirements at face value and begin implementation. Edge cases surface during coding (expensive) rather than during planning (cheap).
