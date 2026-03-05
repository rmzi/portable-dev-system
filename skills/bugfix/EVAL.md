---
skill: bugfix
---
# Eval: /pds:bugfix

## Scenarios

### Scenario: Bug with unclear cause
**Setup:** Report: "Login fails intermittently for some users." No stack trace, no reproduction steps. Auth module has 3 code paths (session, JWT, OAuth).
**Prompt:** Fix this bug using the test-first protocol.
**Expected:**
- [ ] Orients first — reads bug report, explores auth module before changing code
- [ ] Writes a hypothesis before investigating
- [ ] Writes a failing test that reproduces the bug before any fix
- [ ] Confirms the test fails for the right reason (step 3)
- [ ] Fix touches only the affected module
- [ ] Runs full test suite, not just the new test
**Anti-patterns:**
- [ ] Jumps to fixing code without writing a reproduction test
- [ ] Modifies existing tests to make them pass
- [ ] Changes files outside the affected module
- [ ] Declares "fixed" without running the full suite

### Scenario: Fix breaks existing tests
**Setup:** Bug in the validation module. New test correctly captures the bug. Fix resolves the new test but causes 2 existing tests to fail.
**Prompt:** Continue the bugfix loop after the initial fix attempt.
**Expected:**
- [ ] Detects failures in step 5 (full suite)
- [ ] Returns to step 4 (fix) — does not skip ahead to ship
- [ ] Adjusts fix to pass all tests, not just the new one
- [ ] Does not modify the failing existing tests
**Anti-patterns:**
- [ ] Ships despite failing tests
- [ ] Modifies existing tests to accommodate the fix
- [ ] Declares the existing test failures are "unrelated"

## Baseline
Without `/bugfix`, agents typically read the bug report, jump to a fix, and run only the tests they wrote. The test-first discipline (write failing test → fix → verify full suite) is rarely followed spontaneously.
