# Agentic SDLC: A Technical Whitepaper

**v3.0 | April 2026**

---

## Executive Summary

This whitepaper details a model for software development where AI agents operate as autonomous collaborators. Rather than treating AI as sophisticated autocomplete, we propose infrastructure where agents plan, execute, validate, and document work with minimal human intervention.

PDS (Portable Development System) implements this model as a **Claude Code plugin** — distributing skills, agents, hooks, and security settings through the native plugin system. The methodology is encoded as configuration: install it once, and every Claude Code session gains the full agentic SDLC workflow.

A key insight from deep source analysis of Claude Code's internals (March 2026): Claude Code is deeply coupled to Anthropic's API with no model abstraction layer. The "multi-provider" support (Bedrock, Vertex, Foundry) is multi-deployment of Claude, not multi-model. However, PDS's extension points — CLAUDE.md, skills, agents, hooks — are already expressed in model-agnostic markdown and JSON. PDS is more portable than the platform it runs on.

The goal is amplification, not replacement. A single engineer orchestrates multiple agents working in parallel, each in isolated environments, producing work that flows through automated validation before human review. The human remains architect and final authority. The agents become a scalable workforce. This central orchestrator + specialist sub-agents pattern is emerging as the industry standard for agentic development [1][6].

This document provides the technical depth required to implement this model: the conceptual framework, isolation architecture, tooling requirements, adoption path, and governance framework.

---

## The Problem

Traditional development workflows hit fundamental limits as AI capabilities improve:

**Human attention becomes the bottleneck.** When AI generates code faster than humans can review it, cognitive bandwidth — not typing speed — becomes the constraint.

**Context switching destroys productivity.** Supervising multiple agents fragments attention. The cost compounds throughout the day.

**Idle time accumulates.** When developers leave, work stops. When CI runs, work stops. These gaps represent unrealized capacity.

**The feedback loop stays slow.** Write-test-fix-test requires human presence at each iteration. Autonomous iteration would compress this cycle dramatically.

The agentic SDLC addresses these limitations by restructuring development around autonomous agents operating within well-defined boundaries.

---

## The Model

Six phases, each with clear inputs, outputs, and transition criteria. Human involvement concentrates at phase boundaries. A **phase state machine** tracks forward-only transitions (plan → decompose → dispatch → validate → consolidate → knowledge) via `.claude/swarm/phase`. Phase gates enforce this mechanically — the PR gate blocks creation before `consolidate`, the teardown gate blocks cleanup before `knowledge`. At each phase transition, the orchestrator writes a **checkpoint** to `.claude/swarm/checkpoint.json` recording the phase, tier, task assignments, and timestamp — enabling a replacement orchestrator to resume mid-swarm without losing work.

The six-phase structure is stable. Enforcement mechanisms have been implemented across all phases — checkpoint protocol, backpressure, pipeline validation, parallel consolidation, structured human approval, and a cleanup sub-phase. Each phase description below notes what was built.

### Phase 1: Requirements and Planning

Work begins when requirements arrive. The developer engages with an orchestrating agent to refine requirements into an actionable plan.

The orchestrator runs `/grill` — a structured requirement interrogation protocol — to validate requirements before decomposition. This protocol covers: restating the problem, defining scope boundaries, establishing verifiable acceptance criteria, surfacing constraints, challenging assumptions, identifying risks, ranking priorities, and performing a MECE check to ensure requirements don't overlap and all cases are covered. Ambiguous requirements are the primary source of wasted tokens in agentic workflows.

The grill protocol also recommends a **swarm tier** (lite, med, heavy) based on problem complexity. Tiers control model selection and specialist inclusion — lite uses haiku workers for routine pattern-following tasks, med uses the default sonnet/opus configuration, heavy uses opus for reasoning-heavy roles with a full specialist roster. This tiered architecture draws from Anthropic's own multi-agent research [1], where an Opus lead with Sonnet subagents outperformed single-agent Opus by 90.2%. The developer confirms or overrides the tier during plan approval.

The orchestrator may spawn a **researcher** agent to gather context: querying documentation, searching codebases, accessing external APIs. The orchestrator synthesizes this research and produces a structured task specification.

The critical output is explicit acceptance criteria — unambiguous and mechanically verifiable. "The API should be fast" becomes "p99 latency for /users under 200ms with 1000 concurrent connections."

**Implemented:** Phase 1 now runs parallel tracks for Med/Heavy tiers. The **grill track** (sync, human-facing) runs `/pds:grill` to validate requirements and recommend a tier. The **research track** (async) spawns a researcher immediately — it explores the codebase while the human refines requirements with the orchestrator. Both tracks converge before Phase 2 decomposition. Instincts from `.claude/instincts.md` are loaded into grill context, so accumulated patterns from prior swarms inform requirement validation. Lite tier skips the researcher; the orchestrator self-researches after grill. See Phase 1 in `/pds:swarm`.

### Phase 2: Task Decomposition and Dispatch

The orchestrator decomposes the plan into discrete work units for parallel execution. Each unit becomes a task assigned to a worker agent.

The orchestrator uses TaskCreate to build a task DAG, defining dependencies between work units. It then spawns worker agents via the Task tool, each receiving its own git worktree — complete, independent working directories sharing the underlying git object store. Each worker operates on its own branch, in its own directory, with no merge conflicts during execution.

The orchestrator records session metadata: which agents work on which worktrees, which branches they correspond to, expected deliverables, and task dependencies. This enables monitoring, recovery, and coordination.

**Implemented:** TaskCreate now requires acceptance criteria in **checklist format** — markdown checkboxes (`- [ ] criterion`) that can be mechanically verified against completed work. After setting task dependencies (`addBlockedBy`/`addBlocks`), the orchestrator validates the DAG: checking for cycles (if A blocks B, B must not transitively block A) and warning on orphan tasks (tasks with no `blocks` relationship). Agent Zones remain advisory configuration in CLAUDE.md — the format is documented but not mechanically enforced. See Phase 2 in `/pds:swarm`.

### Phase 3: Parallel Execution

Workers execute independently. Each worker agent declares `isolation: worktree` in its agent definition — a Claude Code feature that provisions a dedicated git worktree declaratively, without manual setup. Workers access the codebase within their worktree, read documentation, and write code.

**Workers use a pull model for task claiming.** The orchestrator assigns initial tasks, but workers self-claim subsequent unblocked tasks by checking TaskList and claiming the lowest-ID available task via TaskUpdate. This reduces orchestrator bottleneck — workers stay productive without waiting for assignment. Workers can communicate via SendMessage when tasks require cross-agent coordination, and create new tasks via TaskCreate when they discover additional work.

Workers benefit from a platform optimization: Claude Code's `StreamingToolExecutor` enables tool execution to overlap with response generation. When the model emits multiple tool_use blocks in a single response, Claude Code begins executing them before the full response completes. This means workers that chain multiple tool calls (read file, edit, run tests) don't pay a serial penalty for multi-tool turns — execution pipelines naturally while the model continues generating.

Each worker produces a result artifact: code changes, summary, issues encountered. Workers commit to their branches but do not merge.

