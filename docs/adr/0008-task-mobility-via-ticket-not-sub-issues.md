# ADR 0008: Task Mobility via the Existing Ticket, Not GitHub Sub-Issue Mirroring

## Status
Accepted

## Context

PDS tracks swarm state across three layers, and only one of them survives a change of machine or person:

- **Native Task-tool state** (`TaskCreate`/`TaskUpdate`/`TaskList`/`TaskGet`) lives at `~/.claude/tasks/{team-name}/` — file-locked, never uploaded, no cross-device sync. Per Claude Code's own docs, `/resume`/`/rewind` do not restore in-process teammates, so even same-machine resumption has a hard platform ceiling.
- **`.claude/swarm/*`** (phase, tier, `checkpoint.json`, ticket pointer) is entirely gitignored — local-only, gone the moment the working copy changes.
- **The GitHub ticket** (`/pds:ticket`) is the only externally durable layer today. It already carries the plan, the acceptance-criteria checklist, and phase-transition comments — real dev-diary content, not a bolt-on.

`/pds:pause` promised a `/resume` skill that never existed — a dangling, wrongly-namespaced reference (`/resume` instead of `/pds:resume`). That's the immediate bug. The larger question this ADR answers is what `/pds:resume` should actually read.

### The design that was considered and rejected

A full architecture was drafted first: mirror every `TaskCreate`d task to a GitHub sub-issue in real time via the official `github-mcp-server`, link dependencies via sub-issue relationships, and migrate `/pds:ticket`, `/pds:triage`, and `/pds:worktree` off `gh` CLI onto the same MCP server for a single consistent GitHub interface. This would have given per-task GitHub visibility, not just plan-level visibility.

Adversarial review found five independent problems with it, each sufficient on its own to reject the design:

1. **Hot-path latency.** Phase 3's pull-model task-claiming (`TaskList` → `TaskUpdate`) is deliberately fast and local. Mirroring every claim/status-change to a network call reintroduces exactly the "Waiting" waste PDS's own efficiency tooling (η, the Efficiency Ratio) is built to eliminate.
2. **New mid-swarm single point of failure.** GitHub outages or auth hiccups would sit on PDS's critical path with no clean degrade — a swarm's task claiming would depend on GitHub's availability, which today it explicitly does not.
3. **Rate-limit exposure.** A heavy swarm decomposing into 15-30 tasks in Phase 2 firing 15-30 near-simultaneous sub-issue creations plausibly trips GitHub's burst/abuse rate limiting — a self-inflicted failure mode that doesn't exist today.
4. **Clutter with no reader.** 15-30 sub-issues per swarm, most auto-closed minutes to hours later, is noise in a repo's issue tracker. Nobody reads sub-issue #47 of a swarm that finished before lunch.
5. **No remaining justification for the MCP migration.** `/pds:ticket`, `/pds:triage`, and `/pds:worktree` all work today on `gh` CLI, which is already a project dependency with a proven fallback pattern (see `/pds:ticket` section 4). Once sub-issue mirroring — the one thing that needed a richer API — is cut, migrating three working skills to a new MCP server and its own auth path has no benefit left to justify the migration risk.

Separately, the same research pass found that `docs/swarm-reports/` is **already git-tracked** and already contains `plan.md`, `context.md`, and `checkpoint.json` per swarm — exactly the artifacts a "what happened and why" resume needs for completed swarms. This means the actual gap was much narrower than the full design assumed: a gitignored ticket pointer, and a promised-but-unbuilt `/pds:resume` — not an absence of durable state altogether.

## Decision

Build `/pds:resume` against the ticket that already exists, with no new infrastructure:

- **No new MCP server.** `github-mcp-server` is not adopted. `gh` CLI remains the sole GitHub interface across `/pds:ticket`, `/pds:triage`, and `/pds:worktree` — unchanged.
- **No GitHub sub-issue mirroring.** Tasks stay exactly where they are: native `TaskCreate`/`TaskUpdate` locally, visible in the ticket only at the plan/acceptance-criteria granularity `/pds:ticket` already posts.
- **`/pds:pause` posts a comment, not a mirror.** On pause, if a real ticket number exists in `.claude/swarm/ticket`, post the pause state (branch, phase, tier, note) as a single `gh issue comment` — one already-proven API call, reusing the exact mechanism `/pds:ticket` uses for phase-transition comments.
- **`/pds:resume` reads in priority order**: local `.claude/swarm/checkpoint.json`/`pause.json` (same machine, full fidelity) → the ticket's comment thread (cross-machine/person, coarser fidelity — task list is reconstructed from the acceptance-criteria checklist, not the original fine-grained decomposition) → `docs/swarm-reports/<timestamp>/` (completed swarms, already archived and git-tracked).
- **Discovery for zero-local-state resume** uses a new `pds-active-swarm` label, applied by `/pds:ticket` at creation/reuse and removed at Phase 6 teardown — cheap, and built entirely from commands `/pds:ticket` already runs.
- **In-flight task recovery accepts platform limits.** Previous workers cannot be reattached (no tool exists for it). Stale `in_progress` tasks are recreated as `pending` with owner cleared; Phase 3's normal pull-model redispatch handles the rest. Git-branch partial-completion inspection is explicitly deferred to a v2 follow-up, not built speculatively now.

