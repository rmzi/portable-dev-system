# Model-Agnostic Strategy Research — Issue #94
*Researcher: auto-generated, April 2, 2026*

---

## Problem Statement

Issue #94 asks: what is PDS's strategy for model independence? The existing memory note established the key finding — Claude Code has zero model abstraction. This document updates and expands that analysis with 2026 developments, identifies actionable portability improvements for PDS, and specifies what would need to change if Claude Code ever added multi-model support.

---

## Key Finding: Claude Code Remains Hardwired to Anthropic (March 2026)

The March 2026 source analysis confirmed what prior research established: **Claude Code has no model abstraction layer**.

From `services/api/claude.ts` (126k):
```typescript
import type {
  BetaMessage,
  BetaMessageStreamParams,
  BetaRawMessageStreamEvent,
  BetaToolUnion,
  BetaToolResultBlockParam,
  // ... 20+ more Anthropic-specific types
} from '@anthropic-ai/sdk/resources/beta/messages/messages.mjs'
```

From `services/api/client.ts`:
```typescript
export type APIProvider = 'firstParty' | 'bedrock' | 'vertex' | 'foundry'
```

All four providers are deployment targets for Claude models. There is no OpenAI provider, no Ollama provider, no generic interface. Anthropic's "multi-provider" offering is multi-deployment of Claude, not multi-model.

The model registry in `utils/model/configs.ts` defines 11 model configurations — all Claude variants from Haiku 3.5 through Opus 4.6. No slots for external models.

**This has not changed since the prior analysis. Claude Code is not pursuing LLM agnosticism as a product goal.**

---

## 2026 Developments: The Proxy Path

A community workaround has emerged and matured since the original analysis. Three mechanisms now exist for running Claude Code with non-Anthropic models:

### 1. ANTHROPIC_BASE_URL Proxy

Claude Code's API client respects `ANTHROPIC_BASE_URL` as a proxy endpoint. Any server that speaks the Anthropic API format can intercept and reroute requests:

```bash
export ANTHROPIC_BASE_URL="https://my-proxy.example.com"
export ANTHROPIC_API_KEY="my-key"
```

The proxy receives Anthropic-format requests and translates them to the target model's format.

### 2. Model Tier Overrides

Environment variables allow overriding which model serves each tier:

```bash
export ANTHROPIC_DEFAULT_SONNET_MODEL="openai/gpt-5"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="google/gemini-flash"
```

This lets PDS's swarm tier model assignments (`model: "haiku"` for lite workers) redirect to non-Anthropic models while the harness stays identical.

### 3. Proxy Gateways (Community)

- **Bifrost CLI** — Routes Claude Code through a gateway supporting 20+ providers (OpenAI, Azure, Google Vertex/Gemini, AWS Bedrock, Mistral, Groq, Ollama, and more). Automates configuration via CLI setup.
- **LiteLLM** — OpenAI-compatible proxy gateway; supports similar provider routing.
- **OpenCode** — Alternative CLI that is model-agnostic by design, treating models as interchangeable engines. Not Claude Code-compatible but represents the category.

**Critical constraint for all proxy approaches:** The target model **must support tool calling**. Claude Code's core operations (Read, Write, Edit, Bash, Agent, Task*) all use tool use blocks. Models without robust tool use support break Claude Code's agentic loop.

---

## PDS's Current Portability Position

PDS leverages Claude Code's extension points, all of which are expressed in markdown and JSON:

| Extension Point | Format | Model-Specific? |
|-----------------|--------|-----------------|
| `CLAUDE.md` | Markdown | No — plain prose instructions |
| Skills (`.claude/skills/`) | Markdown | Weakly — uses Claude idioms (e.g., "use the Skill tool") |
| Agent definitions (`agents/*.md`) | Markdown + frontmatter | Weakly — tool names are Claude Code-specific |
| Hooks (`hooks/hooks.json`) | JSON + shell scripts | No — shell scripts are model-agnostic |
| Hook responses | JSON | Weakly — field names like `updatedInput` are Claude Code API |
| Settings (`.claude/settings.json`) | JSON | No — structural config only |
| Plugin manifest (`plugin.json`) | JSON | No — registry metadata |
| MCP servers | JSON | No — MCP is already model-agnostic by design |

**PDS is already more model-agnostic than Claude Code itself.** The extension points are stable public API surface unlikely to change without notice. If PDS ever builds its own harness or ports to an alternative CLI, these artifacts transfer with minimal adaptation.

### Where Claude-Specificity Creeps In

Despite being markdown/JSON, PDS artifacts contain Claude idioms that would need updates in a non-Claude environment:

1. **Tool name references** — Skills reference Claude Code tool names by name (`Agent`, `TaskCreate`, `Skill`). A different harness would have different tool names.
2. **Extended thinking** — Some agent definitions implicitly assume extended thinking is available (Opus-class reasoning). Models without extended thinking may not follow multi-step SDLC instructions faithfully.
3. **Permission model** — Hook responses use Claude Code permission fields (`decision: "approve"/"block"`, `permissionDecision`). These are harness-specific.
4. **`run_in_background` parameter** — Used in dispatch patterns; this is a Claude Code-specific tool parameter.
5. **Swarm tier model IDs** — Hardcoded model IDs in agent definitions (`model: "haiku"`) are Claude-specific strings.

