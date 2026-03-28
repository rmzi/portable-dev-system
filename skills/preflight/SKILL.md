---
description: Preflight environment validation. Use at session start or before running tests to verify the development environment is correctly configured.
---
# /preflight — Environment Validation

Quick validation that the development environment is ready for work. Each check reports pass/fail independently. Run at session start or before tests to catch configuration issues early.

## When to Use

- At the start of a development session
- Before running tests for the first time
- After switching branches or worktrees
- When builds or tests fail with environment-related errors
- Before starting a swarm (catches env issues before they block workers)

## Checks

### 1. Git Status
```bash
git status --porcelain
```
- **Pass:** Clean working tree, or only expected changes
- **Fail:** Unexpected uncommitted changes, merge conflicts, detached HEAD

Report: branch name, clean/dirty status, conflict count.

### 2. Working Directory
```bash
pwd
git rev-parse --show-toplevel
```
- **Pass:** Current directory is inside a git repository
- **Fail:** Not in a git repo, or in the wrong project

Report: current directory, repo root, worktree status.

### 3. Dependencies
```bash
# Node.js
test -d node_modules && echo "exists" || echo "missing"
# Python
test -d .venv || test -n "$VIRTUAL_ENV" && echo "exists" || echo "missing"
# Check lockfile freshness
```
- **Pass:** Dependencies installed and lockfile not newer than installed packages
- **Fail:** Missing node_modules/.venv, or lockfile changed since last install

Report: dependency manager detected, install status, staleness.

### 4. Test Collection
```bash
# Node.js
npx jest --listTests 2>/dev/null | wc -l
# Python
python -m pytest --collect-only -q 2>/dev/null | tail -1
# Generic
ls **/test* **/spec* 2>/dev/null | head -5
```
- **Pass:** Test runner found and tests can be discovered
- **Fail:** No test runner, or test collection errors

Report: test runner, test file count, collection errors.

### 5. Environment Variables
```bash
# Check for .env file
test -f .env && echo "exists" || echo "missing"
# Check for .env.example
test -f .env.example && echo "exists" || echo "missing"
# Check for required env vars (project-specific)
```
- **Pass:** Required environment files present, or no env files needed
- **Fail:** .env.example exists but .env is missing, or required vars unset

Report: env file status, missing variables.

### 6. Tool Versions
```bash
node --version 2>/dev/null
python3 --version 2>/dev/null
git --version
```
- **Pass:** Required tools are installed and accessible
- **Fail:** Missing tools, or version mismatch with project requirements

Report: tool name, version, required vs actual.

## Output Format

```
## Preflight Check: [project-name]

| Check | Status | Details |
|-------|--------|---------|
| Git status | pass/fail | [branch, clean/dirty] |
| Working directory | pass/fail | [path, repo root] |
| Dependencies | pass/fail | [manager, install status] |
| Test collection | pass/fail | [runner, test count] |
| Environment | pass/fail | [env files, missing vars] |
| Tool versions | pass/fail | [tools and versions] |

**Result:** Ready / [N issues to resolve]
```

## Rules

- **Report all checks** even if early ones fail — the full picture helps diagnose compound issues.
- **No fixes.** Report what's wrong, don't auto-fix. The user decides how to resolve.
- **Project-adaptive.** Skip checks that don't apply (no Python check in a Node.js project).
- **Fast.** Each check should complete in under 5 seconds. Total preflight under 30 seconds.

## See Also

- `/pds:verify` — Post-implementation completeness check (different purpose)
- `/pds:audit-config` — PDS configuration security audit
