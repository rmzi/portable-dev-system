# /review — Structured Code Review

Systematic code review that catches issues and builds shared understanding.

## Invocation

```
/review [file|PR|commit]
```

## Review Checklist

### 1. Intent (Does it solve the right problem?)
- [ ] Change matches the stated goal
- [ ] No scope creep beyond the requirement
- [ ] Edge cases considered

### 2. Correctness (Does it work?)
- [ ] Logic handles all code paths
- [ ] Error cases handled appropriately
- [ ] No obvious bugs or typos

### 3. Security (Is it safe?)
- [ ] Input validation at boundaries
- [ ] No injection vulnerabilities (SQL, command, XSS)
- [ ] Secrets not hardcoded or logged
- [ ] Auth/authz checks in place

### 4. Clarity (Can others understand it?)
- [ ] Names reveal intent
- [ ] Complex logic has explanatory comments
- [ ] No dead code or commented-out blocks
- [ ] Functions are appropriately sized

### 5. Testing (Is it verified?)
- [ ] Tests cover the change
- [ ] Tests cover failure modes
- [ ] Tests are readable as specification

### 6. Integration (Does it fit?)
- [ ] Follows existing patterns in codebase
- [ ] No breaking changes to public interfaces
- [ ] Dependencies are appropriate

## Review Response Format

```
## Summary
One sentence on what this change does.

## Assessment
✓ Looks good / ⚠ Needs changes / ✗ Significant issues

## Findings

### [Category]: [Brief description]
Location: file:line
Issue: What's wrong
Suggestion: How to fix

## Questions
- Things that need clarification
```

## Review Etiquette

**As reviewer:**
- Ask questions, don't demand
- Explain the "why" behind suggestions
- Distinguish nitpicks from blockers
- Acknowledge good work

**As author:**
- Assume good intent
- Explain context reviewer might lack
- If you disagree, explain why—then defer or discuss
