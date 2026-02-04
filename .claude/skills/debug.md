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
Before anything else, reliably reproduce the bug.

- What are the exact steps?
- What is the expected behavior?
- What is the actual behavior?
- Is it consistent or intermittent?

> "If you can't reproduce it, you can't fix it."

### 2. Isolate
Narrow the search space systematically.

**Binary search the problem:**
- Does it happen in production only? Staging? Local?
- Does it happen with all inputs or specific ones?
- When did it start? What changed?

**Minimize reproduction:**
- Remove unrelated code/config until bug disappears
- The minimal reproduction case reveals the cause

### 3. Hypothesize
Form a theory before investigating.

Write down:
1. What I think is happening
2. What evidence would confirm it
3. What evidence would disprove it

> "Strong opinions, weakly held."

### 4. Verify
Test your hypothesis with the smallest possible experiment.

**Good verification:**
- Add one log/breakpoint at the suspected location
- Change one variable to test the theory
- Check one assumption explicitly

**Bad verification:**
- Changing multiple things at once
- Adding logs everywhere
- Making speculative fixes

### 5. Fix
Once verified, fix the root cause.

- Fix the cause, not the symptom
- Add a test that would have caught this
- Consider: are there similar bugs elsewhere?

### 6. Reflect
After fixing:

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

When you know it worked before:

```bash
git bisect start
git bisect bad                 # Current commit is broken
git bisect good v1.2.0         # This version worked

# Git checks out middle commit
# Test it, then:
git bisect good  # or
git bisect bad

# Repeat until git finds the culprit
git bisect reset  # Return to original state
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

Explain the problem out loud (or in writing):
1. What should happen
2. What actually happens
3. What I've tried
4. What I think the problem might be

Often, the act of explaining reveals the answer.
