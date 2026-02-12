---
description: Test strategy selection and coverage analysis
---
# /test — Test Strategy Selection

Tests are a specification that happens to be executable.

## Invocation

```
/test [file|function]    # Suggest test strategy for code
/test coverage           # Analyze test coverage gaps
/test plan               # Create test plan for feature
```

## The Testing Pyramid

```
        ╱╲
       ╱  ╲      E2E Tests (few)
      ╱────╲     Slow, brittle, high confidence
     ╱      ╲
    ╱────────╲   Integration Tests (some)
   ╱          ╲  Test boundaries and contracts
  ╱────────────╲
 ╱              ╲ Unit Tests (many)
╱────────────────╲ Fast, isolated, focused
```

## When to Use Each Type

### Unit Tests
Test single function/class in isolation.
**When:** Pure functions, complex algorithms, edge cases, error handling.
**Skip:** Simple getters, framework boilerplate, trivial delegation.

```javascript
// Test: complex logic with multiple paths
function calculateDiscount(price, customerType, quantity) { ... }
```

### Integration Tests
Test component interactions across boundaries.
**When:** Database ops, API endpoints, external services, component interactions.

```javascript
test('registration creates account and sends email', async () => {
  const result = await registerUser({ email: 'test@example.com' });
  expect(await db.users.find(result.id)).toBeDefined();
  expect(mockEmailService.sent).toContainEqual(expect.objectContaining({ to: 'test@example.com' }));
});
```

### E2E Tests
Test complete user workflows. Few, focused on happy paths, resilient to UI changes.
Use for: critical user journeys, smoke tests, regression on key flows.

## Test Naming

Pattern: `test('[given] [when] [then]')` or `test('[unit] [action] [expected outcome]')`
Example: `test('given expired token, when accessing API, then returns 401')`

## What to Test

### Test Behavior, Not Implementation

```javascript
// Bad: test('calls database.save') → tests implementation detail
// Good: test('created user retrievable by email') → tests behavior
```

### Test the Contract
At boundaries (APIs, public interfaces): valid inputs → correct outputs, invalid inputs → errors, edge cases handled.

### Test the Scary Parts
Prioritize: money handling, security ops, complex conditionals, recent bugs, unfamiliar code.

## Test Quality Checklist

- [ ] Test has a single reason to fail
- [ ] Test name describes the behavior
- [ ] Test is deterministic (no flakiness)
- [ ] Test is independent (no shared state)
- [ ] Test is fast (< 100ms for unit tests)
- [ ] Test documents expected behavior

## Common Testing Mistakes

| Mistake | Problem | Fix |
|---------|---------|-----|
| Testing everything | Slow, brittle suite | Test behavior at boundaries |
| Too many mocks | Tests pass, prod fails | Use real deps where possible |
| Flaky tests | Erode trust in suite | Fix or delete immediately |
| No tests | Fear of change | Start with integration tests |
| Wrong level | E2E for edge cases | Match test type to need |

## TDD Workflow

```
1. RED    — Write a failing test
2. GREEN  — Write minimal code to pass
3. REFACTOR — Improve code, keep tests green
```