**Implemented:** The orchestrator now monitors workers via `TeammateIdle` events with a tiered remediation protocol. On idle: check `TaskGet` first — if the agent awaits a blocked dependency, no action needed. If the agent has an unblocked task and is idle, send `SendMessage` to re-activate. Apply a **health timeout** (default 2× the task's estimated turns): on first timeout send a warning; on second timeout use `TaskStop` and reassign the task. If 3+ workers are simultaneously idle with blocked tasks, the bottleneck task is escalated for decomposition or priority adjustment. See Phase 3 in `/pds:swarm`.

### Phase 4: Validation

A validator agent examines all worker output by monitoring TaskUpdate status changes. The validator operates in its own worktree, merging worker branches and running comprehensive tests.

Responsibilities: writing tests based on acceptance criteria, running the existing test suite, performing static analysis, checking for defects. Workers run `/verify` before declaring tasks done — a structured self-check covering acceptance criteria, test suite, debug artifacts, git status, and diff review. The validator does not fix issues — it produces a structured report (via TaskUpdate) identifying failures, localizing them, and suggesting remediation. The validator writes its report to `.claude/swarm/validation-report.md` — a required artifact enforced by an LLM prompt evaluator on the validator's Stop hook.

A platform detail affects report structure: Claude Code stores large tool results externally and replaces them with references in the conversation. When the validator runs comprehensive test suites, large test outputs may be stored externally rather than inline. The validation report should reference specific test results by name rather than assuming full output is inline, ensuring the report remains useful even after tool result storage kicks in.

If validation fails, the report flows to the orchestrator, which updates the task DAG and dispatches targeted fix requests. This cycle continues until validation passes or human intervention is required.

**Implemented:** Pipeline validation is now the default — the validator is spawned when the **first** task completes, not the last. It monitors `TaskList` continuously, merging and testing incrementally as workers complete. The validation report now includes required JSON-checkable fields: `merge_status` per branch, `test_counts` (total/passed/failed/skipped), `criteria_verdicts` (per criterion: status + evidence), and `overall` (ready/needs_fixes). The LLM Stop hook supplements these mechanical checks but does not replace them. See Phase 4 in `/pds:swarm`.

### Phase 5: Consolidation and Human Review

Once Phase 4 validation passes, the orchestrator consolidates worker branches using `/finish` to prepare each branch — rebasing onto the target, cleaning commit history, and running post-rebase tests — then ships via `/bcp` (bump version, commit, push, create PR). `/bcp` is the single exit path for all shipping; `/finish` handles preparation, `/bcp` handles delivery. A **reviewer** agent is spawned here — after validation completes — to perform automated pre-review: checking code quality, security patterns, and consistency, and producing a structured report before human review. A **documenter** agent updates user-facing documentation when changes warrant it.

The orchestrator writes the reviewer's report to `.claude/swarm/review-report.md` — a required artifact. A PreToolUse gate on `gh pr create` blocks PR creation unless both the validation and review reports exist. The developer reviews with full context: requirements, plan, validation results, reviewer findings, issues encountered. The developer can request changes (flowing back through the orchestrator) or approve for merge. The reviewer's automated pre-review supplements but never replaces the human gate.

**Implemented:** `/finish` now runs in **parallel** across all task branches simultaneously — each branch gets its own rebase, history cleanup, and post-rebase test run concurrently. The human approval gate is formalized using `ExitPlanMode` / `plan_approval_response`: the orchestrator presents the consolidated diff summary, validation results, and reviewer findings as a structured plan; the parent responds with approval or rejection. On rejection, the orchestrator returns to the indicated phase. This replaces the informal "create PR and wait" pattern with a structured handoff that the orchestrator can act on unambiguously. See Phase 5 in `/pds:swarm`.

### Phase 6: Knowledge Capture

Before merging, the orchestrator reviews what happened: patterns emerged, architectural decisions made, unexpected challenges. A **scout** agent analyzes the completed swarm for meta-improvements — workflow optimizations, skill gaps, configuration updates. The scout writes its report to `.claude/swarm/scout-report.md` and can access cross-session memory via claude-mem MCP tools (when available) to enrich analysis with historical context.

A teardown gate verifies the swarm has reached the `knowledge` phase and all three phase artifacts exist (validation, review, scout reports) before cleanup, ensuring no phase is skipped during swarm completion. Because teams are implicit per-session (TeamCreate/TeamDelete were removed at v2.1.178) and dissolve at session end, this gate guards the pre-cleanup boundary rather than an explicit teardown call.

This knowledge flows into the lexicon — a persistent repository of engineering knowledge spanning tasks, repositories, and team members. The lexicon captures lessons learned, gotchas, and patterns.

An **auditor** agent may be spawned periodically (not per-swarm) to scan for tech debt, code smells, and missing tests, filing findings as GitHub issues.

Agents query the lexicon during future planning and execution, avoiding repeated mistakes and building on proven patterns [5].

**Implemented:** The scout now spawns **before agent shutdown** — workers remain active so the scout can query them via `SendMessage` for clarification on decisions made during execution. The feedback loop is established: instincts captured or updated in Phase 6 are written to `.claude/instincts.md`, and Phase 1 explicitly loads this file into grill context at the start of the next swarm. Phase 6 also includes a **cleanup sub-phase** after agent shutdown (the implicit team dissolves at session end): worktree deletion (`git worktree remove`), artifact archival to `docs/swarm-reports/<YYYY-MM-DD-HHmm>/`, state validation (all tasks completed, all branches merged), and merged branch deletion. Heavy tier spawns the auditor for a post-swarm tech debt scan. See Phase 6 in `/pds:swarm`.

---

## Core Technical Concepts

### Git Worktrees

A worktree is an additional working directory associated with a repository. Unlike a clone, it shares the object store (commits, blobs, trees) with the main repository. Creation is nearly instantaneous with minimal disk overhead.

Claude Code manages worktrees natively — agents spawned with `isolation: "worktree"` receive their own worktree automatically. Path resolution, branch creation, and cleanup are handled by the runtime.

Each worktree has its own index and HEAD. Operations in one worktree do not affect others. A key constraint: each branch can only be checked out in one worktree at a time.

### MCP (Model Context Protocol)

MCP is a standardized protocol for agents to interact with external systems. MCP servers are plugins exposing capabilities: filesystem access, database queries, ticket management.

The protocol uses JSON-RPC over stdio or SSE. Servers can be written in any language and wrap any API.

**MCP Ecosystem Maturity**: The Docker MCP Catalog now provides 200+ verified, containerized MCP servers with:
- Digital signatures and provenance verification
- SBOM metadata for supply chain transparency
- MCP Gateway for centralized access control and OAuth automation
- Pre-built integrations for common services (Jira, Slack, databases)

This ecosystem reduces the barrier to agent integration significantly.

### Plugin Architecture

PDS distributes as a **Claude Code plugin** — a first-class extension mechanism that bundles skills, agents, hooks, and MCP server configurations into a single installable unit.

**Plugin manifest** (`plugin.json`): Declares the plugin's name, version, and description. Claude Code discovers the plugin at `~/.claude/plugins/pds/` and loads its contents automatically.

**What a plugin provides:**
- **Skills** (`skills/` directory): 24 workflow protocols in markdown format. Each skill is loaded on demand when invoked (e.g., `/pds:swarm`). Skills encode multi-step procedures that would bloat passive context if always present.
- **Agents** (`agents/` directory): 8 role definitions with model selection, permission mode, tool access, and behavioral constraints. Agents are spawnable via the Task tool with type restrictions (`Task(worker)`, `Task(validator)`).
- **Hooks** (`hooks/hooks.json`): Lifecycle event handlers that fire on specific Claude Code events. PDS uses hooks for quality gates (Stop, TaskCompleted, TeammateIdle), audit logging (WorktreeCreate, InstructionsLoaded), session setup (SessionStart), telemetry (PostToolUse), roster enforcement (SubagentStart), context management (PreCompact, PostCompact), and skill hints (UserPromptSubmit).
- **MCP servers**: Tool integrations declared in the plugin manifest, available to agents based on role permissions.

**Plugin sources**: Claude Code supports three plugin sources — builtin (ships with the CLI), marketplace (git repositories installable via `claude mcp install-marketplace`), and local (symlinked for development). PDS is available through the marketplace and as a local dev install.

**Why plugins matter for PDS**: Before the plugin system, PDS required copying files into each project's `.claude/` directory. Plugins provide user-level installation — install once, available across all projects. Project-level overrides (`.claude/settings.json`, `CLAUDE.md`) layer on top for team-specific configuration.

### Hook Lifecycle

Claude Code provides **28 hook lifecycle events** that plugins and project configuration can subscribe to. Hooks are the mechanical enforcement layer — they fire automatically at specific points in the agent lifecycle, independent of agent prompts or instructions.

**Event categories:**

| Category | Events | PDS Usage |
|----------|--------|-----------|
| **Tool lifecycle** | PreToolUse, PostToolUse, PostToolUseFailure | Phase gates (PR gate, teardown gate), post-write lint |
| **Session lifecycle** | SessionStart, SessionEnd, Stop, StopFailure, Setup | Version check, context injection, completion verification |
| **Agent lifecycle** | SubagentStart, SubagentStop, TeammateIdle, TaskCreated, TaskCompleted | Quality gates, idle detection, task completion verification |
| **Permission** | PermissionRequest, PermissionDenied | LLM-as-judge permission routing |
| **Configuration** | ConfigChange, WorktreeCreate, WorktreeRemove, InstructionsLoaded, CwdChanged, FileChanged | Audit logging, lifecycle tracking |
| **Context** | PreCompact, PostCompact, UserPromptSubmit, Notification | Context management |
| **Interaction** | Elicitation, ElicitationResult | User input handling |

**Hook types**: Hooks can be implemented as bash commands (run a script), agent hooks (spawn a Claude instance to evaluate), HTTP hooks (call an external webhook — available since Claude Code 2.1.63), or internal callbacks.

**Hook responses**: Depending on the event, hooks can continue or stop execution, approve or deny permissions, inject additional context, or modify tool input/output. Two powerful response capabilities remain untapped by PDS: `updatedInput` can modify tool parameters before execution (e.g., ensuring Bash commands run in the correct worktree), and `updatedMCPToolOutput` can modify MCP tool results after execution (e.g., sanitizing or enriching outputs). These represent enforcement opportunities beyond simple approve/deny decisions.

**PDS hook usage**: PDS registers hooks for 11 events: SessionStart (inject version and context), Stop (verify completion for implementation sessions), TaskCompleted (run tests), TeammateIdle (backpressure — detect idle workers, trigger remediation), WorktreeCreate (telemetry), InstructionsLoaded (telemetry), PostToolUse (skill/agent/file telemetry), SubagentStart (roster enforcement — warn on unknown agent types), PreCompact (context snapshot), PostCompact (context injection), and UserPromptSubmit (suggest relevant skills). The orchestrator's PreToolUse PR gate blocks `gh pr create` unless required artifacts exist; a teardown gate guards swarm cleanup against missing phase artifacts. PermissionRequest was removed in v4.6.0; static deny rules and the OS-level sandbox provide equivalent enforcement without LLM-as-judge overhead.

All 28 events receive `agent_id` and `agent_type` in their payloads (since Claude Code 2.1.69), enabling agent-aware policy decisions — the same hook can apply different rules depending on whether the requestor is a worker, validator, or orchestrator.

**Implemented:** PDS now uses 11 of 28 hook events. Added since the initial 7: PostToolUse (skill invocation and file modification telemetry), SubagentStart (roster enforcement — warns when an unknown agent type is spawned), PreCompact/PostCompact (context snapshot and injection around compaction), and UserPromptSubmit (skill hint suggestions based on prompt keywords). Remaining high-value additions: `updatedInput` in PreToolUse to rewrite Bash commands to the correct worktree path, and `updatedMCPToolOutput` to sanitize or enrich MCP results — both require hook response capabilities not yet wired in PDS.

### LLM Independence

**The coupling reality:** Claude Code is deeply coupled to Anthropic's API. The `services/api/claude.ts` module (126k lines) uses `@anthropic-ai/sdk` types throughout — `BetaMessageStreamParams`, `BetaMessage`, `BetaToolUnion`, `ToolResultBlockParam`. Streaming uses Anthropic's `Stream<BetaRawMessageStreamEvent>`. Extended thinking, prompt caching (`cache_control`), and tool results all use Anthropic-specific formats. There is no abstraction layer between business logic and the Anthropic SDK.

The four providers (firstParty, Bedrock, Vertex, Foundry) are different deployment targets for the same Claude models, not a multi-model architecture. Model configs map each Claude model to provider-specific identifiers. No OpenAI, no local model support, no generic LLM interface exists in the codebase.

**What PDS already owns that's portable:** PDS's extension points are expressed in model-agnostic formats:
- **CLAUDE.md** — plain markdown, injected into system prompt as `userContext.claudeMd`
- **Skills** — markdown files loaded by `loadSkillsDir.ts`, provided to the Skill tool
- **Agents** — markdown files loaded by `loadAgentsDir.ts`, spawnable via Agent tool
- **Hooks** — JSON configuration triggering bash/HTTP/agent handlers
- **Settings** — JSON configuration for permissions, sandbox, environment
- **MCP servers** — JSON-RPC protocol, already LLM-agnostic by design

PDS is already more model-agnostic than Claude Code itself. The methodology (six phases, human gates, isolation) is pure process — it transfers to any agent runtime that supports worktrees, tasks, and inter-agent messaging.

**The abstraction boundary strategy:** PDS does not need Claude Code to become LLM-agnostic. PDS needs to own the abstraction boundary:
1. **Message format translator** — Convert between Anthropic message format and a PDS-internal format. Key challenge: tool_use blocks, thinking blocks, content arrays.
2. **Tool schema translator** — Claude Code tools use Anthropic's `ToolInputJSONSchema`. OpenAI uses JSON Schema with `function` wrapping. Local models use varying formats.
3. **Streaming protocol adapter** — Anthropic SSE events differ from OpenAI SSE events.
4. **Context window management** — Claude Code's compact/microcompact/reactive-compact system (61k `compact.ts`) is sophisticated. Any alternative runtime would need equivalent compression.

This is a vision-forward strategy. Today, PDS runs on Claude Code and benefits from its deep Claude integration. The portable markdown/JSON layer means PDS could migrate to another runtime without rewriting its methodology — only the runtime adapter would change.

### Agent Isolation

Agents must operate within well-defined boundaries. Unrestricted access to production systems is unacceptable risk.

**Defense-in-Depth Model**:

PDS layers six enforcement mechanisms, from OS-level sandboxing to human review:

1. **OS-level sandbox** — Claude Code's native sandbox (Seatbelt on macOS, bubblewrap on Linux) confines Bash commands: filesystem writes are restricted to the working directory, network access is limited to an allowlist of domains. This is the hard floor — no prompt injection or agent confusion can bypass OS-level enforcement.
2. **Static deny rules** — Pattern-matched rules in `settings.json` block credential paths, protected branches, sensitive files, and production patterns across all tools. Deny rules are evaluated before any permission mode logic and cannot be overridden.
3. **Hook gates** — PreToolUse phase gates enforce SDLC transitions mechanically. A forward-only phase state machine (`.claude/swarm/phase`) tracks the current phase; gates validate both phase state and required artifacts. The orchestrator's PR gate blocks `gh pr create` unless phase >= `consolidate` and validation + review reports exist; its teardown gate verifies phase = `knowledge` and all three phase artifacts exist before cleanup. Teams are implicit per-session (TeamCreate/TeamDelete were removed at CC v2.1.178), so cleanup is guarded at the pre-teardown boundary. Phase checks are defense-in-depth — if the phase file is absent, gates fall through to artifact-only checks. SubagentStart hooks enforce the agent roster. HTTP hooks (Claude Code 2.1.63) allow quality gates to call external services for policy enforcement. Hooks receive `agent_id` and `agent_type` in all hook events (Claude Code 2.1.69), enabling agent-aware decisions. `WorktreeCreate`/`WorktreeRemove` hook events provide lifecycle gates for worktree operations. The validator's Stop hook uses an LLM evaluator to verify report completeness. `InstructionsLoaded` events let hooks audit which rule files are active at session start.
4. **Agent prompt constraints** — Each agent's `.md` file defines role-specific boundaries ("read-only", "stay in your worktree", "does not fix code"). Shared behavioral rules (`shared-rules.md`) are inherited by all agents via `inherits:` frontmatter. This shared-rules pattern has a hidden benefit: agents with byte-identical system prompt prefixes get better prompt cache efficiency. Placing shared rules at the top of agent definitions maximizes the shared prefix, reducing per-agent cache warming cost across a swarm.
5. **Permission modes** — `plan`, `acceptEdits`, `default`, and `auto` control which tools each agent type can access. Orchestrators declare which agent types they can spawn via `Task(agent_type)` restriction syntax, preventing unauthorized agent escalation. In auto mode, a Sonnet classifier evaluates each tool call — agent-declared modes are overridden, but deny rules, sandbox, and hook gates remain enforced.
6. **The human gate** — All changes flow through PR review before reaching production.

**Observability** complements these enforcement layers but is not itself enforcement — it detects rather than blocks. Opt-in telemetry tracks skill invocations, agent spawns, and file modifications. Pattern detection (`scripts/detect-patterns.sh`) identifies anomalies: repeated skill invocations suggesting missing automation, agents spawned without work output, and zero-usage skills. This data feeds into the instinct lifecycle, enabling data-driven skill evolution.

This approach favors lightweight isolation over heavyweight containers. The sandbox adds OS enforcement without container overhead. The blast radius of a misbehaving worker is limited to its worktree branch. No changes reach production without human approval.

**Permission Tiers**:

| Agent Type | Sandbox | Network | Filesystem | Credentials |
|------------|---------|---------|------------|-------------|
| Worker | Yes (writes to CWD) | Package registries only | Own worktree only | None |
| Validator | Yes (writes to CWD) | Package registries + test DBs | Own worktree + read others | Test DB credentials |
| Orchestrator | Yes (writes to CWD) | External APIs (Jira, Slack) | All worktrees (read) | API tokens (no prod) |

**Additional Permission Modes**:

- **auto** — A Sonnet classifier evaluates each tool call instead of prompting the user. Reads `autoMode` config from `~/.claude/settings.json` (user-level) for allow/environment context. Static deny rules and the sandbox still apply. Recommended for interactive development.
- **dontAsk** — Auto-denies every tool not explicitly in the allow list. Fully non-interactive, suitable for CI/CD pipelines where `--allowedTools` restricts the tool surface. Anthropic recommends `dontAsk` or `acceptEdits` + `--allowedTools` for CI/CD, not auto mode.

### Native Agent Teams

Agents execute as native Claude Code teams — no containers, no file synchronization, no heavyweight orchestration.

**Implicit team** — since CC v2.1.178 a team is established automatically per session (one team, formed on the first `Task(...)` spawn; no TeamCreate/TeamDelete). It carries a shared task list the orchestrator uses to coordinate multiple agents working on related tasks.

**TaskCreate** defines work units with dependencies, forming task DAGs. Workers can depend on each other's completion, enabling sophisticated workflows while maintaining clarity about execution order.

**Task tool** spawns worker agents. Each worker receives its own git worktree (via `isolation: "worktree"`), providing filesystem isolation without containerization overhead. Claude Code handles worktree creation, path resolution, and cleanup automatically. Agents follow a spawn-execute-return-die lifecycle — they are ephemeral by design. A worker spawned for a task executes until completion (or maxTurns), returns its output, and terminates. This simplicity is a strength (no zombie processes, no session management) but means workers cannot be queried after completion.

**SendMessage** enables direct and broadcast communication. Workers can ask questions, share findings, or coordinate when decomposition requires it. The orchestrator receives all messages and can route or respond as needed.

**PDS's specialized-agent model vs. fork subagents:** Claude Code's `FORK_SUBAGENT` feature flag enables a different agent spawning pattern — forking the parent's full conversation context into a child agent. The child inherits the parent's system prompt (byte-exact for cache efficiency) and full conversation history. This contrasts with PDS's model where each agent starts fresh with its own role-specific system prompt. Fork subagents optimize for "do this subtask with full context" while PDS agents optimize for "play this specialized role with focused behavior."

**Platform gap: Three-system disconnect.** Claude Code provides three agent spawning systems — specialized team agents (`Task(worker)`), fork subagents (`FORK_SUBAGENT`), and coordinator mode (`COORDINATOR_MODE`) — but they address different problems and cannot be composed. Specialized agents get role constraints but lose the orchestrator's accumulated context. Fork subagents inherit full context but have no role specialization. Coordinator mode enables collaboration but does not differentiate agents by capability. Community evidence confirms this is a pain point: anthropics/claude-code#24316 (27 upvotes, requesting fork + specialization), #16153 (context inheritance for spawned agents), #4908 (subagent memory sharing), #6825 (agent context bootstrapping), #17283 (passing conversation context to subagents). No hidden combination exists in the codebase — `fork` and `agent_type` are separate code paths.

**PDS bridge (implemented):** A **dual-dispatch model** (documented in the Dispatch Modes section of `/pds:team`) where the orchestrator chooses at runtime: team teammate (`Task(worker)`) for long-running, visible, role-specialized work; fork subagent for quick inline subtasks that need the orchestrator's full context (under 2-3 turns). For context loss on teammate spawn, PDS uses a structured context protocol: the orchestrator writes `.claude/swarm/context.md` before dispatching workers — containing the plan, research findings, acceptance criteria, and key decisions. Workers read this file on initialization, recovering the orchestrator's reasoning without requiring fork-level context inheritance. The platform gap (cannot compose fork + team agents) remains a Claude Code limitation; PDS bridges it pragmatically.

This approach eliminates Docker/container overhead while maintaining isolation through git worktrees and Claude Code's permission system. Agents run natively with full access to local tools (language servers, build tools, formatters) without the complexity of mounting volumes or synchronizing files.

### The Shepherd: Substantive Advisory Agent

The orchestrator handles the graph of work — who's assigned what, what's blocked on what, which phase is active. But substantive questions also arise during a swarm — "should this module own retry logic?", "is squashing these commits before PR the right call?", "which principle applies when tests and design are in tension?" These questions are fundamentally different in kind from dispatch questions. Delegating them to the orchestrator conflates two distinct responsibilities and tends to starve the one whose answers require the most thought.

The **shepherd** is PDS's answer. It is a persistent, cross-swarm-memory agent spawned after the Phase 1 grill in med and heavy tiers (never lite). Model: opus. It loads a reference corpus on spawn — `docs/whitepaper.md`, `docs/philosophy.md`, `docs/ethos.md`, `CLAUDE.md`, `skills/swarm/SKILL.md`, and `.claude/shepherd-journal.md` (created with a header if absent) — then walks the ticket alongside workers and the orchestrator through Phases 2 through 6. Its four capabilities are: reactive consult (responds to SendMessage substance questions with citations — `file:line` or section heading), running journal (writes decisions, observations, and caught violations continuously to `.claude/shepherd-journal.md`), proactive flagging (initiates SendMessage when observed drift crosses a threshold), and loop-break (escalates to human after three consults on the same question without convergence). It is advisory-only — it never blocks work. When a user overrides a principle, the shepherd logs the divergence; when the same principle has been overridden three times across swarms, it files a GitHub issue proposing whitepaper review. This is the living-whitepaper feedback loop: the document evolves through observed use, not opinion.

The shepherd exists partly because of a measured waste. Instinct #2 (recorded in `.claude/instincts.md` from earlier swarms) observed that the orchestrator's capacity sits idle during Phase 3 worker execution — the dispatch is done, workers are implementing, and the orchestrator is passively monitoring. That idle capacity is a transport waste in the Toyota Production System sense: time that could be creating value instead spent in transit between dispatch and validation. The shepherd absorbs that capacity into a role that produces durable value — substantive consultation, drift detection, journal continuity. It does not replace the orchestrator (which is still the main Claude session handling the graph) and does not create a new topological layer; it fills an observed gap. Workers route graph questions to the orchestrator and substance questions to the shepherd, so neither agent is over-burdened and neither is starved. The shepherd's journal persists across swarms as project-level state (gitignored by default, scout-compacted in Phase 6), so substantive context compounds rather than being lost each session.

The MCP plumbing for the shepherd lives at `mcp/advisor/` — a Node-based server that wraps Anthropic's `advisor_20260301` beta tool and exposes it as a single MCP tool, `mcp__pds-advisor__advisor_consult`. The shepherd uses this tool to reach the advisor beta when it needs synthesis beyond its loaded corpus. The server falls back gracefully: if the advisor beta is unreachable (4xx/5xx, timeout) it retries as plain Opus; if `ANTHROPIC_API_KEY` is unset it returns a structured degraded response. Workers also have `advisor_consult` in their allowlist as a fallback for when the shepherd is absent (lite tier or idle), using a shepherd-role prompt template documented in `agents/worker.md`.

### Instruction Architecture

Agent effectiveness depends on how instructions reach the model. Vercel's agent evals [2] found that passive context (always-loaded AGENTS.md) achieves 100% pass rates for horizontal framework knowledge, while skills without explicit invocation instructions scored 53%. Skills with careful wording reached 79%.

PDS uses a dual-layer approach informed by these findings:

- **Passive context** (`CLAUDE.md`) — Always loaded. Carries rules, the skills table, and conventions that apply across all tasks. This is the horizontal layer.
- **Explicit skills** (plugin `skills/` directory) — User-triggered vertical workflows (`/pds:swarm`, `/pds:grill`, `/pds:finish`). Loaded on demand when the user or orchestrator invokes them. These encode multi-step protocols that would bloat passive context if always present.

The passive layer tells the agent *what skills exist and when to use them*. The skills themselves contain the detailed protocol. This avoids the failure mode identified in Vercel's research — agents not discovering skills during general tasks — while keeping context lean [4].

**Platform alignment:** PDS's dual-layer pattern independently converged on the same optimization Claude Code uses for its own tool system. Claude Code defers tool schemas via `ToolSearch` — less-commonly-used tools appear only as names in a system reminder, with full schemas loaded on demand when the model needs them. PDS lists skills in CLAUDE.md (names and descriptions), with full skill content loaded when invoked via the Skill tool. Both systems solve the same problem: rich capability without context bloat. This convergence validates PDS's instruction architecture as aligned with platform-native patterns, not fighting them.

**System prompt assembly** (observed from source analysis): Claude Code builds the system prompt through a multi-stage pipeline. Sections are cached via `systemPromptSection()` for prompt cache efficiency — unchanged sections hit the cache, reducing cost. The pipeline assembles: system prompt base + user context (CLAUDE.md files, current date) + system context (git status snapshot). The QueryEngine layer adds coordinator context, memory mechanics, and any custom system prompts. PDS's CLAUDE.md content enters this pipeline as `userContext.claudeMd`, alongside skills and agent definitions loaded from the plugin directory. This caching-aware assembly means PDS's passive context benefits from prompt caching automatically — the skills table in CLAUDE.md is cached across turns when unchanged.

### Data Source Registry

Agents need credentials to access external systems. The data source registry configures:

- **MCP server mappings**: Which servers are available in each environment
- **Credential injection**: How secrets reach the agent (dotenv locally, secrets manager in cloud)
- **Role-based access**: Which agent roles can access which resources

Configuration example:

```yaml
mcp_servers:
  postgres:
    image: mcp/postgres:latest
    credentials: [DATABASE_URL]
    roles: [worker, validator]

  github:
    image: mcp/github:latest
    credentials: [GITHUB_TOKEN]
    roles: [orchestrator]
```

This ensures workers never receive GitHub tokens and orchestrators don't get database access beyond what coordination requires.

**Note:** The data source registry is currently aspirational configuration — PDS uses it as a design pattern for teams to follow, but there is no mechanical enforcement mapping agent roles to MCP server access at runtime. Role-based access control is enforced via static deny rules and permission hooks, not via the registry schema. This is a vision-forward design that would benefit from Claude Code adding agent-role-aware MCP server filtering.

### Headless Agents

Not all agent work requires an interactive session. Some tasks — preflight validation, instinct capture, telemetry analysis, scheduled audits, post-swarm cleanup — are better suited to background or scheduled execution without a human present.

**Three dispatch modes:**

| Mode | Mechanism | Visibility | Use Case |
|------|-----------|------------|----------|
| **Team teammate** | `Task(worker)` | Visible in team, tracked via TaskList | Long-running implementation, validation, review |
| **Fork subagent** | `FORK_SUBAGENT` | Invisible to team, inherits parent context | Quick subtasks, ad-hoc queries, inline research |
| **Headless** | `CronCreate`, `run_in_background`, SessionStart/Stop hooks | No interactive session required | Preflight checks, telemetry analysis, scheduled audits, instinct capture |

**What headless agents can do today** (from source analysis):
- **`CronCreate`** — Schedule recurring agent execution on a cron expression. The agent runs independently of any active session.
- **`run_in_background`** — Launch a long-running command that continues after the parent returns. Results are available later via notification.
- **SessionStart hooks** — Execute validation, context injection, or environment checks at every session start. PDS already uses this for version checking and context injection.
- **Stop hooks** — Execute verification or cleanup when a session ends.

**Use cases:**
- **Preflight validation** — Run environment validation via the SessionStart hook before any work begins.
- **Instinct capture** — After a swarm completes, a headless agent analyzes the session for patterns worth recording as instincts.
- **Telemetry analysis** — Scheduled analysis of `.claude/telemetry.jsonl` to detect efficiency trends and waste patterns.
- **Cleanup** — Post-swarm worktree removal, stale branch pruning, artifact archival.
- **Scheduled audits** — Periodic codebase scanning for tech debt, dependency updates, or configuration drift.

Headless agents are the least mature dispatch mode — `CronCreate` and background execution exist in the platform but PDS does not yet wrap them in workflow-aware skills. The Dispatch Modes section of `/pds:team` documents when to use each mode and provides the dispatch protocol.

### The Lexicon

The lexicon is persistent engineering knowledge spanning tasks and team members.

**Implementation**: The lexicon is realized as **instincts** — structured observations stored in `.claude/instincts.md`. Each instinct records a pattern with context, confidence level, and action. The file is git-tracked, diffable, and readable by any agent with `memory: project`.

**Lifecycle**: Instincts follow an automated lifecycle managed by the scout agent:

1. **Capture**: Any agent or human records a pattern via the `/instinct` skill
2. **Validate**: Scout reviews instincts post-swarm (Phase 6), increments observation counts, adjusts confidence
3. **Promote**: When an instinct reaches `high` confidence (3+ validations), scout drafts a new skill. Human approves via PR review.
4. **Retire**: If an instinct proves wrong or irrelevant, scout marks it `retired`

This auto-evolution means the lexicon grows from work — not from manual documentation efforts. The human gate at promotion (new skill = new committed file = PR review) ensures quality.

**Auto-Detection**: In addition to manual capture, the scout agent can detect instinct-worthy patterns from telemetry data. The detect-patterns script identifies: skills invoked 3+ times per session (suggesting automation opportunities), agents spawned without task completion (suggesting configuration issues), dominant file extensions (suggesting tooling needs), and zero-usage skills (suggesting deprecation candidates). These automated detections appear as draft instincts in the scout report for human review.

Agents query `.claude/instincts.md` during planning (Phase 1) and execution, avoiding repeated mistakes and building on proven patterns [5].

### Observability

PDS instruments its own usage through opt-in telemetry. When enabled (PDS_TELEMETRY=1), hook scripts append JSONL events to .claude/telemetry.jsonl:

- **Skill invocations**: Which skills are used, how often, by which sessions
- **Agent spawns**: Which agent types are created during swarms
- **File modifications**: Which files are edited, by file extension
- **Lifecycle events**: Worktree creation, instruction loading

All data is local — nothing leaves the developer's machine. The telemetry file is gitignored by default. The `/telemetry` skill provides management commands: enable, disable, view reports, and rotate logs.

**Dual-level persistence:** Telemetry events are written to both project-level (`.claude/telemetry.jsonl`) and user-level (`~/.claude/telemetry/sessions.jsonl`). Project-level telemetry lives in the working directory and may be lost when worktrees are cleaned up after a swarm. User-level telemetry persists across sessions, repositories, and worktree lifecycles — enabling retrospective analysis of any past session. Each user-level event includes a `repo` field for filtering. The efficiency chart script (`scripts/efficiency-chart.sh`) supports `--user` to read user-level telemetry, `--session <id>` to filter to a specific session, and `--repo <name>` to filter by repository.

A pattern detection script (scripts/detect-patterns.sh) analyzes telemetry for instinct-worthy patterns: repeated skill invocations within a session, agents spawned without corresponding work output, dominant file extensions suggesting specialized tooling needs, and zero-usage skills that may warrant deprecation. The scout agent runs this analysis during Phase 6, producing draft instinct entries for human review.

This closes the feedback loop between usage and methodology: PDS can now identify which parts of the system are actually used and which are dead weight, enabling data-driven decisions about skill promotion, retirement, and optimization.

### Efficiency Measurement

Agentic workflows introduce new categories of waste invisible to traditional development metrics. Lines of code, velocity points, and commit frequency measure output but not the efficiency of the process that produced it. A swarm may produce correct code while spending 60% of its wall-clock time on non-value-creating activity: agents waiting for permission prompts, re-reading files already analyzed by the researcher, serializing context between agents, or iterating through failed validation cycles.

**Value Stream Mapping** — a technique from the Toyota Production System [13] — provides the analytical framework. Ohno defined seven categories of waste (muda) in manufacturing; these map directly to agentic software development:

| TPS Waste | Agentic SDLC Equivalent | Example |
|-----------|------------------------|---------|
| **Waiting** | Agent idle during review or approval | Worker blocked on orchestrator assignment; validator waiting for all workers to finish |
| **Transport** | Context serialization between agents | Orchestrator's research lost when worker spawns fresh; findings re-discovered from scratch |
| **Over-processing** | Re-reading files already analyzed | Worker re-reads files the researcher already summarized; validator re-analyzes code the reviewer already checked |
| **Defects** | Failed validation cycles | Worker produces code that fails validation; fix-revalidate cycle repeats |
| **Inventory** | Stale worktrees and branches | Completed worktrees not cleaned up; branches lingering after merge |
| **Motion** | Permission prompts and tool approval friction | Interactive permission prompts interrupting autonomous flow; sandbox denials requiring reconfiguration |
| **Overproduction** | Gold-plating beyond acceptance criteria | Worker adds features not in the spec; documenter writes docs for internal-only changes |

Beck's Extreme Programming [14] and Poppendieck's Lean Software Development [15] both identify waste elimination as a core principle — but neither anticipated waste categories specific to multi-agent coordination. The transport waste (context loss between agents) and the motion waste (permission prompt friction) are unique to agentic workflows and have no equivalent in human-only development.

**Efficiency ratio:** The fundamental metric is the ratio of value-creating time to total elapsed time per agent:

```
η = Σ(value-creating time) / Σ(total elapsed time)
```

A value-creating event is one that advances the work product: writing code, running tests, producing reports. An idle event is everything else: waiting for assignment, re-reading context, blocked on permissions, serializing between phases.

**Efficiency chart:** A binary signal over time for each agent — 1 when creating value, 0 when idle. Gaps between value events are waste to be investigated and reduced:

```
orchestrator: ████░░░░████░░████████░░░░████
worker-1:     ░░░░░░░░████████████░░░░░░░░░░
worker-2:     ░░░░░░░░░░████████████████░░░░░
validator:    ░░░░░░░░░░░░░░░░░░░░████████░░░
              ─────────────────────────────────
              0    5    10   15   20   25   30  (minutes)

█ = value-creating   ░ = idle/waiting
Overall η = 0.52 (52% efficiency)
Top waste: worker-1 idle 0:00-0:08 (waiting for dispatch)
```

The chart makes waste visible. The leading idle gap for workers (waiting for dispatch) and the trailing idle gap for the orchestrator (waiting for validation) are structural — they exist in every swarm. The question is whether they can be compressed: pipeline validation (start checking completed tasks early), pre-warm worker context (write context file before dispatch), parallelize consolidation.

**PDS telemetry as measurement mechanism:** The existing telemetry infrastructure (`.claude/telemetry.jsonl`) captures timestamped events per agent. The efficiency chart script (`scripts/efficiency-chart.sh`) reads these events, classifies each as value-creating or idle based on event type, produces the per-agent binary signal chart, calculates η, and identifies the top waste points. The scout agent runs this analysis during Phase 6 (Knowledge), including efficiency findings in its report alongside instinct analysis.

This grounds PDS's self-improvement cycle in quantitative evidence rather than subjective assessment. A swarm that achieves η=0.7 is measurably better than one at η=0.4, and the waste breakdown shows exactly where to invest optimization effort.

---

## Platform Positioning

Understanding where PDS leads and where the platform leads is essential for strategic investment. Source analysis of Claude Code's internals reveals a clear competitive split:

**Where PDS leads:**
- **Structured agent workflows** — PDS's 6-phase SDLC with role-specific agents (orchestrator, researcher, worker, validator, reviewer, documenter, scout, auditor) is more opinionated and more structured than Claude Code's generic coordinator mode. The coordinator provides the platform; PDS provides the methodology.
- **Workflow enforcement** — PDS's grill → implement → verify → finish pipeline has no Claude Code equivalent. Phase gates, artifact requirements, and the forward-only state machine are PDS innovations.
- **Quality gates** — PDS hooks enforce SDLC stages mechanically; Claude Code's hooks are general-purpose event handlers without workflow semantics.
- **Swarm tiers** — Cost-aware model selection per agent role. Claude Code provides the model override mechanism; PDS provides the tier abstraction that makes it usable.

**Where Anthropic leads:**
- **Context management** — 61k lines of compaction code across 5 modes (auto-compact, micro-compact, reactive compact, context collapse, history snip) vs. PDS's zero investment. PDS gets this for free as a platform benefit.
- **Intelligence** — ML-powered classifiers for bash command safety (`BASH_CLASSIFIER`) and auto-mode permission decisions (`TRANSCRIPT_CLASSIFIER`). These reduce permission prompting without PDS needing to implement its own classification.
- **IDE integration** — Native VS Code and JetBrains bridge via WebSocket protocol (`BRIDGE_MODE`). PDS doesn't need to replicate UI.
- **Memory extraction** — Auto-memory extraction from conversations (`EXTRACT_MEMORIES`). PDS's instinct system has similar goals but is currently unused. Anthropic's implementation is automatic; PDS requires explicit `/instinct` invocation.

**The synergy:** PDS methodology + Claude Code platform creates a stack that neither provides alone. Claude Code handles the hard engineering problems (context compression, caching, IDE integration, model API). PDS handles the hard methodology problems (SDLC enforcement, agent specialization, human gates, quality assurance). Feature flags like `COORDINATOR_MODE`, `AGENT_TRIGGERS`, and `WORKFLOW_SCRIPTS` signal that Anthropic is investing in PDS-adjacent territory — but with generic primitives, not opinionated methodology. PDS remains the methodology layer.

---

## Required Tooling

### Terminal Environment

The terminal provides a powerful interface for multi-worktree workflows. Graphical IDEs assume one project, one set of files, one debug session. Agentic workflows involve multiple worktrees and rapid context switching.

**Core tools** (optional but recommended):
- **tmux**: Terminal multiplexing, persistent sessions
- **yazi** or similar: Terminal file manager for worktree navigation
- **neovim + telescope**: Editor with multi-worktree support

Claude Code handles agent lifecycle natively through the Task/TaskCreate tools (teams are implicit per-session; TeamCreate/TeamDelete were removed at v2.1.178). tmux and terminal tools enhance the developer's monitoring experience but are not required for agent orchestration.

### Version Control

- **git worktree**: Core functionality
- **lazygit**: Terminal UI accelerating common operations
- Custom scripts for worktree lifecycle management

### Dependency Management

Each worktree needs dependencies. Prefer tools that make environment creation fast:

- **uv** (Python): Virtual environments in seconds, global package cache
- **pnpm** (Node.js): Content-addressable store, hard linking

### Agent Runtime

**Claude Code** is the agent runtime. It provides the execution environment for agents: spawning (Task tool), coordination (implicit per-session team, TaskCreate, SendMessage), isolation (worktree provisioning), permissions (sandbox, deny rules, hooks), and lifecycle management (agent start, stop, idle detection) [7].

Claude Code requires:
- **Claude model access**: API key or organization account with Anthropic, Bedrock, Vertex, or Foundry
- **MCP servers**: Configured per agent type with appropriate permissions. The Docker MCP Catalog provides 200+ verified servers for common integrations.

Terminal tools (tmux, yazi, neovim) are optional enhancements for the developer's workflow — they are not required for agent operation.

### Monitoring

Agents must be observable:
- Action logging to persistent storage
- Token consumption tracking
- Real-time status dashboards
- Alerting for error conditions

---

## Adoption Path

### Phase 0: Foundation

Engineers master git worktrees and terminal workflows. Establish conventions for naming and directory structure.

**Deliverable**: Every engineer can create a worktree, make changes, commit, and merge using terminal tools.

**Achievable today** with Claude Code and PDS installed. No additional infrastructure required.

### Phase 1: Supervised Single-Agent

One agent, active human oversight. Build familiarity with agent behavior, effective prompts, failure modes.

**Deliverable**: Each engineer completes five supervised agent tasks across different work types.

**Achievable today** — this is the default Claude Code experience with PDS skills guiding the workflow.

### Phase 2: Multi-Agent Local

Parallel workers on local machines. Learn task decomposition and resource management.

**Deliverable**: Each engineer completes three multi-agent tasks. Team documents best practices.

**Achievable today** using Claude Code's native Task/TaskCreate tools (implicit per-session teams) with PDS's swarm skill. Requires sufficient local compute for concurrent agents.

### Phase 3: Cloud Infrastructure

Agents run in isolated cloud environments. Implement governance framework with IAM roles and network policies.

**Deliverable**: Infrastructure supports ten concurrent agents. At least one overnight execution without supervision.

**Partially achievable today.** Claude Code runs locally, but headless agent primitives (`CronCreate`, `run_in_background`, SessionStart/Stop hooks) enable a subset of Phase 3 capabilities without cloud infrastructure: scheduled local agents for overnight audits, preflight validation at session start, and background telemetry analysis. Full cloud execution (agents in persistent pods, remote monitoring) requires infrastructure that does not yet exist in the Claude Code ecosystem. The primitives are there (agent spawning, task coordination, hook-based governance), but the deployment model is local-first. Teams pursuing full Phase 3 would need custom infrastructure around Claude Code's CLI.

### Phase 4: Full Autonomy

Agents execute complete tasks from requirements to PR. Human attention focuses on review and architecture.

**Deliverable**: Measurable increase in development capacity.

**Vision-forward.** Requires Phase 3 infrastructure plus matured governance: automated escalation, cost controls, quality thresholds that trigger human intervention. This is the end state the model aims for; Phases 0-2 are the achievable foundation today.

---

## Governance and Security

### The Human Gate

**Non-negotiable**: No agent action reaches production without human approval.

Agents write code, run tests, create PRs. They cannot merge, deploy, or affect users. The PR is the enforcement mechanism.

### Isolation Boundaries

**Sandbox**: All Bash commands run inside an OS-level sandbox (Seatbelt on macOS, bubblewrap on Linux). Writes are confined to the working directory. Network access is restricted to `allowedDomains`. Commands that need broader access (`git`, `docker`) are excluded from the sandbox and go through the normal permission flow.

**Network**: Workers access only package registries via the sandbox allowlist. Validators may need test database endpoints (added to allowlist per project). Orchestrators access external APIs. All network restrictions are OS-enforced for Bash commands.

**Filesystem**: Agents access only their designated worktree for writes (OS-enforced via sandbox). Reads are broadly allowed across the repository for cross-worktree monitoring.

**Credentials**: Scoped to role. No agent receives production credentials. Credential paths are blocked by both deny rules and sandbox filesystem restrictions.

**Resources**: CPU/memory limits prevent runaway processes. Token budgets prevent unbounded costs.

### Enterprise Readiness

PDS's plugin architecture positions it well for enterprise environments, but three Claude Code enterprise controls affect deployment:

- **`strictPluginOnlyCustomization`** — Blocks non-plugin skills, agents, hooks, and MCP servers. PDS survives this control because it distributes as a plugin. Non-plugin customizations (project-level CLAUDE.md, hooks) would be blocked.
- **`strictKnownMarketplaces`** — Only plugins from approved marketplace sources can be installed. PDS needs marketplace presence for enterprise adoption.
- **`allowManagedHooksOnly`** — Only hooks defined in `managed-settings.json` execute. This would block PDS hooks unless PDS is distributed as a managed-settings-compatible package. Enterprise IT would need to include PDS hook configurations in their managed settings.

**Path forward:** For enterprise deployments, PDS should provide a managed-settings overlay that IT administrators can merge into their `managed-settings.json`. This preserves the full PDS hook lifecycle while satisfying enterprise lockdown requirements.

### Runtime Security

- **Secret blocking**: Agents cannot access or transmit secrets
- **Call logging**: All agent actions logged for audit
- **Interceptors**: Custom policies for organization-specific requirements

### Audit Trail

Git commits record code and timing. Agent logs record actions and reasoning. Token usage records cost. These support debugging and compliance.

### Failure Recovery

**Worker failure**: Orchestrator detects, preserves partial work, retries or escalates.

**Orchestrator failure**: Workers complete current work. Human picks up from last checkpoint.

**Infrastructure failure**: State preserved, resume on recovery.

**Implementation**: Frequent commits (every significant change) plus orchestrator checkpoints to a manifest file recording task state.

---

## Cost Considerations

### API Tokens

Token costs vary dramatically by model tier. Real per-model pricing (per million tokens, input/output):

| Model | Input | Output | Typical Role |
|-------|-------|--------|-------------|
| Haiku 3.5 | $0.80 | $4.00 | Lite-tier workers, scout |
| Haiku 4.5 | $1.00 | $5.00 | Lite-tier workers |
| Sonnet | $3.00 | $15.00 | Med-tier workers, validator, reviewer |
| Opus 4 / 4.1 | $15.00 | $75.00 | Orchestrator (med/heavy), researcher (heavy) |
| Opus 4.5 | $5.00 | $25.00 | Cost-effective reasoning |
| Opus 4.6 fast | $30.00 | $150.00 | Maximum capability orchestrator |

**Cost examples by swarm tier:**

- **Lite swarm** (haiku workers, sonnet orchestrator): A 2-worker swarm with ~50k turns total. Workers at haiku ($0.80/$4 per Mtok) plus orchestrator at sonnet ($3/$15 per Mtok). Estimated: $5-15 for a routine task.
- **Med swarm** (sonnet workers, opus orchestrator): A 3-worker swarm with ~100k turns total. Workers at sonnet ($3/$15) plus orchestrator at opus ($15/$75). Estimated: $20-60 for a substantial task.
- **Heavy swarm** (sonnet workers, opus orchestrator, full specialists): A 4-worker swarm with full specialist roster. Estimated: $50-150 for a complex multi-boundary refactor.

**Swarm tiers** provide cost control at the architectural level. A lite tier swarm using haiku workers costs roughly 10-20x less than a heavy tier swarm for the same number of turns. The grill protocol recommends the appropriate tier based on problem complexity, preventing over-spending on routine tasks while ensuring complex work gets adequate model capability.

Token budgets provide control — tasks pause and request intervention when exhausted.

### Prompt Cache Economics

Prompt caching significantly reduces effective cost for PDS workflows. Each `systemPromptSection()` wrapping in Claude Code's system prompt assembly enables per-section caching — unchanged sections across turns hit the cache at 10% of the base input price. In a typical multi-turn agent session, 60-80% of input tokens may hit the cache.

**The swarm cache tax:** Each agent spawn creates a new conversation with its own prompt cache. Cache efficiency is per-agent, not shared across the swarm. A 4-worker swarm builds 4 separate caches — the orchestrator's cache doesn't benefit workers, and workers don't benefit each other. The first few turns of each agent pay full input price while the cache warms. PDS mitigates this through `shared-rules.md` — agents with byte-identical system prompt prefixes get better cache alignment. Placing shared rules at the top of agent definitions maximizes the shared prefix length, reducing per-agent cache warming cost. But fundamentally, more agents means more total cache warming cost — a key reason swarm tiers exist. Lite tiers are not just about cheaper per-token pricing; they also reduce the number of separate caches that need warming.

### Compute

Cloud execution scales with concurrent agents and duration. Spot instances work for ephemeral workers. On-demand for orchestrators and validators. Today, most PDS usage is local — cloud cost applies only when Phase 3 infrastructure is built.

### Storage

Worktrees duplicate working files. 500MB repo with ten worktrees: ~5GB peak. Ephemeral — deleted on completion.

### Economics

Compare agent costs against developer time, not in isolation. Four hours of developer time typically exceeds agent costs for equivalent work.

Agents favor: parallelizable, well-defined, automatically validatable tasks.
Direct work favors: continuous judgment, ambiguous requirements.

---

## Context Compression

Agent configuration files consume context window. Compression is tempting but has a fidelity cliff — beyond a threshold, agents lose operational knowledge and produce worse results [3].

**Platform support for compression:** Claude Code provides a sophisticated context compression system internally. Source analysis reveals five compaction modes, not the three documented publicly:

1. **Auto-compact** (`autoCompact.ts`, 13k) — Monitors token usage, triggers compaction before hitting the limit
2. **Micro-compact** (`microCompact.ts`, 20k) — Targeted compaction of individual tool results
3. **Reactive compact** (feature-gated: `REACTIVE_COMPACT`) — Real-time compaction during streaming
4. **Context collapse** (feature-gated: `CONTEXT_COLLAPSE`) — Aggressive context folding
5. **History snip** (feature-gated: `HISTORY_SNIP`) — Trim old conversation history entirely

The main compaction uses the LLM itself to summarize old messages, creating a compact boundary — everything before is summarized into a single message, everything after is preserved verbatim. The prompt caching mechanism (`cache_control` on message blocks) means unchanged context — including PDS's CLAUDE.md and skill content — is cached across turns, reducing both cost and latency. PDS benefits from compaction and caching automatically without explicit configuration.

**Context Preservation**: PreCompact and PostCompact hooks preserve PDS swarm state across context compaction events. Before compaction, a snapshot captures the current phase, tier, and task summary. After compaction, this snapshot is re-injected as additional context, preventing the loss of swarm coordination state during long-running sessions. This is critical because long swarms will hit compaction mid-phase — when the LLM's summary of earlier messages may lose PDS-specific context (current phase, task statuses, coordination decisions made). The PreCompact/PostCompact hook pair ensures this state survives compression.

### What's Safe to Compress

- **Decorative formatting**: Horizontal rule dividers (`---`), excessive blank lines, redundant section headers. Markdown headers provide sufficient hierarchy.
- **Cross-file deduplication**: Content stated identically in multiple files. Define once, cross-reference elsewhere (e.g., coordination model defined in `/team`, agents reference "See /team").
- **LLM-known concepts**: Explanations of well-documented tools or universal patterns. "git is a version control system" adds nothing. But "git bisect to binary-search regressions" reinforces method.

### What's NOT Safe to Compress

- **Role sections**: Tell an agent what it is. Without "produce structured context reports for the orchestrator to plan," the researcher drifts into implementation suggestions.
- **Constraints**: Define boundaries. "Read-only. You do NOT write files" prevents a researcher from editing code. "Does NOT fix code — report issues" prevents a validator from patching.
- **Process steps**: Encode methodology. A 6-step debugging protocol produces different behavior than "debug the issue."
- **Output formats**: Structure agent output for downstream consumption. Without a structured validation report format, the validator produces unstructured prose the orchestrator can't parse.
- **Step-by-step examples**: Especially in complex workflows like merging. Agents need exact git commands and the sequence matters — a compressed "rebase then merge" loses the conflict resolution flow, the cleanup commands, and the multi-subtask coordination pattern.
- **Anti-pattern tables with rationale**: The "Why" column prevents agents from rationalizing exceptions. "Don't merge without a summary" without "because the coordinator can't meaningfully review" lets the agent skip summaries when it thinks the change is obvious.
- **Engineering method patterns**: git bisect, TDD, rubber duck debugging. These reinforce disciplined technique over ad-hoc problem solving. They're not trivia — they're method.

### The Test

Two questions, in order:

1. **"Would an agent get *stuck* without this?"** Multi-step sequences where missing a step causes failure (shutdown → response then team dissolves at session end, plan approval response flow) must stay — even if they're native platform behavior documented elsewhere. The agent may never navigate to that documentation in time.
2. **"Would an agent behave *differently* without this?"** If the line changes agent behavior — or you're unsure — keep it. If it restates something the agent already knows from built-in tool documentation and can't cause a failure mode, cut it.

---

## Engineering Best Practices

PDS encodes two complementary layers of engineering guidance, designed to be MECE (mutually exclusive, collectively exhaustive):

**Principles** (`docs/ethos.md`) define *why* — the philosophy that grounds decisions. Understand before acting. Small reversible steps. Tests as specification. Explicit over implicit. Optimize for change. Fail fast. Automation as documentation.

**Techniques** (encoded across skills) define *how* — the concrete methods that implement principles:

| Technique | Skill / Agent | Principle it implements |
|-----------|---------------|------------------------|
| Hypothesis-driven debugging | `/pds:bugfix` | Understand before you act |
| git bisect for regression hunting | `/pds:bugfix` | Automation as documentation |
| Rubber duck protocol | `/pds:grill` | Explicit over implicit |
| TDD (RED/GREEN/REFACTOR) | native (Claude) | Tests as specification |
| Behavior-based test naming | native (Claude) | Explicit over implicit |
| Atomic commits | `/pds:finish` | Small, reversible steps |
| Severity-categorized review | reviewer agent | Fail fast, recover gracefully |
| Rebasing-first merge coordination | `/pds:swarm` | Optimize for change |
| Requirement interrogation | `/pds:grill` | Understand before you act |
| Completion verification | `/pds:verify` | Explicit over implicit |
| Branch preparation for merge | `/pds:finish` | Small, reversible steps |
| Version bump and ship | `/pds:finish` | Explicit over implicit |
| Statistical skill evaluation | `/pds:eval` | Tests as specification |

This separation matters: principles are stable across projects and technologies, while techniques evolve with tooling and practice. An agent grounded in principles makes better judgment calls when no specific technique applies.

Skills themselves need testing — a modified skill that silently degrades is worse than no skill. PDS uses LLM-as-judge grading [10] with statistical repetition and Wilson score confidence intervals [8][9] to evaluate whether skills produce the intended agent behavior. Eval criteria are subject to drift [11] — "users need criteria to grade outputs, but grading outputs helps users define criteria" — so eval scenarios are calibrated against observed model behavior, testing reasoning quality rather than predetermined answers [12]. This treats skills as testable artifacts, not just documentation.

---

## Testing and Resilience

Enforcement without testing creates false confidence. A hook that should block secret leakage but has an untested regex gap provides worse security than acknowledged open exposure — it eliminates vigilance while providing none. PDS applies the same discipline to its own enforcement infrastructure that it applies to production code.

### Three Testing Layers

**Unit tests** verify hook correctness deterministically — no LLM required. Each hook script receives JSON input (tool name, arguments, agent context) and produces a decision (block/allow/scrub). Test fixtures supply known inputs and assert expected outputs. A hook that scrubs `GITHUB_TOKEN=abc123` should produce `GITHUB_TOKEN=***REDACTED***`, not silence. Shell-based test runners execute in milliseconds and are suitable for pre-commit gates. See `hooks/tests/` for the fixture structure and test runner.

**Skill evals** measure whether skills produce correct agent behavior. Unlike unit tests, skills are non-deterministic — the same prompt yields different outputs across runs. Statistical rigor is required. PDS uses LLM-as-judge grading with Wilson score confidence intervals across N executions per scenario. Each skill carries a companion `EVAL.md` defining scenarios, expected behaviors (binary checklist), and anti-patterns. See `/pds:eval` and `scripts/run-eval.sh` for the full methodology, including run-count guidance (3 for smoke, 5 for default, 10 for serious checks, 20 for regression baselines) and cost model (haiku execution + sonnet grading ≈ $0.10/run).

**Integration tests** validate the installation itself. Smoke tests confirm that `install.sh` produces a working plugin: hooks fire on expected events, skills load via the Skill tool, agents spawn with correct permissions.

### Why Hook Testing Matters

Hooks are the mechanical enforcement layer. They fire automatically, independent of agent instructions. A failing hook silently downgrades enforcement — the agent receives no error, the developer sees no indication the gate they rely on is non-functional.

Three hook categories warrant particular rigor:

- **Security**: Secret scrubbing hooks (PostToolUse, UserPromptSubmit) must redact credential patterns reliably. A gap in regex coverage is a vulnerability, not a minor bug.
- **Quality**: Task-completion gates and post-write lint hooks enforce standards across all agents. An untested gate can silently pass on the exact failure case it was designed to catch.
- **Phase gates**: PreToolUse gates block PR creation and team teardown unless required artifacts exist. An untested edge case could allow a swarm to exit a phase prematurely, skipping validation or review.

Unit tests prove correctness of the hook logic. Evals prove effectiveness in agent context — that agents respond to hook output as intended, not just that the hook output is technically correct.

### The Improvement Cycle

Testing closes the loop between observation and improvement:

1. **Telemetry** surfaces usage patterns and anomalies (`scripts/detect-patterns.sh`)
2. **Scout (Phase 6)** analyzes the swarm: evals skills exercised, updates instinct confidence, flags regressions
3. **Instincts** accumulate evidence — observations gain confidence across swarms (low → medium → high at 3+ validations), then promote to skills via the scout agent
4. **Evals narrow confidence intervals** each cycle — N=5 gives a wide CI; N=20 gives an actionable one
5. **Skills and hooks improve** based on evidence, not intuition

This is measured improvement. The Wilson score CI tracks progress quantitatively. A skill that regresses from 90% to 60% pass rate after a modification is a detected regression, not a silent degradation. Each cycle builds the evidence base that distinguishes genuine improvement from random variation — the same standard PDS applies to production code.

---

## Resolved Questions

These questions from v1.0 have been resolved through research and implementation experience:

| Question | Resolution |
|----------|------------|
| **Inter-agent communication** | Supported via SendMessage (direct, broadcast). Orchestrator coordinates through TaskCreate/TaskUpdate task DAGs. Independent execution preferred for simplicity; direct communication available when tasks require it. |
| **Lexicon structure** | Instincts in `.claude/instincts.md` — git-backed markdown with structured entries (confidence, context, action). Scout automates lifecycle: capture → validate → promote → retire. See `/instinct` skill. |
| **Failure recovery** | Frequent commits + orchestrator checkpoints to manifest file. Worktree itself preserves partial work. |
| **Metrics** | Primary: tokens per task, validation cycles before pass, human intervention rate. Secondary: PRs merged, time to deployment. |
| **Organizational integration** | PR-based workflow is the integration point. Agents produce PRs that flow through existing review processes. No changes to sprint planning or on-call. |
| **How does PDS plug into Claude Code?** | Via the plugin system. PDS installs as a marketplace plugin to `~/.claude/plugins/pds/`. The plugin manifest (`plugin.json`) declares skills, agents, hooks, and MCP servers. Claude Code loads these automatically at session start. Project-level `.claude/settings.json` and `CLAUDE.md` provide team overrides. |
| **What does PDS own vs. Claude Code?** | Claude Code owns the runtime: model API, tool execution, sandbox, agent spawning, worktree management. PDS owns the methodology: SDLC phases, human gates, agent roles, skill protocols, quality gate hooks, context engineering patterns. This separation means PDS configuration is portable — it's markdown and JSON, not Anthropic SDK types. |

---

## Conclusion

The agentic SDLC is a structural change in development. AI agents operate autonomously within well-defined boundaries. Infrastructure provides those boundaries. Clear interfaces separate humans and agents. Rigorous governance maintains safety.

The path is incremental: foundational skills, supervised use, parallel execution — achievable today with Claude Code and PDS. Cloud infrastructure and full autonomy remain vision-forward goals that the model is designed to support when the platform catches up.

The investment is substantial. The return — a step-change in development velocity with maintained quality — justifies it.

This is a living document. The model evolves with implementation experience, improving AI capabilities, and deeper platform understanding. What matters now is to begin.

---

## Appendix A: Tooling Quick Reference

| Category | Tool | Purpose |
|----------|------|---------|
| Terminal | tmux | Session management (optional) |
| Terminal | yazi | File navigation (optional) |
| Terminal | neovim + telescope | Multi-worktree editing (optional) |
| Version Control | git worktree | Core functionality |
| Version Control | lazygit | Terminal UI |
| Dependencies | uv | Python (fast) |
| Dependencies | pnpm | Node.js (efficient) |
| Agent Runtime | Claude Code | Agent execution environment |
| Agent Runtime | MCP servers | Tool integrations |
| Agent Coordination | Implicit per-session team | Auto team setup + shared task list (no TeamCreate/TeamDelete since v2.1.178) |
| Agent Coordination | TaskCreate/TaskUpdate | Task DAG management |
| Agent Coordination | SendMessage | Inter-agent communication |
| Agent Coordination | Task (worker) | Worker agent spawning |
| Infrastructure | Kubernetes | Cloud orchestration (vision-forward) |

---

## Appendix B: Glossary

**Orchestrator**: Primary agent that plans, dispatches workers, and consolidates results. Core tier.

**Researcher**: Agent that gathers context during Phase 1 — querying documentation, searching codebases, mapping dependencies. Core tier.

**Worker**: Agent executing a specific subtask in an isolated worktree. Core tier (N instances per swarm).

**Validator**: Agent responsible for merging branches, running tests, and reporting validation results. Core tier.

**Reviewer**: Agent performing automated pre-review — code quality, security, consistency checks — before human Phase 5 review. Specialist tier.

**Documenter**: Agent updating user-facing documentation when changes warrant it. Specialist tier.

**Scout**: Agent analyzing completed swarms for PDS meta-improvements — workflow optimizations, skill gaps, configuration updates. Manages instinct lifecycle: validates patterns, bumps confidence, proposes skill promotions. Specialist tier.

**Auditor**: Agent scanning codebases for tech debt, code smells, and missing tests, filing findings as GitHub issues. Spawned periodically, not per-swarm. Specialist tier.

**Worktree**: Git feature providing independent working directory sharing the repository's object store.

**MCP**: Model Context Protocol — standard for agent interaction with external tools.

**Plugin**: A Claude Code extension unit that bundles skills, agents, hooks, and MCP server configurations. Installed once at the user level, available across all projects. PDS distributes as a plugin.

**Hook**: A lifecycle event handler that fires automatically at specific points in the agent lifecycle. Claude Code provides 28 hook events. PDS uses hooks for quality gates, audit logging, and permission routing.

**Settings Hierarchy**: Claude Code's 4-layer settings merge system: policy settings (enterprise admin, highest priority) > user settings (`~/.claude/settings.json`) > project settings (`.claude/settings.json`) > local settings (`.claude/settings.local.json`). Deny rules are additive — lower layers cannot remove higher-layer denies.

**Prompt Cache**: Claude Code's mechanism for caching unchanged system prompt sections across turns. PDS's passive context (CLAUDE.md, skills table) benefits from prompt caching automatically, reducing cost and latency for repeated turns.

**Compact**: Claude Code's context compression system for managing long conversations. Five modes: auto-compact (summarize older context), micro-compact (targeted tool result compression), reactive compact (real-time during streaming), context collapse (aggressive folding), and history snip (trim old history). PDS does not configure compact directly — it operates automatically.

**Lexicon**: Persistent repository of engineering knowledge, queryable by agents. Implemented as instincts in `.claude/instincts.md`.

**Instinct**: A structured observation of a recurring pattern — lighter than a skill, with confidence levels and an automated lifecycle managed by scout.

**Acceptance Criteria**: Specific, mechanically verifiable conditions defining task completion.

**Phase Gate**: A mechanical enforcement point (PreToolUse hook or prompt evaluator) that blocks phase transitions unless required artifacts exist. Prevents SDLC phases from being skipped.

**Telemetry**: Opt-in, local-only JSONL logging of PDS skill, agent, and file usage. Disabled by default (`PDS_TELEMETRY=0`). Managed via `/telemetry` skill.

**Context Preservation**: PreCompact/PostCompact hook pair that snapshots and re-injects PDS swarm state across context compaction events.

**Auto-Instinct**: Scout-driven pattern detection from telemetry data during Phase 6 (Knowledge). `scripts/detect-patterns.sh` proposes instinct entries for recurring usage patterns.

**Swarm Artifacts**: Phase reports written to `.claude/swarm/` during a swarm — `validation-report.md` (Phase 4), `review-report.md` (Phase 5), `scout-report.md` (Phase 6). Required by phase gates for PR creation and team teardown.

**Swarm Tier**: One of three cost/capability levels (lite, med, heavy) that control model selection and specialist inclusion for a swarm. Set during Phase 1 grill, stored in `.claude/swarm/tier`. Lite uses haiku workers for routine tasks. Med uses sonnet workers (the default). Heavy uses opus for reasoning-heavy roles with full specialist roster.

**Efficiency Ratio (η)**: The ratio of value-creating time to total elapsed time per agent. Calculated from telemetry events: η = Σ(value-creating time) / Σ(total elapsed time). Higher values indicate less waste.

**Headless Agent**: An agent that runs without an interactive session — via `CronCreate`, `run_in_background`, or lifecycle hooks. Used for preflight validation, scheduled audits, telemetry analysis, and post-swarm cleanup.

**Dual-Dispatch**: The orchestrator's runtime decision to use fork (quick, invisible, context-inheriting) vs. team teammate (long-running, visible, role-specialized) based on task characteristics. See Native Agent Teams.

**Context Protocol**: A structured file (`.claude/swarm/context.md`) written by the orchestrator before worker dispatch, containing the plan, research findings, acceptance criteria, and key decisions. Workers read it on init to recover orchestrator context without fork-level inheritance.

**Human Gate**: Principle that no agent work reaches production without human approval.

**SendMessage**: Tool for direct and broadcast communication between agents in a team.

**TaskCreate**: Tool for defining work units with dependencies, forming task DAGs.

**Implicit team**: Since CC v2.1.178 an agent team with a shared task list is established automatically per session (formed on first spawn; the explicit TeamCreate/TeamDelete tools were removed).

---

## Appendix C: References

1. Hadfield, J., Zhang, B., Lien, K., Scholz, F., Fox, J., & Ford, D. (2025). "Multi-agent research system." *Anthropic Engineering Blog.* https://www.anthropic.com/engineering/multi-agent-research-system — Opus lead + Sonnet subagents outperformed single-agent Opus by 90.2% on internal research eval. 3-5 parallel subagents, ~15x token usage vs chat.

2. Vercel Engineering. (2025). "AGENTS.md outperforms skills in our agent evals." *Vercel Blog.* https://vercel.com/blog/agents-md-outperforms-skills-in-our-agent-evals — Passive context (always-loaded AGENTS.md) achieves 100% pass rate for horizontal knowledge; skills without invocation instructions scored 53%; carefully worded skills reached 79%.

3. Boeckeler, B. & Fowler, M. (2026). "Context Engineering for Coding Agents." *martinfowler.com.* https://martinfowler.com/articles/exploring-gen-ai/context-engineering-coding-agents.html — Defines context engineering as curating model input for better output. Notes over-stuffing context hurts more than helps.

4. Anthropic. (2025). "Effective Context Engineering for AI Agents." *Anthropic Engineering Blog.* https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents

5. The New Stack. (2026). "Memory for AI Agents: A New Paradigm of Context Engineering." https://thenewstack.io/memory-for-ai-agents-a-new-paradigm-of-context-engineering/ — Large context windows improved short-term coherence but did not solve memory. 2026 production standard: dual-layer memory (hot path + cold path retrieval).

6. HuggingFace. (2026). "2026 Agentic Coding Trends." https://huggingface.co/blog/Svngoku/agentic-coding-trends-2026 — Engineers shifting from writing code to coordinating agents. Central orchestrator + specialist sub-agents as the emerging standard.

7. Anthropic. (2025). "Enabling Claude Code to work more autonomously." *Anthropic News.* https://www.anthropic.com/news/enabling-claude-code-to-work-more-autonomously

8. Anthropic. (2025). "Demystifying Evals for AI Agents." *Anthropic Engineering Blog.* https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents — Three-grader system (code, model, human). pass@k for capability, pass^k for consistency. Start with 20-50 tasks from real failures.

9. AgentAssay. (2026). "Probabilistic Regression Testing for AI Agents." *arXiv 2603.02601.* https://arxiv.org/abs/2603.02601 — Three-valued verdicts (Pass/Fail/Inconclusive) with Wilson score CIs. Behavioral fingerprinting achieves 86% regression detection where binary testing has 0%.

10. Agent-as-a-Judge. (2025). *arXiv 2508.02994.* https://arxiv.org/html/2508.02994v1 — Agent evaluators disagree with human majority vote 0.3% of the time; single LLM judges disagree 31%. Strongest evidence for LLM-as-judge reliability in agentic evaluation.

11. Shankar, S. et al. (2024). "Who Validates the Validators? Aligning LLM-Assisted Evaluation of LLM Outputs with Human Preferences." *UIST 2024.* https://arxiv.org/abs/2404.12272 — Criteria drift: evaluation criteria evolve upon observing model outputs, even when defined a priori. Eval authors need to iterate criteria against actual behavior.

12. Husain, H. (2026). "Your AI Product Needs Evals." https://hamel.dev/blog/posts/evals/ — Write evaluators for errors you discover, not errors you imagine. Observe model behavior before finalizing criteria. Binary pass/fail forces clarity over subjective Likert scales.

13. Ohno, T. (1988). *Toyota Production System: Beyond Large-Scale Production.* Productivity Press. — Value Stream Mapping, seven wastes (muda), continuous flow, just-in-time production. The foundational framework for identifying and eliminating non-value-creating activity in any process.

14. Beck, K. (2004). *Extreme Programming Explained: Embrace Change.* 2nd ed. Addison-Wesley. — Feedback loops, eliminate waste, simplicity, sustainable pace. XP's waste elimination principle applied to software development predates but aligns with lean software thinking.

15. Poppendieck, M. & T. (2003). *Lean Software Development: An Agile Toolkit.* Addison-Wesley. — Bridges Toyota Production System to software: eliminate waste, amplify learning, deliver fast, empower the team. Maps manufacturing waste categories to software development equivalents.

---

## Appendix D: Platform Architecture (Observed 2026-03-31)

This appendix documents Claude Code's internal architecture as observed through source analysis on March 31, 2026. This is a snapshot — Claude Code is actively developed and internals may change. PDS treats these as implementation details informing its design, not guaranteed APIs.

### System Prompt Assembly Pipeline

Claude Code builds the system prompt through a cached, multi-stage pipeline:

1. **`getSystemPrompt()`** in `constants/prompts.ts` builds an array of prompt sections
2. **`systemPromptSection()`** wraps each section with caching metadata (`cache_control`) for Anthropic's prompt cache — unchanged sections across turns hit the cache, reducing cost
3. **`fetchSystemPromptParts()`** in `utils/queryContext.ts` assembles three components: system prompt base + user context + system context
4. **`getUserContext()`** loads all CLAUDE.md files (user, project, local) plus the current date
5. **`getSystemContext()`** captures a git status snapshot for repository awareness
6. **QueryEngine** adds: coordinator context (for multi-agent mode), memory mechanics prompt, and any `--system-prompt` override
7. Custom system prompts (`--system-prompt` flag) replace the default pipeline entirely

PDS enters this pipeline at step 4: CLAUDE.md content is loaded as `userContext.claudeMd`. Skills and agent definitions are loaded separately by `loadSkillsDir.ts` and `loadAgentsDir.ts` from the plugin directory.

### Settings Hierarchy

Four layers with strict merge rules:

| Layer | Location | Priority | Purpose |
|-------|----------|----------|---------|
| **Policy** | `managed-settings.json` | Highest (deny rules) | Enterprise admin controls |
| **User** | `~/.claude/settings.json` | User preferences | Personal overrides |
| **Project** | `.claude/settings.json` | Repo-level | Team-shared configuration |
| **Local** | `.claude/settings.local.json` | Machine-specific | Per-machine overrides |

**Merge rules**: Deny rules are additive — a lower layer can add stricter rules but cannot remove a higher layer's denies. Allow rules are intersective at the policy layer. Other settings follow standard override precedence (higher layer wins for conflicts).

Key settings: permissions (allow/deny/ask rules), hooks, environment variables, model selection, sandbox configuration, worktree config, MCP servers, plugins, status line.

### Hook Lifecycle Events

28 events in 7 categories:

| Category | Events |
|----------|--------|
| Tool lifecycle | `PreToolUse`, `PostToolUse`, `PostToolUseFailure` |
| Session lifecycle | `SessionStart`, `SessionEnd`, `Stop`, `StopFailure`, `Setup` |
| Agent lifecycle | `SubagentStart`, `SubagentStop`, `TeammateIdle`, `TaskCreated`, `TaskCompleted` |
| Permission | `PermissionRequest`, `PermissionDenied` |
| Configuration | `ConfigChange`, `WorktreeCreate`, `WorktreeRemove`, `InstructionsLoaded`, `CwdChanged`, `FileChanged` |
| Context | `PreCompact`, `PostCompact`, `UserPromptSubmit`, `Notification` |
| Interaction | `Elicitation`, `ElicitationResult` |

**Hook implementation types**: bash command, agent hook (spawn Claude to evaluate), HTTP webhook (since 2.1.63), internal callback.

**Hook response types**: continue/stop execution, approve/deny permission, inject context (`additionalContext`), modify tool input/output.

**Agent awareness**: All events include `agent_id` and `agent_type` since Claude Code 2.1.69.

### Plugin Loading

Three sources:

| Source | Location | Use Case |
|--------|----------|----------|
| **Builtin** | Ships with Claude Code CLI | Core functionality |
| **Marketplace** | Git repositories, installed via `claude mcp install-marketplace` | Community plugins (PDS) |
| **Local** | Symlinked directory | Development and testing |

Plugin manifest (`plugin.json`) declares: name, description, version. The plugin directory provides: `skills/` (loaded by Skill tool), `agents/` (loaded by Agent tool), `hooks/hooks.json` (merged into hook event handlers), MCP server configurations.

Enterprise environments can restrict customization to plugins only via `strictPluginOnlyCustomization` — ensuring all agent configuration comes through approved plugin channels.

### Feature Flags

Claude Code uses GrowthBook for feature flag management. Active experiments observed as of 2026-03-31 (this list is a point-in-time snapshot):

REACTIVE_COMPACT, CONTEXT_COLLAPSE, EXPERIMENTAL_SKILL_SEARCH, TEMPLATES, HISTORY_SNIP, FORK_SUBAGENT, COORDINATOR_MODE, BASH_CLASSIFIER, TRANSCRIPT_CLASSIFIER, TOKEN_BUDGET, KAIROS, BRIDGE_MODE, BUDDY, VOICE_MODE, EXTRACT_MEMORIES, BG_SESSIONS, AGENT_TRIGGERS, REVIEW_ARTIFACT, WORKFLOW_SCRIPTS, MONITOR_TOOL, PROACTIVE, CACHED_MICROCOMPACT, among others.

Notable for PDS: `COORDINATOR_MODE` (multi-agent orchestration), `FORK_SUBAGENT` (agent spawning model), `REACTIVE_COMPACT` and `CACHED_MICROCOMPACT` (context compression), `AGENT_TRIGGERS` (event-driven agent spawning).

### Cost Model Internals

Per-model pricing as defined in `modelCost.ts` (per million tokens):

| Model | Input | Output | Cache Write | Cache Read |
|-------|-------|--------|-------------|------------|
| Haiku 3.5 | $0.80 | $4.00 | $1.00 | $0.08 |
| Haiku 4.5 | $1.00 | $5.00 | $1.25 | $0.10 |
| Sonnet | $3.00 | $15.00 | $3.75 | $0.30 |
| Opus 4 / 4.1 | $15.00 | $75.00 | $18.75 | $1.50 |
| Opus 4.5 | $5.00 | $25.00 | $6.25 | $0.50 |
| Opus 4.6 fast | $30.00 | $150.00 | $37.50 | $3.00 |

Prompt caching significantly reduces effective cost for PDS workflows — the CLAUDE.md content, skills table, and system prompt sections are cached across turns. In a typical multi-turn agent session, 60-80% of input tokens may hit the cache at 10% of the base input price.
