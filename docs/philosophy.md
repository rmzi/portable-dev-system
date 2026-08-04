# Philosophy

## The Eight Principles

1. **Understand before you act** — Read code before changing it
2. **Small, reversible steps** — Atomic commits, small PRs
3. **Tests as specification** — Tests document intent
4. **Explicit over implicit** — No magic, no hidden conventions
5. **Optimize for change** — Code is read 10x more than written
6. **Fail fast, recover gracefully** — Validate at boundaries
7. **Automation as documentation** — Scripts > READMEs
8. **Portability of operation** — Detect runtime capabilities, degrade gracefully on gaps

These principles are documented in [docs/ethos.md](ethos.md) and grounded across all PDS skills. They are stable — tools and techniques evolve, but principles endure.

---

## Why Skills?

Skills encode team knowledge:
- **Consistency**: Everyone follows the same process
- **Onboarding**: New members learn by doing
- **Evolution**: Update a skill, everyone benefits
- **AI leverage**: Claude follows your conventions

---

## Portability Contract (Distribution)

PDS is "install once, works across all projects." To hold that promise, it ships **only** markdown, bash, Python 3, and `jq`. No compiled artifacts. No language toolchains (Rust, Go, Node). No private binaries.

If a feature needs a compiled component, that component lives in a separate repo and PDS consumes its output through a skill — never bundles the build. Skills like `/pds:explore` read SQLite indexes written by external tools; PDS does not produce the indexer.

This keeps the install path honest: `curl | bash` is enough, no hidden prerequisites. Users without Rust, Go, or Node installed still get the full PDS experience.

This is portability of **install** — what it takes to get PDS onto a machine. It says nothing about what happens once PDS is running and the runtime underneath it turns out to be narrower than expected.

---

## Portability of Operation

Distribution portability answers "can PDS get installed here?" A different question: once running, does PDS assume a fixed toolset, a fixed agent roster, a fixed place for state to live — and break when the runtime doesn't match?

It has, before. The orchestrator's tool grants have silently lagged behind what its own skills required (`/pds:grill` shipped requiring `AskUserQuestion` and `EnterPlanMode` before the orchestrator's frontmatter granted either — a subagent only gets what its `tools:` list names, so Phase 1 grill had no way to ask a structured question). `TeamCreate`/`TeamDelete` were removed as Claude Code tools outright, and the teardown gate that keyed off `TeamDelete` had nothing left to bind to until it was migrated to a `Stop` hook. Both were the same failure shape: PDS assumed a capability the platform no longer promised, and had no way to notice before it broke.

The principle: **detect the runtime's capabilities before relying on them, and degrade gracefully when one is missing.** A missing tool, agent type, or state path should narrow what an agent does, not crash it silently. This is graceful in the same sense as [ethos](ethos.md) principle 6 ("fail fast, recover gracefully") — the failure should be loud and legible, not a quiet no-op — but the emphasis here is upstream of that: notice the gap before you're relying on it, not after.

Where this shows up concretely: the shepherd's advisor MCP tool falls back to plain Opus if the advisor beta is unreachable, and returns a structured degraded response if `ANTHROPIC_API_KEY` is unset, rather than failing the whole consultation (see `docs/whitepaper.md`, "The Shepherd"). That's the pattern generalized — one runtime-capability check, one explicit fallback, documented at the point of use. PDS does not yet have a single session-start capability probe that surfaces every gap at once; each instance above was found and fixed individually, after breaking. Naming the principle is what turns "fixed after it broke" into something contributors check for before shipping.

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

## Advisory, Not Enforcement

PDS has a shepherd agent that walks each swarm from Phase 1 through Phase 6. It reads the whitepaper, this file, and `docs/ethos.md` on spawn, and answers substance questions with citations — `docs/whitepaper.md:142`, `docs/philosophy.md § "Small, Reversible Steps"`. It writes to a project-level journal at `.claude/shepherd-journal.md` that persists across swarms; scout compacts it periodically.

**The shepherd never blocks work.** Its authority is citation, not enforcement. When a user overrides a principle, the shepherd logs the divergence and defers. When the same principle is overridden three times across swarms, the shepherd files a GitHub issue proposing whitepaper review — the living-whitepaper feedback loop driven by observed use, not opinion.

This is consistent with the first principle: the shepherd exists so agents and users can understand before they act. It is consistent with the fourth principle: by citing sources, it makes implicit conventions explicit. And it absorbs capacity that would otherwise sit idle — the orchestrator coordinates; the shepherd thinks about principles — without removing the human as final arbiter.

Routing: graph questions (dispatch, dependencies, phase state) go to the orchestrator. Substance questions (design, trade-offs, principle-checks) go to the shepherd. In lite swarms, the shepherd is skipped to keep the tier cheap — workers invoke `advisor_consult` directly when needed.

---

## Standing on Giants

- **Thompson & Ritchie** — Unix philosophy: do one thing well
- **Kent Beck** — TDD, XP: tests drive design
- **Martin Fowler** — Refactoring: continuous improvement
- **Sandi Metz** — Practical OO: small objects, clear interfaces
- **Rich Hickey** — Simple vs easy: choose simple
