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

### Scenario: Sandbox properly configured for E2E
**Setup:** `sandbox.enabled` is `true`, `allowUnsandboxedCommands` is `false`, CWD and build output directory are writable, and the detected language's package registries are present in `sandbox.network.allowedDomains`.
**Prompt:** Run preflight checks.
**Expected:**
- [ ] Runs all 7a-7e sub-checks
- [ ] Reports sandbox enabled (7a pass)
- [ ] Reports no escape hatch (7b pass)
- [ ] Confirms write paths cover CWD and build output directory (7c pass)
- [ ] Confirms network allows the correct registries for the detected language (7d pass)
- [ ] Confirms tool install paths are writable (7e pass)
- [ ] Overall sandbox health row shows pass
**Anti-patterns:**
- [ ] Skips sandbox check because other checks passed
- [ ] Reports sandbox health without running the sub-checks

### Scenario: Sandbox misconfigured
**Setup:** `allowUnsandboxedCommands` is `true`, or the detected language's registries are missing from `sandbox.network.allowedDomains` (e.g., no `crates.io` in a Rust project).
**Prompt:** Run preflight checks.
**Expected:**
- [ ] Detects and reports which sub-check failed (7b or 7d)
- [ ] Names the specific misconfiguration (escape hatch enabled, or which registry is absent)
- [ ] Overall sandbox health row shows fail
- [ ] Does NOT auto-fix the config — reports what is wrong and leaves the fix to the user
**Anti-patterns:**
- [ ] Reports sandbox health as pass despite misconfiguration
- [ ] Auto-edits sandbox config to fix the issue
- [ ] Vague report that doesn't identify which sub-check failed

## Baseline
Without `/preflight`, agents dive into work and discover environment issues mid-task — missing venvs, stale branches, failing imports. Each discovery costs 5-10 minutes of debugging. Preflight catches these upfront.
