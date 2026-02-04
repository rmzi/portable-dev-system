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
**What:** Test a single function or class in isolation
**When:**
- Pure functions with logic
- Complex algorithms
- Edge cases and error handling

**Not for:**
- Simple getters/setters
- Framework boilerplate
- Trivial delegation

```javascript
// Good unit test candidate
function calculateDiscount(price, customerType, quantity) {
  // Complex logic with multiple paths
}

// Don't bother unit testing
function getUsername() {
  return this.username;
}
```

### Integration Tests
**What:** Test how components work together
**When:**
- Database operations
- API endpoints
- External service integration
- Component interactions

```javascript
// Good integration test
test('user registration creates account and sends welcome email', async () => {
  const result = await registerUser({ email: 'test@example.com' });

  expect(await db.users.find(result.id)).toBeDefined();
  expect(mockEmailService.sent).toContainEqual(
    expect.objectContaining({ to: 'test@example.com' })
  );
});
```

### E2E Tests
**What:** Test complete user workflows
**When:**
- Critical user journeys
- Smoke tests for deployment
- Regression prevention on key flows

**Keep them:**
- Few in number
- Focused on happy paths
- Resilient to UI changes

## Test Naming

```
test('[unit] [action] [expected outcome]')
test('[given] [when] [then]')
```

Examples:
```javascript
test('calculateTotal applies discount when quantity exceeds 10')
test('given expired token, when accessing API, then returns 401')
test('user can complete checkout with valid payment')
```

## What to Test

### Test Behavior, Not Implementation

```javascript
// Bad: Tests implementation
test('calls database.save with user object', () => {
  createUser(data);
  expect(database.save).toHaveBeenCalledWith(data);
});

// Good: Tests behavior
test('created user can be retrieved by email', async () => {
  await createUser({ email: 'test@example.com' });
  const user = await findUserByEmail('test@example.com');
  expect(user).toBeDefined();
});
```

### Test the Contract

At boundaries (APIs, public interfaces), test:
- Valid inputs produce correct outputs
- Invalid inputs produce appropriate errors
- Edge cases are handled

### Test the Scary Parts

Focus testing effort on:
- Code that handles money
- Security-sensitive operations
- Complex conditional logic
- Recently buggy areas
- Code you don't fully understand

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

> "I'm not a great programmer; I'm a good programmer with great habits." — Kent Beck
