---
description: Create semantic git commits with proper format and context
---
# /commit — Semantic Commit Workflow

Commits are documentation. They tell the story of why code changed.

## Invocation

```
/commit          # Interactive commit flow
/commit --amend  # Amend previous commit (use carefully)
```

## Commit Message Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

| Type | Use When |
|------|----------|
| `feat` | New feature for users |
| `fix` | Bug fix for users |
| `refactor` | Code change that neither fixes nor adds |
| `test` | Adding or updating tests |
| `docs` | Documentation only |
| `chore` | Build, tooling, dependencies |
| `perf` | Performance improvement |

### Rules

1. **Subject line**
   - Imperative mood: "Add feature" not "Added feature"
   - No period at end
   - Max 50 characters (hard limit: 72)

2. **Body** (when needed)
   - Explain *what* and *why*, not *how*
   - Wrap at 72 characters
   - Separate from subject with blank line

3. **Footer** (when relevant)
   - Reference issues: `Fixes #123`
   - Breaking changes: `BREAKING CHANGE: description`

## Examples

### Simple fix
```
fix(auth): prevent session fixation on login
```

### Feature with context
```
feat(api): add rate limiting to public endpoints

Without rate limiting, the API is vulnerable to abuse and DoS.
Implementing token bucket algorithm with 100 req/min default.

Configurable via RATE_LIMIT_RPM environment variable.
```

### Breaking change
```
refactor(config): migrate from JSON to YAML configuration

YAML provides better readability and comment support.

BREAKING CHANGE: config.json must be migrated to config.yaml
See docs/migration-v3.md for migration guide.
```

## Pre-Commit Checklist

Before committing:
- [ ] `git diff --staged` reviewed
- [ ] No debug code or console.logs
- [ ] No secrets or credentials
- [ ] Tests pass (run test suite before committing)
- [ ] Commit is atomic (single logical change)

## Pre-Push Checklist

Before pushing:
- [ ] Pull and rebase: `git pull --rebase origin <branch>`
- [ ] Tests still pass after rebase
- [ ] No merge conflicts introduced

## The Atomic Commit Test

> "Could I revert just this commit without breaking anything else?"

If no, split the commit.
