---
description: Fixing bugs using a test-first disciplined loop. Use when a bug is reported or discovered and needs a verified fix with minimal blast radius.
---
# /bugfix — Test-First Bug Fix Protocol

Bugs get fixed once when you prove the fix works. No guessing, no "it should be fine." Write a failing test, fix the code, watch it pass.

## Invocation

```
/bugfix [bug description or issue link]
```

## The Loop

### 1. Orient
Confirm your context before touching anything:

- Run `git branch --show-current` and `git rev-parse --show-toplevel`
- Read the bug report. Identify the affected module.
- Explore relevant source files to understand the current behavior.
- If the cause is unknown, run `/debug` first.

### 2. Reproduce
Write a minimal failing test that captures the exact bug:

- The test should fail for the *right reason* — the bug, not a typo
- Place it in the existing test file for the affected module
- Name it clearly: `test_[module]_[bug_description]`

### 3. Confirm
Run the test suite. Your new test must fail. If it passes, your test doesn't capture the bug — go back to step 2.

### 4. Fix
Implement the minimal fix:

- Change only the affected module
- Do not modify existing tests
- Do not refactor surrounding code
- Smallest diff that resolves the failing test

### 5. Verify
Run the **full** test suite — not just your new test. If anything fails, go back to step 4.

### 6. Check
Run project linters and type checks. Fix any warnings your changes introduced. Do not fix pre-existing warnings.

### 7. Ship
Only after all tests and checks pass:

- Commit with `fix(scope): description` format (see `/commit`)
- Push and create/update PR

## Constraints

- **One module.** Do not change files outside the affected module.
- **No test modifications.** Do not alter existing tests — only add your reproduction test.
- **Minimal diff.** The fix should be the smallest change that resolves the bug.
- **Evidence before claims.** Do not say "fixed" until the test suite passes.

## See Also

- `/debug` — finding the root cause (use before /bugfix if cause is unknown)
- `/test` — test strategy and TDD workflow
- `/verify` — completion self-check before declaring done
- `/commit` — commit format for the fix
