# Research Report: Source Analysis Insights for Whitepaper

## New Insights to Weave Into Whitepaper Main Body

### 1. Tool Deferral and PDS Skill Discovery (→ Instruction Architecture section)

The source analysis reveals that Claude Code uses **tool deferral** via `ToolSearch` — not all 35+ tool schemas are sent upfront. Less-common tools appear only as names in `<system-reminder>` blocks. The model calls `ToolSearch` to fetch full schemas on demand. This mirrors PDS's own skill discovery pattern (skills listed in CLAUDE.md table, full content loaded on `/pds:invoke`). The parallel is worth noting: PDS's dual-layer approach (passive listing + on-demand loading) independently converged on the same optimization Claude Code uses for its own tools. This validates PDS's instruction architecture as aligned with platform-native patterns.

**Target section:** Instruction Architecture — add paragraph after the dual-layer description.

### 2. Streaming Tool Parallelism Benefits PDS Workers (→ Phase 3 section)

`StreamingToolExecutor` enables tool execution to overlap with response generation — when the model emits multiple tool_use blocks, Claude Code begins executing them before the full response completes. This is a significant performance win for PDS workers that chain multiple tool calls (read file → edit → run tests). PDS gets this for free but should document it as a platform benefit that makes agentic workflows viable. Workers don't pay a serial penalty for multi-tool turns.

**Target section:** Phase 3 (Parallel Execution) — note platform optimization that benefits workers.

### 3. Fork-Subagent vs PDS Specialized-Agent Trade-offs (→ Agent Isolation / Native Agent Teams)

The `FORK_SUBAGENT` feature flag enables forking the parent's full conversation context into a child. The child inherits the parent's system prompt (byte-exact for cache efficiency) and full conversation history. This is fundamentally different from PDS's model where each agent starts fresh with its own role-specific system prompt. Fork subagents optimize for "do this subtask with full context" — PDS agents optimize for "play this specialized role." The trade-off: fork subagents get better context but no role specialization; PDS agents get focused behavior but must rebuild context. PDS could use fork subagents for quick subtasks within a phase while keeping specialized agents for cross-phase roles.

**Target section:** Native Agent Teams — add trade-off paragraph.

### 4. Enterprise Lockdown and PDS Survival (→ Governance and Security)

Three enterprise controls matter:
- `strictPluginOnlyCustomization` — blocks non-plugin customizations. **PDS survives** because it IS a plugin.
- `strictKnownMarketplaces` — only approved marketplace plugins install. PDS needs marketplace presence.
- `allowManagedHooksOnly` — only managed-settings.json hooks execute. **This blocks PDS hooks.** PDS would need to be distributed as a managed-settings-compatible package for enterprise use.

**Target section:** Governance and Security — add enterprise readiness subsection.

### 5. Compaction Strategy Impact on Long Swarms (→ Context Compression)

The source reveals FIVE compaction modes, not three:
1. Auto-compact (monitors token usage, triggers before limit)
2. Micro-compact (targeted compaction of individual tool results)
3. Reactive compact (real-time during streaming — feature-gated)
4. Context collapse (aggressive folding — feature-gated)
5. History snip (trim old history entirely — feature-gated)

The main compaction uses the LLM itself to summarize — creating a boundary where everything before is summarized, everything after is verbatim. This is critical for PDS because long swarms WILL hit compaction. When it fires mid-phase, the LLM's summary may lose PDS-specific context (current phase, task statuses, decisions). The PreCompact/PostCompact hook opportunity is already in the whitepaper but should be strengthened with the 5-mode detail.

**Target section:** Context Compression — update with 5 modes and strengthen PreCompact/PostCompact argument.

### 6. Hook Response Capabilities PDS Doesn't Use (→ Hook Lifecycle)

Two powerful capabilities PDS hasn't exploited:
- `updatedInput` — modify tool parameters BEFORE execution. PDS could use this to inject PDS context into tool calls (e.g., ensure Bash commands run in correct worktree).
- `updatedMCPToolOutput` — modify MCP tool results AFTER execution. PDS could use this to sanitize or enrich MCP tool outputs.

**Target section:** Hook Lifecycle — note untapped capabilities as known gaps.

### 7. Cache Efficiency is Per-Agent, Not Shared (→ Cost Considerations)

Each agent spawn creates a NEW conversation with its own prompt cache. Cache efficiency is per-agent, not shared across the swarm. This means a 4-worker swarm builds 4 separate caches — the orchestrator's cache doesn't help workers, and workers don't help each other. This has cost implications: the first few turns of each agent pay full input price while the cache warms up. PDS's shared-rules.md (inherited by all agents) helps — agents with similar system prompts may get partial cache hits if the shared prefix is byte-identical. But fundamentally, more agents = more cache warming cost.

**Target section:** Cost Considerations — add cache efficiency section.

### 8. Tool Result Storage and Validator Merges (→ Phase 4)

Large tool results are stored externally and replaced with references in the conversation. The content is available if the model requests it, but the reference persists in the conversation. This matters for the validator: when merging branches and running tests, large test outputs may get stored externally. The validator's report should reference specific test results, not assume they're inline. This is a platform detail that affects how PDS structures its validation report schema.

**Target section:** Phase 4 (Validation) — note tool result storage implication.

### 9. Feature Flag Competitive Framing (→ new "Where PDS Leads" paragraph)

The source analysis identifies a clear competitive split:
- **PDS leads on:** Structured agent workflows (6-phase SDLC with role specialization), workflow enforcement (grill → implement → verify → finish), quality gates (SDLC-enforcing hooks), swarm tiers (cost-aware model selection)
- **Anthropic leads on:** Context management (61k of compaction code vs PDS zero), intelligence (ML classifiers for bash safety, permission auto-mode), IDE integration (native VS Code/JetBrains bridge), memory extraction (auto-memory)

This framing should appear in the whitepaper's main body, not just the appendix. It positions PDS as the methodology layer that complements platform capabilities.

**Target section:** Add to Engineering Best Practices or create a new "Platform Positioning" section.

### 10. Shared-Rules Reference and Agent Inheritance (→ Agent Isolation)

The update-wp whitepaper mentions `shared-rules.md` but the source analysis reveals WHY it matters: agents with similar system prompts get cache efficiency when the shared prefix is byte-identical. This means PDS's `inherits: shared-rules` frontmatter pattern isn't just about DRY principles — it's a cost optimization. Shared rules should be placed at the TOP of agent system prompts so the shared prefix maximizes cache hits.

**Target section:** Agent Isolation (defense layer 5) — strengthen shared-rules rationale with cache insight.

## Summary

10 insights identified. At least 7 should go into the whitepaper's main body sections (not just Appendix D). The acceptance criteria require at least 5 in the main body.