## Consequences

### Positive
- Fixes a real, currently-broken dangling reference (`/pds:pause` promising a skill that doesn't exist) with no new dependency.
- Closes the actual mobility gap — cross-machine/cross-person resume — for the cost of one `gh issue comment` call per pause, reusing infrastructure that already works.
- Keeps Phase 3's task-claiming hot path exactly as fast as it is today; nothing new sits on it.
- Avoids introducing GitHub as a mid-swarm dependency — today's design (ticket only touched at phase boundaries, never per-task) keeps GitHub availability off the critical path.
- Leaves `/pds:ticket`, `/pds:triage`, and `/pds:worktree` untouched — no migration risk taken for a benefit (per-task GitHub visibility) that adversarial review found wasn't worth its cost.

### Negative
- Cross-machine/cross-person resume is **lossy by design** — the reconstructed task list is only as granular as the ticket's acceptance-criteria checklist, not the original session's fine-grained `TaskCreate` decomposition. A different person picking up a swarm gets a coarser starting point than the original orchestrator had.
- In-flight task recovery in v1 has no way to detect that a "stale in_progress" task is actually 80% done on an unmerged branch — it gets redispatched from scratch. This is an accepted gap, not a hidden one (see Decision, discovery/in-flight sections).
- The `pds-active-swarm` label is another piece of GitHub state to keep in sync (applied/removed at the right points) — a small ongoing discipline cost, though far smaller than sub-issue mirroring's.

### Mitigations
- The fidelity loss on cross-machine resume is surfaced explicitly to the user by `/pds:resume` (see `skills/resume/SKILL.md` Rules) rather than silently presented as a full recovery.
- The v2 git-branch-inspection follow-up is named explicitly in `/pds:resume` rather than left as an implicit limitation — if in-flight loss proves costly in practice, there's a clear next step already identified.
- If `pds-active-swarm` label hygiene drifts (label not removed on teardown), the cost is a false-positive discovery candidate resolved by `AskUserQuestion` disambiguation — not a silent wrong resume.

## Alternatives considered

### A. GitHub sub-issue mirroring via `github-mcp-server` (the rejected full design)
Pros: per-task GitHub visibility; dependency links visible outside the terminal; a single consistent GitHub interface across all ticket-touching skills.
Cons: all five problems in Context above — hot-path latency, mid-swarm SPOF, rate-limit exposure, clutter, and no remaining justification for the MCP migration once mirroring itself is cut.
Rejected: the combined cost outweighs a visibility benefit that, per Context, nobody was shown to actually need — the ticket's plan-level view already served every real use case surfaced during review.

### B. Do nothing beyond fixing the `/resume` → `/pds:resume` typo
Pros: minimal change; fixes the one confirmed-broken reference.
Cons: leaves the actual mobility gap (cross-machine/cross-person resume) unaddressed — the typo fix alone doesn't make anything resumable that wasn't already.
Rejected: the user's request was explicitly about mobility, not just the dangling reference; a real fix was available at low cost (one `gh issue comment` call, one label) once the sub-issue-mirroring design was cut down to size.

### C. Cross-machine resume via a shared filesystem or cloud sync (e.g. S3, a shared drive)
Pros: could carry full fidelity (the actual `checkpoint.json`, not a reconstruction) across machines.
Cons: introduces new infrastructure and a new sync dependency for a problem GitHub already solves at the granularity that matters (plan + acceptance criteria); duplicates what `/pds:ticket` already does durably.
Rejected: not evaluated in depth once the ticket was confirmed sufficient for the resume protocol's actual needs — adding infrastructure to recover fidelity the ticket doesn't carry contradicts the "right-sized" framing of this decision.

## Open questions

1. If in-flight task loss (no git-branch partial-completion detection) proves costly in practice, what does the v2 inspection logic look like — diffing the stale branch against its base, or something simpler? Deferred until real swarms surface the need.
2. Should `/pds:resume`'s coarser cross-machine task list eventually get richer — e.g. by having `/pds:ticket` post the full `plan.md` content into the ticket body rather than just the acceptance-criteria checklist? Not resolved here; would need its own evaluation of ticket-body size and readability trade-offs.
3. Does `pds-active-swarm` label hygiene need its own enforcement (a hook checking the label matches `.claude/swarm/phase` state) or is manual discipline via the `/pds:ticket` checklist sufficient? Revisit if label drift is observed in practice.