---

## What Would Need to Change If Claude Code Added Multi-Model Support

If Anthropic added a model abstraction layer (hypothetically), here is what PDS would need to update:

### Low Effort (Find-and-Replace)

- **Model IDs in agent definitions** — Replace `"claude-haiku-4-5-20251001"` with a capability tag like `"tier:fast"` and let the harness resolve to the appropriate model
- **Model tier env vars** — Already supported; would become the canonical path

### Medium Effort (Design Work)

- **Extended thinking fallback** — Skills that rely on deep reasoning need a compatibility note: "if extended thinking is unavailable, this agent may produce lower-quality plans." The SKILL.md frontmatter could add `requires_extended_thinking: true`.
- **Tool capability requirements** — Agent definitions could declare required tools. A hypothetical `capabilities: [tool_use, file_access]` frontmatter field would let PDS's installer verify the harness supports what the agent needs.
- **Hook response field portability** — If hook response field names change between harnesses, PDS's shell scripts would need conditional logic or an adapter layer.

### High Effort (Architecture Work)

- **Harness replacement** — If PDS ever abandons Claude Code as the runtime (e.g., ports to OpenCode or a self-hosted harness), the following require re-implementation: the agentic loop, the tool execution pipeline, the agent/team spawning mechanism, the permission system, and the compaction strategy. PDS's markdown artifacts would port; the infrastructure underneath them would not.

---

## Actionable Recommendations

### Immediate (No Code Changes)

1. **Document the proxy path.** Add a section to `docs/` or CLAUDE.md explaining the `ANTHROPIC_BASE_URL` + gateway approach for organizations that need model choice. This is already functional and requires zero PDS changes.

2. **Document the model tier override mechanism.** Users who want cost-optimized tiers with different providers can use `ANTHROPIC_DEFAULT_SONNET_MODEL` / `ANTHROPIC_DEFAULT_HAIKU_MODEL`. PDS's swarm tier assignments already use these tiers.

### Short-Term (Design-Level)

3. **Add `requires_tool_use: true` (implicit) to all agent definitions.** When Anthropic or a future harness adds a "lite mode" without full tool support, PDS agents need a way to declare they require it. Today this is obvious but undocumented; make it explicit.

4. **Audit skills for extended-thinking dependence.** Walk through all 23 skills and identify which rely on multi-step reasoning that degrades without extended thinking. Flag these in their frontmatter with a `reasoning_depth: high` marker. This is low-cost insurance.

5. **Decouple model IDs from agent definitions.** Replace hardcoded model strings with capability tier labels (`fast`, `balanced`, `capable`). Map tier labels to model IDs in a central config file. When Anthropic ships a new model, update one file instead of all agent definitions.

### Long-Term (If/When Needed)

6. **Evaluate OpenCode as a parallel target.** OpenCode is model-agnostic by design. Running PDS skills against OpenCode would reveal exactly what needs adaptation and would give PDS a second runtime target — reducing single-vendor risk.

7. **MCP-first tool design.** MCP is the only truly model-agnostic layer in the current ecosystem. Migrating PDS's external integrations (telemetry, instinct capture, artifact archival) to MCP servers would make those integrations portable to any harness that supports MCP.

---

## Summary

| Dimension | Status | Risk |
|-----------|--------|------|
| Claude Code portability | None today | High if CC drops PDS extension points (unlikely) |
| PDS artifact portability | High — markdown/JSON | Low |
| Extended thinking dependence | Moderate — implicit | Medium if non-Claude target |
| Model ID hardcoding | Low-medium | Low — env var overrides exist |
| Proxy path viability | Functional today | Low — community has proven it |
| Full harness replacement | Not needed now | High effort if ever needed |

PDS is well-positioned. No urgent changes are required. The proxy path exists for organizations that need model choice today. The recommended improvements are defensive — they reduce future adaptation cost without changing current behavior.

---

## Next Steps

- [ ] Add proxy path documentation to `docs/` (ANTHROPIC_BASE_URL + Bifrost/LiteLLM pattern)
- [ ] Audit 23 skills for extended-thinking dependence; add `reasoning_depth` frontmatter where relevant
- [ ] Replace hardcoded model IDs in agent definitions with capability tier labels
- [ ] Issue #94 can be closed once proxy docs are added

---

*Sources: [Claude Code source analysis](./claude-code-source-analysis.md) · [PDS LLM-agnostic strategy memory](~/.claude/projects/-Users-rmzi-dev-tools-portable-dev-system/memory/pds_llm_agnostic_strategy.md) · [Bifrost CLI article](https://www.getmaxim.ai/articles/running-claude-code-with-non-anthropic-models-using-bifrost-cli/) · [OpenCode comparison](https://www.infralovers.com/blog/2026-01-29-claude-code-vs-opencode/)*
