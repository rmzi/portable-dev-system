---
description: Selecting test strategy and analyzing coverage. Use when writing tests, choosing test types, or planning test coverage for a feature.
---
# /test — Test Strategy Selection

Tests are a specification that happens to be executable.

## Invocation

```
/test [file|function]    # Suggest test strategy for code
/test coverage           # Analyze test coverage gaps
/test plan               # Create test plan for feature
```

## Testing Pyramid

| Level | Count | Speed | Use For |
|-------|-------|-------|---------|
| Unit | Many | Fast | Pure functions, algorithms, edge cases, error handling |
| Integration | Some | Medium | DB ops, API endpoints, external services, component boundaries |
| E2E | Few | Slow | Critical user journeys, smoke tests, key regression flows |

## When to Use Each Type

### Unit Tests
Test single function/class in isolation.
**When:** Pure functions, complex algorithms, edge cases, error handling.
**Skip:** Simple getters, framework boilerplate, trivial delegation.

### Integration Tests
Test component interactions across boundaries.
**When:** Database ops, API endpoints, external services, component interactions.

### E2E Tests
Test complete user workflows. Few, focused on happy paths, resilient to UI changes.

## Test Naming

Pattern: `test('[unit] [action] [expected outcome]')`
Example: `test('given expired token, when accessing API, then returns 401')`

## What to Test

**Behavior, not implementation:**
```javascript
// Bad: test('calls database.save') → tests implementation detail
// Good: test('created user retrievable by email') → tests behavior
```

**The contract:** At boundaries: valid inputs → correct outputs, invalid inputs → errors, edge cases handled.

**The scary parts:** Money handling, security ops, complex conditionals, recent bugs, unfamiliar code.

## Test Quality Checklist

- [ ] Single reason to fail
- [ ] Name describes the behavior
- [ ] Deterministic (no flakiness)
- [ ] Independent (no shared state)
- [ ] Fast (< 100ms for unit)

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Testing everything | Test behavior at boundaries |
| Too many mocks | Use real deps where possible |
| Flaky tests | Fix or delete immediately |
| Wrong level | Match test type to need |

## TDD Workflow

Test-driven development is a discipline, not a suggestion. The cycle enforces design thinking before implementation.

1. **RED** — Write a failing test that describes the behavior you want. Run it. Watch it fail. The failure message is your specification.
2. **GREEN** — Write the *minimal* code to make the test pass. No more. Resist the urge to implement ahead.
3. **REFACTOR** — Improve the code while keeping tests green. Extract patterns, rename for clarity, remove duplication.

Repeat. Each cycle should take minutes, not hours.

### Test-First vs Test-After

| Aspect | Test-First (TDD) | Test-After |
|--------|-------------------|------------|
| Design feedback | Immediate — tests shape the API | Late — tests adapt to existing API |
| Coverage gaps | Rare — untested code doesn't exist yet | Common — easy to forget edge cases |
| Refactoring safety | High — comprehensive tests already exist | Variable — depends on discipline |
| When to use | New features, complex logic, public APIs | Legacy code, exploratory prototyping |

When in doubt, write the test first. The discipline pays compound interest.
