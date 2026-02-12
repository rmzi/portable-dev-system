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

## Why Skills?

Skills encode team knowledge:
- **Consistency**: Everyone follows the same process
- **Onboarding**: New members learn by doing
- **Evolution**: Update a skill, everyone benefits
- **AI leverage**: Claude follows your conventions

---

## Why Worktrees?

Worktrees give you parallel, isolated environments. No stashing. No branch switching. No lost context. Each worktree has its own working directory and Claude Code session, but shares git history.

---

## The Agentic SDLC

PDS implements the six-phase agentic development model:

1. **Plan** — Refine requirements into acceptance criteria
2. **Decompose** — Split into independent tasks, create worktrees
3. **Execute** — Workers implement in parallel (SendMessage when needed)
4. **Validate** — Merge, test, review, fix
5. **Consolidate** — PR + docs for human review
6. **Knowledge** — Meta-improvements, lessons captured

The human remains architect and final authority. Agents become a scalable workforce.

See [Proposal](proposal.md) for the shareable overview and [Whitepaper](whitepaper.md) for full technical depth.

---

## Standing on Giants

- **Thompson & Ritchie** — Unix philosophy: do one thing well
- **Kent Beck** — TDD, XP: tests drive design
- **Martin Fowler** — Refactoring: continuous improvement
- **Sandi Metz** — Practical OO: small objects, clear interfaces
- **Rich Hickey** — Simple vs easy: choose simple
