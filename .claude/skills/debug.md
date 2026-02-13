---
description: Systematic debugging using scientific hypothesis testing
---
# /debug — Systematic Debugging

Debugging is hypothesis testing. Be scientific.

## Invocation

```
/debug [description of problem]
```

## The Debugging Protocol

### 1. Reproduce
Reliably reproduce before anything else.

- Exact steps, expected vs actual behavior
- Consistent or intermittent?

> "If you can't reproduce it, you can't fix it."

### 2. Isolate
Narrow the search space systematically.

- Production only? Staging? Local?
- All inputs or specific ones?
- When did it start? What changed?
- Remove unrelated code/config until bug disappears

### 3. Hypothesize
Write down before investigating:
1. What I think is happening
2. Evidence that would confirm it
3. Evidence that would disprove it

### 4. Verify
Test with the smallest possible experiment.

**Good:** One log/breakpoint, one variable change, one assumption check.
**Bad:** Multiple changes at once, logs everywhere, speculative fixes.

### 5. Fix
- Fix the cause, not the symptom
- Add a test that would have caught this
- Check for similar bugs elsewhere

### 6. Reflect
- Why did this bug exist?
- Why wasn't it caught earlier?
- What could prevent similar bugs?

## Debugging Tools by Layer

| Layer | Tools |
|-------|-------|
| Network | `curl`, `httpie`, browser devtools, `tcpdump` |
| Application | debugger, logs, `console.log`, print statements |
| Database | query logs, `EXPLAIN`, direct queries |
| System | `htop`, `lsof`, `strace`, `dmesg` |
| Git | `git bisect`, `git log -p`, `git blame` |

## git bisect — Binary Search History

```bash
git bisect start
git bisect bad                 # Current commit is broken
git bisect good v1.2.0         # This version worked
# Git checks out middle commit — test, then: git bisect good/bad
# Repeat until culprit found
git bisect reset               # Return to original state
```

## Common Bug Patterns

| Symptom | Common Causes |
|---------|---------------|
| Works locally, fails in prod | Env vars, file paths, network, permissions |
| Intermittent failure | Race condition, timing, external dependency |
| Wrong data | Off-by-one, null/undefined, type coercion |
| Performance regression | N+1 queries, missing index, memory leak |
| Works for me | User-specific data, browser/OS differences |

## The Rubber Duck Protocol

Explain the problem aloud or in writing: what should happen, what actually happens, what you've tried, what you suspect. The act of explaining often reveals the answer.
