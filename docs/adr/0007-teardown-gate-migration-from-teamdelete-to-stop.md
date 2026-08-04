# ADR 0007: Teardown Gate Migration — From `PreToolUse(TeamDelete)` to an Orchestrator-Scoped `Stop` Hook

## Status
Accepted

## Context

PDS's Phase 6 teardown gate (`hooks/scripts/orchestrator-teardown-gate.sh`) was defined as a `PreToolUse` hook matched on the tool name `TeamDelete`, in `agents/orchestrator.md`'s frontmatter. Its job: block team teardown unless the swarm's phase file reads `knowledge` and all three phase artifacts (`validation-report.md`, `review-report.md`, `scout-report.md`) exist, plus `.worktrees/` is clean and `docs/swarm-reports/` exists.

Confirmed against current official Claude Code documentation: **`TeamCreate` and `TeamDelete` no longer exist as tools, as of Claude Code v2.1.178.** Team formation and cleanup are now automatic — a team forms on the first teammate spawn, and tears down when the session ends. There is no tool call left for a `PreToolUse` matcher to bind to. The gate has had nothing to trigger on for as long as PDS has run against a Claude Code version at or past v2.1.178 — a real, currently-live enforcement gap, independent of the task-mobility work (ADR 0008) this surfaced alongside.

### What was confirmed before choosing the replacement

Rather than guess at the replacement mechanism, the following was checked directly against Claude Code's hooks documentation:

1. **`Stop` hook payload includes `cwd`.** A command-type `Stop` hook receives the same JSON-stdin shape as `PreToolUse` — `session_id`, `prompt_id`, `transcript_path`, `cwd`, `permission_mode`, `hook_event_name`, plus a `Stop`-specific `last_assistant_message`. The existing gate script reads only `.cwd` via `jq`, so its mechanical body ports unchanged.
2. **Command-type `Stop` hooks support exit-code-2 blocking**, the same mechanism `PreToolUse` hooks use (stderr becomes the block reason; the calling turn continues rather than the session ending). This matters because PDS's one existing `Stop` hook (on `validator.md`) is a *prompt*-type hook using `$ARGUMENTS` — a different mechanism than what this gate needs, since the teardown check is a deterministic file-existence check, not an LLM judgment call.
3. **Multiple `Stop` hooks compose as AND.** All matching hooks run in parallel; a block from any one of them blocks the stop, and none silently overrides another. A global/plugin-level `Stop` hook and this new orchestrator-scoped one do not conflict.
4. **`SessionEnd` cannot block** — it is advisory-only; exit code 2 shows a message but does not prevent the session from ending, and JSON output is ignored entirely. Despite the name reading like the more obvious fit for "session teardown," `SessionEnd` cannot do the one thing this gate needs to do.

All four were open risks going into this work and are now confirmed facts, not assumptions carried into production.

## Decision

Replace the `PreToolUse(TeamDelete)` gate with an **orchestrator-scoped `Stop` hook**, following the precedent `agents/validator.md` already set for agent-scoped `Stop` hooks (there, a prompt-type quality check; here, a command-type deterministic check — same scoping mechanism, different hook type, chosen because this check is mechanical, not judgment-based).

