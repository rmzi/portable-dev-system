# Philosophy

## The Seven Principles

1. **Understand before you act** — Read code before changing it
2. **Small, reversible steps** — Atomic commits, small PRs
3. **Tests as specification** — Tests document intent
4. **Explicit over implicit** — No magic, no hidden conventions
5. **Optimize for change** — Code is read 10x more than written
6. **Fail fast, recover gracefully** — Validate at boundaries
7. **Automation as documentation** — Scripts > READMEs

---

## Why Terminal-First?

- **Speed**: No GUI latency, instant feedback
- **Composability**: Pipes, scripts, automation
- **Portability**: Same workflow on any machine
- **Focus**: No visual distractions
- **AI-native**: Claude Code works best in terminal

---

## Why Worktrees?

**The problem:** You're mid-feature, urgent bug comes in. You `git stash`, fix it, come back, forget what you were doing.

**The solution:** Worktrees give you parallel, isolated environments.

```bash
# Working on feature
wt -b feature/auth

# Urgent bug? New terminal:
wt -b hotfix/critical

# Two completely isolated environments
# No stashing. No branch switching. No lost context.
```

Each worktree:
- Own working directory
- Own Claude Code session
- Shares git history
- True isolation

---

## Why Skills?

Skills encode team knowledge:
- **Consistency**: Everyone follows the same process
- **Onboarding**: New members learn by doing
- **Evolution**: Update a skill, everyone benefits
- **AI leverage**: Claude follows your conventions

---

## Standing on Giants

Built on wisdom from:

- **Thompson & Ritchie** — Unix philosophy: do one thing well
- **Kent Beck** — TDD, XP: tests drive design
- **Martin Fowler** — Refactoring: continuous improvement
- **Sandi Metz** — Practical OO: small objects, clear interfaces
- **Rich Hickey** — Simple vs easy: choose simple
