# ADR 0006: The Harness Layer Thesis — Naming PDS's Position in the Model-Harness-Methodology Stack

## Status
Proposed

## Context

PDS today is a configuration layer — skills, agents, hooks, all markdown/JSON — riding on top of Claude Code, which is itself a generic harness (tool loop, context management, permissions, worktree provisioning) around the raw model. Put plainly: PDS is a harness on a harness. This has been the right call so far — see the whitepaper's "LLM Independence" section, which explains why riding a generic harness gets PDS context compression, IDE integration, and model access for free without PDS having to build any of it.

But the agentic SDLC's actual content — the phase model, the swarm tiers, the defense-in-depth enforcement — is not generic best practice pulled from Claude Code's docs. It's DevOps judgment about how autonomous agents should move through a software lifecycle. That judgment is currently expressed entirely as configuration sitting on top of someone else's tool loop, and a generic harness's config surface can only carry so much of it before it wants to become the harness itself.

This session's research (a 12-week industry catch-up, 2026-Q2/Q3) surfaced real external vocabulary and validation for this observation that didn't exist when the whitepaper was last substantively updated (v3.0, April 2026):

- **Harness engineering** emerged as a named discipline in early 2026: an OpenAI internal-infrastructure writeup prompted Mitchell Hashimoto (Terraform, Ghostty) to coin "Agent = Model + Harness"; Martin Fowler and Birgitta Böckeler extended it into a "guides and sensors" taxonomy. Fowler is already whitepaper reference [3] for context engineering — this is the same author/site describing the layer directly above what PDS already cites him for.
- **Gartner** projects more than half of enterprise GenAI models will be domain-specific by 2027 (up from 1% in 2024), with small task-specific models outnumbering general-purpose LLM usage 3:1 by the same year.
- **Anthropic itself** now ships two harnesses, not one — Claude Code for engineering, Claude Cowork for general knowledge work (expanded to mobile/web July 2026, >90% non-software usage). Even the platform vendor is betting one generic harness doesn't fit every domain.

Separately, the same research pass found that "agentic SDLC" itself genericized industry-wide in 2026 (PwC, Port.io, CodeRabbit, Codebridge, Beam all publishing similar frameworks), and that direct methodology analogs exist (GitHub Spec Kit, BMAD-METHOD, AWS Kiro) that `docs/competitive-analysis.md` didn't mention until this pass. BMAD-METHOD in particular — the closest analog to PDS's own multi-agent-role model — has documented, GitHub-issue-sourced cost/context blowouts (80-100x token usage, users hitting Max-plan rate limits daily) traceable to having no lightweight mode. This gives PDS's lite/med/heavy swarm tiers external validation they didn't have before: not just an internally-reasoned cost optimization, but a design choice proven out by someone else's production failures.

## Decision

Add a new standalone whitepaper section, "The Harness Layer: Where PDS Sits Today," positioned between Core Technical Concepts and Platform Positioning. The section:

1. States the model → harness → methodology-as-config stack plainly, and names PDS's current position on it honestly (a config layer on a generic harness).
2. Cites harness engineering and the Gartner/Cowork signals as external vocabulary and validation for an intuition reached independently — not as the idea's origin.
3. States a directional next move: PDS owning more of the harness layer itself over time, with domain-specific model pairing as a longer-horizon bet.
4. Holds an explicit, in-text non-claims boundary: no custom harness exists today, no timeline, no domain-specific model in development, Claude Code remains PDS's substrate.

Bump the whitepaper's own version header to v4.0 to mark this as a significant addition, distinct from (and not requiring) a major bump to the PDS package's own semver — this is a docs-only change with no skill or agent contract changes, so the package bump at `/pds:finish` should be minor.

Do not begin any implementation work toward a custom harness or domain-specific model in this pass. Do not fold this into Platform Positioning (register mismatch — that section is comparative/current-state; this thesis is directional/future-state) or limit it to Executive Summary/Conclusion bookends (insufficient weight for what this represents).

## Consequences

### Positive
- Gives PDS's future strategic direction a named, citable vocabulary ("harness," "harness engineering") instead of leaving it as an unstated intuition.
- Retroactively strengthens the swarm-tier design: BMAD's documented cost failures are now cited as external validation of a choice PDS made independently.
- Extends the whitepaper's own "living document" claim (Conclusion) with a concrete instance of the document evolving through observed industry movement, not just PDS's internal implementation experience.
- Creates a natural anchor for future ADRs if/when concrete harness-ownership work begins.

### Negative
- Publishing a directional thesis without a concrete architecture invites "what does this actually mean" scrutiny — a section that gestures at owning more of the harness layer without specifics can read as aspiration rather than engineering.
- Creates an implicit expectation that a future Adoption Path phase or ADR will eventually make this concrete; if it doesn't, the section ages into an unfulfilled prediction.
- The domain-specific-model bet is currently unfalsifiable — there's no way to check progress against it until PDS actually starts building toward it.

### Mitigations
- The non-claims boundary is written directly into the section's text, not left implicit — future readers (including future PDS maintainers) see the scope limit in the same place as the claim.
- Any real implementation work toward harness ownership routes through its own future ADR rather than retroactively expanding this one's scope.
- The section is explicitly framed as "where the evidence pointed this quarter," consistent with the whitepaper's existing practice of dating vision-forward claims (LLM Independence's abstraction-boundary strategy, Adoption Path Phase 3/4) rather than presenting them as timeless.

## Alternatives considered

### A. Fold into Platform Positioning
Pros: avoids a new top-level section; keeps all "where PDS stands" content in one place.
Cons: Platform Positioning is a comparative, current-state argument ("where PDS leads / where Anthropic leads"); this thesis is directional and future-facing. Mixing registers would muddy both.
Rejected: register mismatch outweighs the organizational convenience.

### B. Bookend only in Executive Summary and Conclusion
Pros: minimal document surface area; avoids over-committing to unwritten architecture.
Cons: a few sentences can't carry the external validation (harness engineering lineage, Gartner data, Cowork evidence) that makes this more than a hunch. Insufficient weight for a major version bump.
Rejected: the whole point is that this intuition now has real external support — that support needs room to be shown, not just asserted.

### C. Wait for concrete architecture before publishing anything
Pros: avoids publishing an unfalsifiable claim; only ships when there's something real to describe.
Cons: the whitepaper's value comes partly from its living-document cadence — capturing directional thinking when the evidence arrives is the same pattern already used for LLM Independence and Adoption Path Phase 3/4, both published well before those capabilities existed.
Rejected: the non-claims boundary (Decision, above) is the safeguard against overclaiming; waiting for architecture would contradict the document's own established practice.

## Open questions

1. What does "owning more of the harness layer" concretely mean in PDS's case — a custom tool-execution wrapper, a forked SDK layer, a standalone CLI, something else? Not resolved by this ADR; deferred to whenever real implementation work begins.
2. How does this interact with the Agent SDK subscription/credits uncertainty (announced, then paused, June 2026)? If PDS ever runs its own harness, its billing relationship with Anthropic's API is an open question this ADR doesn't answer.
3. When does the domain-specific-model bet get revisited, and what would count as evidence it's worth pursuing vs. abandoning?
4. Should this ADR be revisited once/if Adoption Path Phase 3 (cloud infrastructure) work actually begins, given both describe PDS's infrastructure ambitions from different angles?