- `agents/orchestrator.md` frontmatter: remove `TeamCreate`, `TeamDelete` from `tools:`; move the `PreToolUse` block matched on `TeamDelete` to a `Stop:` block with no matcher (Stop hooks fire on the event, not a tool name).
- `hooks/scripts/orchestrator-teardown-gate.sh`: the mechanical body (phase check, three-report check, worktree-clean check, archive-dir check) carries over unchanged — it already read only `.cwd`, nothing `TeamDelete`-specific.
- **One necessary behavior change, not carried over as-is**: `Stop` fires on *every* orchestrator turn-end, not just an intentional teardown attempt (unlike the old gate, which only ever fired at the single call site that meant "tear down now"). Without a change, a Phase-1-only orchestrator returning a plan for human approval — a normal, documented mid-swarm handoff (see `skills/swarm/SKILL.md`'s two-phase delegation pattern) — would be wrongly blocked, since `.claude/swarm/` already exists but phase isn't `knowledge` yet. The script now passes through unconditionally whenever phase != `knowledge`, and only runs the full artifact/worktree/archive check when phase = `knowledge`. This preserves the gate's actual intent ("don't let a swarm end silently incomplete") while dropping the incidental side effect the tool-call-based version never had to consider.
- **The other TeamDelete-era guarantee — "TeamDelete fails if agents are still active" — has no mechanical replacement.** There is no tool call left to fail. The safeguard is now instruction-only: the orchestrator's own shutdown protocol (`SendMessage(shutdown_request)` to every agent, awaiting each `shutdown_response`, *before* attempting to stop) carries the full weight that used to be split between instruction and a hard tool failure. This is a real, named reduction in defense-in-depth — see Consequences.

## Consequences

### Positive
- Restores actual enforcement. The gate had been silently inert; it now fires and blocks exactly the case it was designed for.
- The failure mode it produces when triggered is not a hang: a blocking `Stop` hook (exit 2) continues the orchestrator's own turn with the reason as feedback, so the orchestrator can act (write the missing report, clear a leftover worktree) and retry — the same recoverable shape the old `TeamDelete`-call failure had.
- The phase-based pass-through fix (phase != `knowledge` → allow unconditionally) is a genuine improvement over a literal port: it makes the gate's actual intent (teardown-completeness) explicit, rather than leaning on "only called at the one right moment" as an implicit assumption that the tool-removal broke.

### Negative
- **No mechanical replacement for "TeamDelete fails if agents are still active."** If an orchestrator skips the shutdown-request protocol, nothing forces an error the way the old tool call did. This is now enforced by convention (see `skills/team/SKILL.md`'s rewritten "Shutdown before ending the swarm" note) rather than by a hard platform guarantee. Accepted, not silently dropped — named here and in `skills/team/SKILL.md` so a future contributor doesn't assume protection that no longer exists.
- `Stop` firing on every orchestrator turn-end (versus a single call site before) is a broader surface for the gate script to reason about correctly. The phase-based pass-through addresses the one failure mode identified during this work; a different edge case surfacing later would need the same scrutiny this ADR gave the current one.
- A swarm that can never satisfy the gate's conditions (e.g., a permanently un-removable worktree) will loop on stop attempts rather than fail outright — same characteristic as the old `TeamDelete`-call failure, but worth testing explicitly rather than assuming it inherited cleanly.

### Mitigations
- The instruction-only shutdown safeguard is stated explicitly, not left implicit, in both `skills/team/SKILL.md` and `skills/swarm/SKILL.md` Phase 6 — a future contributor reading either sees the gap and the reasoning, not silence.
- Verification (see below) specifically targets the phase-based pass-through, since that's the one behavior this migration had to *add*, not just port.

## Alternatives considered

### A. `SessionEnd` hook instead of `Stop`
Pros: name reads as the more natural fit for "session teardown."
Cons: confirmed advisory-only — cannot block, JSON output ignored. Disqualifying, not just suboptimal.
Rejected: `SessionEnd` cannot do the one thing this gate exists to do.

### B. Dual-purpose the existing global/plugin-level `Stop` hook instead of adding an agent-scoped one
Pros: one fewer hook definition to maintain.
Cons: the global `Stop` hook fires for every agent type, not just the orchestrator; folding orchestrator-specific teardown logic into it would require the script to detect agent type and branch, adding complexity to a hook that today has a different, simpler job. Confirmed hook composition (multiple `Stop` hooks run in parallel, AND-blocking) means there's no efficiency loss from keeping them separate.
Rejected: agent-scoped stays cleaner, and the validator's existing agent-scoped `Stop` hook is direct precedent for this pattern working correctly.

### C. Leave the gate inert and rely on skill-documented convention alone
Pros: zero implementation risk.
Cons: this is the status quo the research surfaced as a real, live gap — the gate has been enforcing nothing. Convention alone is exactly what hooks exist to backstop.
Rejected: the whole point of a mechanical gate is to not depend solely on an agent choosing to follow the skill correctly.

## Open questions

1. Should the gate script eventually attempt some approximation of "are any agents still active" (e.g., inspecting `~/.claude/tasks/session-<id>/` for tasks with a live owner) to partially restore the guarantee named as a negative consequence above? Not attempted here — depending on undocumented internal task-file formats contradicts this document's own caution about treating Claude Code internals as stable. Revisit only if the instruction-only safeguard proves insufficient in practice.
2. Does the phase-based pass-through need to account for any phase-skipping edge case not yet observed (e.g., an orchestrator that never writes a phase file at all, mid-development)? The existing "phase file missing → warn, fall through to artifact checks" behavior is unchanged from the original gate and covers this, but hasn't been stress-tested against the new every-turn-end firing frequency.
3. Cross-references (not edits) to `docs/adr/0001-hooks-enforcement-for-skills.md`, which first proposed `PreToolUse(TeamDelete)` as Tier 1 enforcement — that ADR is superseded in part by this one for the teardown-gate specifically; its other Tier 1/2/3 recommendations are unaffected.
