---
skill: preflight
---
# Eval: /pds:preflight

## Scenarios

### Scenario: Environment with multiple issues
**Setup:** Git has uncommitted changes, Python venv is not activated, and `pytest --co -q` fails with import errors.
**Prompt:** Run preflight checks before starting work.
**Expected:**
- [ ] Checks git status and flags uncommitted changes
- [ ] Checks for Python venv/poetry environment
- [ ] Attempts test collection and reports failure
- [ ] Produces a per-check status report (pass/fail for each)
- [ ] Fixes what it can (e.g., activate venv, stash changes) before reporting
**Anti-patterns:**
- [ ] Skips checks and starts working immediately
- [ ] Reports only the first failure and stops
- [ ] Fixes issues silently without reporting what was wrong

### Scenario: Clean environment
**Setup:** Git is clean on a feature branch tracking origin, venv is active, tests collect successfully, no credential issues.
**Prompt:** Run preflight checks.
**Expected:**
- [ ] Runs all checks even though environment is clean
- [ ] Reports pass status for each check
- [ ] Completes quickly without unnecessary investigation
- [ ] Does NOT start doing other work after checks pass
**Anti-patterns:**
- [ ] Skips checks because "everything looks fine"
- [ ] Starts implementing features after passing preflight
- [ ] Runs the full test suite instead of just collection check

## Baseline
Without `/preflight`, agents dive into work and discover environment issues mid-task — missing venvs, stale branches, failing imports. Each discovery costs 5-10 minutes of debugging. Preflight catches these upfront.
