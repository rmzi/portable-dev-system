---
description: Create semantic git commits with proper format and context
disable-model-invocation: true
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

1. **Subject line** — Imperative mood ("Add feature" not "Added"), no period, max 50 chars (hard limit: 72)
2. **Body** (when needed) — Explain *what* and *why*, not *how*. Wrap at 72 chars. Blank line after subject.
3. **Footer** (when relevant) — `Fixes #123` or `BREAKING CHANGE: description`

## Examples

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

- `git diff --staged` reviewed
- No debug code or console.logs
- No secrets or credentials
- Tests pass
- Commit is atomic (single logical change)

## Pre-Push Checklist

- Pull and rebase: `git pull --rebase origin <branch>`
- Tests still pass after rebase
- No merge conflicts introduced

## The Atomic Commit Test

> "Could I revert just this commit without breaking anything else?"

If no, split the commit.
