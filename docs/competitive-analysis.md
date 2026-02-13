# Competitive Analysis — February 2026

Landscape scan of opinionated Claude Code SDLC approaches, multi-agent orchestration, and memory management as of February 2026.

---

## Direct Competitors

### everything-claude-code (affaan-m)

**Repo:** [github.com/affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code)

Battle-tested configs from an Anthropic hackathon winner. 12 agents, 24 commands, 16 skills, 20+ hook event types, 3 native custom tools (run-tests, check-coverage, security-audit).

**Differentiators vs PDS:**
- Plugin-based distribution via OpenCode marketplace (PDS uses curl install)
- Security scanning tool that grades your CLAUDE.md/settings.json (A-F)
- "Instinct-based learning" — commands for viewing, importing, exporting instincts that evolve into skills
- Python/Django and Java Spring Boot skill packs (domain-specific)

**PDS advantages:** Whitepaper-backed SDLC methodology, worktree isolation architecture, zero-duplication install modes, context compression methodology with documented fidelity cliff.

### claude-flow (ruvnet)

**Repo:** [github.com/ruvnet/claude-flow](https://github.com/ruvnet/claude-flow)

Large-scale agent orchestration platform. 60+ agents, 170+ MCP tools, SONA self-learning, RuVector vector DB. Claims 84.8% SWE-Bench, 352x faster WASM execution, ~100k MAU.

**Differentiators vs PDS:**
- External orchestration layer (TypeScript/WASM runtime) vs PDS's native Claude Code approach
- Hierarchical (queen/workers) and mesh (peer-to-peer) swarm patterns
- Built-in vector DB (RuVector) for knowledge retrieval
- Docker container isolation per agent

**PDS advantages:** Zero external dependencies (pure Claude Code config), lighter weight, git worktree isolation (no containers), opinionated SDLC phases with human gates. Claude-flow is infrastructure; PDS is methodology.

### Claude Code Agentrooms

**Site:** [claudecode.run](https://claudecode.run/)

Multi-agent development workspace that routes tasks to specialized AI agents with @mentions orchestration.

**Differentiators vs PDS:** Visual workspace UI, @mention-based routing.

**PDS advantages:** No external service dependency, works in any terminal, committed to repo for team sharing.

---

## Adjacent Projects

### OneContext

**Repo:** [github.com/TheAgentContextLab/OneContext](https://github.com/TheAgentContextLab/OneContext)

Persistent context layer that sits above coding agents. Auto-manages and syncs context across sessions, devices, and agents (Codex/Claude Code). Built by Junde Wu; got him an instant interview at Google AI.

**Key idea:** Every new agent session inherits full project memory without manual context loading. Shared context via links for team collaboration.

**Relevance to PDS:** PDS solves this with CLAUDE.md + agent memory files + `.pds-version` auto-update. OneContext is more ambitious (cross-device, cross-tool sync) but adds a dependency. Worth watching for ideas on cross-session memory.

### Vercel agent-skills

**Repo:** [github.com/vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills)

Vercel's official agent skills collection + AGENTS.md. Their [eval blog post](https://vercel.com/blog/agents-md-outperforms-skills-in-our-agent-evals) is foundational research PDS already cites: compressed 8KB AGENTS.md achieves 100% pass rate vs skills at 79%.

**PDS already incorporates this:** Dual-layer architecture (passive CLAUDE.md + explicit skills) directly informed by Vercel's findings.

### danielmiessler/Personal_AI_Infrastructure

**Issue:** [github.com/danielmiessler/Personal_AI_Infrastructure/issues/540](https://github.com/danielmiessler/Personal_AI_Infrastructure/issues/540)

Discussion of Vercel eval implications for personal AI infrastructure. Debating passive context vs active skill retrieval at the personal/user level.

**Relevance:** PDS's user-level install (`--user`) with conditional skill fallback is a direct answer to this question.

---

## Thought Leadership

### Martin Fowler / Birgitta Böckeler — "Context Engineering for Coding Agents"

**Post:** [martinfowler.com/articles/exploring-gen-ai/context-engineering-coding-agents.html](https://martinfowler.com/articles/exploring-gen-ai/context-engineering-coding-agents.html)

Defines context engineering as "curating what the model sees so that you get a better result." Notes that Claude Code leads in context configuration options, with other assistants following. Two categories: instructions (do X) vs guidance (follow convention Y).

**Key insight:** Build context files gradually. Models are powerful enough that over-stuffing context hurts more than helps.

**PDS alignment:** Strong. PDS's `/trim` skill and fidelity cliff lesson directly address this. The whitepaper's context compression section codifies what Fowler describes as emergent best practice.

### Anthropic — "Effective Context Engineering for AI Agents"

**Post:** [anthropic.com/engineering/effective-context-engineering-for-ai-agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)

Anthropic's own guidance on context engineering for agents.

### The New Stack — "Memory for AI Agents: A New Paradigm of Context Engineering"

**Post:** [thenewstack.io/memory-for-ai-agents-a-new-paradigm-of-context-engineering/](https://thenewstack.io/memory-for-ai-agents-a-new-paradigm-of-context-engineering/)

Large context windows improved short-term coherence but did NOT solve memory. Once the window closes, the system forgets. The 2026 production standard is Dual-Layer Memory: hot path (immediate context) + cold path (external store retrieval).

**PDS alignment:** PDS's agent memory system (`.claude/agent-memory/{agent}/MEMORY.md`) is a lightweight version of this. The 200-line MEMORY.md cap is the hot path; topic-specific files linked from MEMORY.md are the cold path. No vector DB needed for the common case.

### HuggingFace — "2026 Agentic Coding Trends"

**Post:** [huggingface.co/blog/Svngoku/agentic-coding-trends-2026](https://huggingface.co/blog/Svngoku/agentic-coding-trends-2026)

Engineers shifting from writing code to coordinating agents. Central orchestrator + specialist sub-agents is the emerging standard.

**PDS alignment:** This is exactly the 6-phase Agentic SDLC model PDS implements.

---

## Memory Management Landscape

| Approach | Implementation | PDS Status |
|----------|---------------|------------|
| CLAUDE.md as session memory | Markdown in system prompt, loaded every turn | Implemented |
| Agent-scoped persistent memory | Per-agent MEMORY.md files, capped at 200 lines | Implemented |
| Cross-session context sync | OneContext, shared memory layers | Not implemented (out of scope) |
| Vector DB retrieval | claude-flow RuVector, Mem0 | Not implemented (git-backed markdown suffices) |
| Dual-layer hot/cold | Hot = MEMORY.md, cold = topic files | Implemented (lightweight) |
| Context compression | Documented methodology with fidelity cliff | Implemented via /trim |

---

## PDS Positioning

PDS occupies a unique niche: **opinionated methodology as configuration**.

- **claude-flow** is infrastructure (runtime, containers, vector DB)
- **everything-claude-code** is a config collection (many skills, no methodology)
- **PDS** is a methodology encoded as config (SDLC phases, human gates, agent tiering, context compression, worktree isolation)

The closest analogy: claude-flow is Kubernetes, everything-claude-code is a dotfiles repo, PDS is the Twelve-Factor App manifesto — but shipping as config you can install.

---

## Opportunities

1. **Security scanning** — everything-claude-code's A-F grading tool for settings.json is clever. PDS could add a `/audit-config` skill.
2. **Instinct → skill evolution** — everything-claude-code's instinct system (auto-learning from patterns) is worth watching. PDS's scout agent partially fills this role.
3. **Cross-session context** — OneContext's approach to syncing context across devices/sessions addresses a real gap. PDS's user-level install partially solves this for a single machine.
4. **Domain skill packs** — everything-claude-code ships Python/Django and Java skill packs. PDS's addon system is ready for this but no packs exist yet.

---

*Last updated: 2026-02-13*
