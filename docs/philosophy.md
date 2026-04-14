# Philosophy

## The Seven Principles

1. **Understand before you act** — Read code before changing it
2. **Small, reversible steps** — Atomic commits, small PRs
3. **Tests as specification** — Tests document intent
4. **Explicit over implicit** — No magic, no hidden conventions
5. **Optimize for change** — Code is read 10x more than written
6. **Fail fast, recover gracefully** — Validate at boundaries
7. **Automation as documentation** — Scripts > READMEs

These principles are documented in [docs/ethos.md](ethos.md) and grounded across all PDS skills. They are stable — tools and techniques evolve, but principles endure.

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

## Platform Understanding

PDS benefits from deep understanding of the platform it extends. A source analysis of Claude Code's internals (March 2026) revealed the system prompt assembly pipeline, 4-layer settings hierarchy, 28 hook lifecycle events, and plugin loading mechanism. This knowledge directly improved PDS: defense-in-depth layers map to actual runtime mechanisms, hook-based phase gates use real event semantics, and cost optimization uses real per-model pricing.

Understanding the platform deeply — not just its public API — is consistent with the first principle: understand before you act.

---

## Standing on Giants

- **Thompson & Ritchie** — Unix philosophy: do one thing well
- **Kent Beck** — TDD, XP: tests drive design
- **Martin Fowler** — Refactoring: continuous improvement
- **Sandi Metz** — Practical OO: small objects, clear interfaces
- **Rich Hickey** — Simple vs easy: choose simple
