# Claude Code Source Analysis — March 2026

A reverse-engineering analysis of the Claude Code CLI internals. Point-in-time snapshot from compiled source obtained March 31, 2026. Written for the PDS team — engineers of varying experience levels.

---

## TL;DR

- **Claude Code is a system prompt compiler with an agentic loop.** The system prompt is assembled in 5 stages: base instructions → CLAUDE.md content → plugin/MCP instructions → hook-injected context → conversation history. Understanding this pipeline is how PDS maximizes its influence.
- **28 hook lifecycle events exist. PDS uses 6.** The untapped events (PreToolUse, PostToolUse, SubagentStart, PreCompact, UserPromptSubmit, FileChanged) could enforce the SDLC at the process level — not just via prompt instructions.
- **The LLM has zero abstraction.** Anthropic SDK types permeate the entire codebase. Their "multi-provider" support (Bedrock, Vertex, Foundry) is multi-deployment of Claude, not multi-model. You cannot swap in OpenAI or a local model.
- **PDS is already more model-agnostic than Claude Code.** Our extension points (CLAUDE.md, skills, agents, hooks, settings) are all markdown and JSON — portable to any LLM harness.
- **30+ feature flags signal heavy investment** in context management, agent coordination, and automation triggers. PDS is ahead on structured agent workflows; they're ahead on context window optimization.
- **PDS has zero usage telemetry.** We can't know which skills and agents are actually used. The instinct system has never recorded a single pattern. We need observability before optimization.
- **CLAUDE.md content is prompt-cached.** PDS's instructions to Claude are token-efficient — they're part of the cache prefix, not re-processed each turn.

---

## Table of Contents

1. [How We Got Here](#how-we-got-here)
2. [Architecture Overview](#architecture-overview)
3. [The System Prompt Pipeline](#the-system-prompt-pipeline)
4. [The Agentic Loop](#the-agentic-loop)
5. [Tool System](#tool-system)
6. [Hook System](#hook-system)
7. [Plugin System](#plugin-system)
8. [Agent / Team System](#agent--team-system)
9. [Settings Hierarchy](#settings-hierarchy)
10. [Context Window Management](#context-window-management)
11. [Where the LLM Lives](#where-the-llm-lives)
12. [Feature Flag Roadmap](#feature-flag-roadmap)
13. [What This Means for PDS](#what-this-means-for-pds)
14. [Appendix: Cost Model](#appendix-cost-model)

---

## How We Got Here

On March 31, 2026, compiled source code for the Claude Code CLI appeared on Twitter/X. The release was the Bun-bundled JavaScript output — not raw TypeScript — but with enough structure (class names, function signatures, module boundaries, string literals) to reconstruct the architecture in detail.

Whether this was an intentional community-engagement move or an actual leak is unclear. Anthropic has not commented. Either way, the architecture will likely shift in response. **This document is a dated snapshot, not a living reference.** The internal implementation details (prompt assembly order, feature flags, compaction algorithms) may change. The extension points we care about — hooks, plugins, settings, CLAUDE.md — are the public API surface and are unlikely to break without notice, since doing so would break every plugin in their marketplace.

**What we analyzed:** ~10MB of source spanning 35+ directories, 800+ files. Key files range from 3k to 804k lines. The codebase is a Bun/TypeScript application using Ink (React for CLI) for terminal UI rendering.

**Why it matters for PDS:** PDS runs as a plugin on top of Claude Code. Understanding the host's internals lets us: (1) exploit extension points we weren't using, (2) avoid reinventing things Claude Code already handles, (3) understand what actually happens when our skills, hooks, and agents fire, and (4) plan for eventual model independence with clear knowledge of coupling boundaries.

---

## Architecture Overview

Claude Code is structured as a layered system:

```
┌──────────────────────────────────────────────────┐
│  main.tsx (804k)                                 │
│  CLI entrypoint, option parsing, session setup   │
├──────────────────────────────────────────────────┤
│  QueryEngine.ts (47k)                            │
│  Session orchestrator: manages ask/respond cycles│
├──────────────────────────────────────────────────┤
│  query.ts (69k)                                  │
│  The agentic loop: tool calls, retries, context  │
├──────────────────────────────────────────────────┤
│  services/api/claude.ts (126k)                   │
│  API call layer, message construction, streaming │
├──────────────────────────────────────────────────┤
│  services/api/client.ts (16k)                    │
│  Provider factory: firstParty/Bedrock/Vertex/    │
│  Foundry — ALL Claude, NO other models           │
├──────────────────────────────────────────────────┤
│  @anthropic-ai/sdk                               │
│  Anthropic's TypeScript SDK                      │
└──────────────────────────────────────────────────┘
```

**Key directories:**

| Directory | Purpose | Size |
|-----------|---------|------|
| `tools/` | 35+ built-in tools (Bash, Read, Write, Edit, Glob, Grep, Agent, Task*, Team*, Skill, MCP, etc.) | Large — AgentTool alone is 234k |
| `hooks/` | React hooks for UI state (not PDS-style lifecycle hooks — naming collision) | 50+ files |
| `services/` | API, analytics, compaction, MCP, OAuth, plugins, voice, memory | Core business logic |
| `bridge/` | IDE integration (VS Code, JetBrains) via WebSocket protocol | 116k bridgeMain.ts |
| `coordinator/` | Multi-agent orchestration mode | 19k |
| `skills/` | Built-in skill loading and bundled skills | 34k loader + bundled/ |
| `plugins/` | Plugin registry and built-in plugins | Small — most logic in utils/plugins/ |
| `context/` | Notifications, context assembly helpers | Small |
| `state/` | AppState management | Centralized state store |

---

## The System Prompt Pipeline

This is where PDS has the most leverage. Understanding how the system prompt is assembled tells us exactly where our CLAUDE.md, skills, and hooks inject their influence.

### Stage 1: Base System Prompt

`constants/prompts.ts` → `getSystemPrompt()` builds an array of cached sections:

1. **Intro** — "You are Claude Code, Anthropic's official CLI for Claude."
2. **Tool instructions** — How to use each tool, git commit/PR workflows, tone/style guidance
3. **Session guidance** — Available skill commands, output style configuration
4. **Memory prompt** — Auto-memory system instructions (how Claude manages `~/.claude/projects/*/memory/`)
5. **Environment info** — Platform, shell, model name, CWD, git repo status

Each section is individually cached via a `systemPromptSection()` wrapper. This means **changing one section doesn't invalidate the cache for others** — prompt caching is efficient.

### Stage 2: CLAUDE.md Content

`context.ts` → `getUserContext()` walks the filesystem from CWD up to `~`, collecting all `CLAUDE.md` files:

```
~/.claude/CLAUDE.md                          (user global)
/path/to/project/CLAUDE.md                   (project root)
/path/to/project/.claude/CLAUDE.md           (project .claude dir)
/path/to/project/subdir/CLAUDE.md            (subdirectory)
```

All CLAUDE.md content is concatenated and injected as `userContext` in the system prompt prefix. **This content is prompt-cached** — it's part of the stable prefix that Anthropic's API caches between turns. PDS's CLAUDE.md instructions are token-efficient; they're not re-processed each turn.

The `CLAUDE_CODE_DISABLE_CLAUDE_MDS` env var disables all CLAUDE.md loading. The `--bare` flag skips auto-discovery but honors explicit `--add-dir` directories.

### Stage 3: Plugin / MCP Instructions

Connected MCP servers contribute their own instructions via a dedicated system prompt section. Plugin-provided skills appear in the Skill tool's available-skills listing. This section can be dynamically updated (MCP servers connect/disconnect between turns), which is why it uses `DANGEROUS_uncachedSystemPromptSection` — it busts the prompt cache when it changes.

### Stage 4: Hook-Injected Context

Hooks that return `additionalContext` in their JSON response inject that text into the next model turn as a `<system-reminder>`. This is how PDS's `SessionStart` hook injects version info and key skill reminders. The context appears in the conversation, not the system prompt prefix — it's per-turn, not cached.

### Stage 5: Conversation History

Messages are normalized via `normalizeMessagesForAPI()` before each API call. This includes:
- Pairing tool_use blocks with tool_result blocks (Anthropic API requirement)
- Stripping internal metadata (attribution, progress messages)
- Applying content replacement for large tool results (references to stored content)
- Truncating old messages when the context window is full (compaction)

### Custom System Prompt Override

The `--system-prompt` and `--system-prompt-file` flags replace the default system prompt entirely. The `--append-system-prompt` flag adds content after the default. When a custom system prompt is set, `getSystemContext()` is skipped (no git status injection), since the custom prompt replaces the default.

---

## The Agentic Loop

The core of Claude Code is a tool-call loop in `query.ts`. Here's how it works:

### Turn Cycle

```
User message
  → Assemble context (system prompt + messages + tool results)
  → Stream API request to Anthropic
  → Parse response: text blocks + tool_use blocks
  → For each tool_use:
      → Check permissions (hooks, settings, user approval)
      → Execute tool
      → Collect tool_result
  → If response has tool_use and stop_reason == "tool_use":
      → Loop back (automatic continuation)
  → If stop_reason == "end_turn" or "stop_sequence":
      → Run stop hooks
      → Return to user
```

Key detail: **the loop is automatic.** When the model emits a tool call, Claude Code executes it and feeds the result back without waiting for user input. This is what makes it "agentic" — the model drives itself through multi-step tasks. The loop only pauses for permission approval (if required by the permission mode) or when the model decides to stop.

### Streaming

Responses stream via Anthropic's `Stream<BetaRawMessageStreamEvent>`. Events include:
- `message_start` — response metadata, model info
- `content_block_start` / `content_block_delta` / `content_block_stop` — text and tool_use blocks
- `message_delta` — stop_reason, usage stats
- `message_stop` — end of response

The streaming is Anthropic-specific. No generic streaming adapter exists.

### Retry Logic

`services/api/withRetry.ts` (28k) handles API failures:
- Rate limits → exponential backoff with jitter
- Overloaded → retry with delay
- Network errors → retry with backoff
- Prompt too long → trigger compaction, retry
- Authentication errors → refresh tokens, retry

A `FallbackTriggeredError` mechanism exists for switching to alternative models on failure.

### Tool Execution

Tools can execute **in parallel during streaming** via `StreamingToolExecutor`. When the model emits multiple tool_use blocks in a single response, Claude Code can begin executing them before the full response completes. This is a significant performance optimization — tool execution overlaps with response generation.

`services/tools/toolOrchestration.ts` manages the execution pipeline, including:
- Permission checking before execution
- Pre/PostToolUse hook firing
- Result size budgeting (large results get compressed or stored externally)
- Error handling and retry

---

## Tool System

### Built-in Tools (35+)

| Category | Tools |
|----------|-------|
| **File I/O** | Read, Write (FileWrite), Edit (FileEdit), Glob, Grep |
| **Execution** | Bash, PowerShell, REPL, NotebookEdit |
| **Agent** | Agent, SendMessage, TaskCreate, TaskGet, TaskList, TaskUpdate, TaskStop, TaskOutput (TeamCreate/TeamDelete removed at v2.1.178 — teams are now implicit per-session) |
| **Planning** | EnterPlanMode, ExitPlanMode, EnterWorktree, ExitWorktree |
| **Knowledge** | Skill, ToolSearch, WebFetch, WebSearch |
| **MCP** | MCPTool, ListMcpResources, ReadMcpResource, McpAuth |
| **Config** | Config, AskUserQuestion, RemoteTrigger, ScheduleCron |
| **Other** | Sleep, SyntheticOutput, Brief, TodoWrite, LSP |

### Tool Registration

Tools are defined in `Tool.ts` (30k) with this interface:

```typescript
type Tool = {
  name: string
  description: string          // Shown to the model
  inputSchema: ToolInputJSONSchema
  isEnabled: () => boolean     // Dynamic enable/disable
  call: (input, context) => Promise<ToolResult>
  permissions: PermissionConfig
  // ... progress reporting, validation, etc.
}
```

Tools are registered at startup and filtered based on:
- Feature flags (some tools are gated)
- Agent definition (agents specify which tools they have access to)
- Permission mode (some tools are restricted in certain modes)

### Tool Deferral

A key optimization: **not all tool schemas are sent to the model upfront.** The `ToolSearch` tool exists specifically because sending 35+ full tool schemas would consume significant context. Instead, less-commonly-used tools are "deferred" — only their names appear in a system reminder. The model calls `ToolSearch` to fetch the full schema when needed. This is why you see `<system-reminder>` blocks listing deferred tools at the start of conversations.

### MCP Tool Integration

MCP (Model Context Protocol) tools from connected servers are dynamically registered alongside built-in tools. They use the same permission system and hook lifecycle. MCP tool names are prefixed with the server name (e.g., `mcp__slack__send_message`).

---

## Hook System

This is the most important section for PDS. Claude Code's hook system is our primary enforcement mechanism.

### All 28 Hook Events

| Category | Event | When It Fires |
|----------|-------|--------------|
| **Session** | `SessionStart` | Session begins |
| | `SessionEnd` | Session ends |
| | `Setup` | First-time setup |
| **Tool** | `PreToolUse` | Before any tool executes |
| | `PostToolUse` | After tool succeeds |
| | `PostToolUseFailure` | After tool fails |
| **Agent** | `SubagentStart` | Agent/subagent spawned |
| | `SubagentStop` | Agent/subagent exits |
| | `TeammateIdle` | Teammate has no work |
| **Task** | `TaskCreated` | Task created |
| | `TaskCompleted` | Task marked complete |
| **Context** | `PreCompact` | Before context compaction |
| | `PostCompact` | After context compaction |
| | `InstructionsLoaded` | CLAUDE.md/rules files loaded |
| **Permission** | `PermissionRequest` | Tool needs permission |
| | `PermissionDenied` | Permission was denied |
| **File** | `FileChanged` | Watched file modified |
| | `CwdChanged` | Working directory changed |
| | `WorktreeCreate` | Git worktree created |
| | `WorktreeRemove` | Git worktree removed |
| **Lifecycle** | `Stop` | Model wants to stop |
| | `StopFailure` | Stop hook rejected |
| | `Notification` | System notification |
| | `ConfigChange` | Settings changed |
| **Interaction** | `UserPromptSubmit` | User sends a message |
| | `Elicitation` | Model asks user a question |
| | `ElicitationResult` | User answers elicitation |

### Hook Types

| Type | How It Works | Example |
|------|-------------|---------|
| **command** | Runs a shell script, reads JSON from stdout | PDS's `session-start.sh`, `task-completed-gate.sh` |
| **prompt** | Sends a prompt to the LLM, reads JSON response | PDS's `Stop` hook (asks LLM to evaluate completion) |
| **http** | POSTs to a URL, reads JSON response | Webhook integrations, centralized policy servers |
| **agent** | Spawns a Claude agent to evaluate | Complex evaluation requiring multi-step reasoning |
| **callback** | Internal function (not user-configurable) | Built-in analytics, session management |

### Hook Response Capabilities

A hook's JSON response can:

| Capability | JSON Field | Effect |
|-----------|-----------|--------|
| Continue/stop | `continue: false` | Blocks the action |
| Approve/deny | `decision: "approve"/"block"` | Permission decision |
| Inject context | `additionalContext: "..."` | Added to next model turn as `<system-reminder>` |
| Modify tool input | `updatedInput: {...}` | Changes tool parameters before execution |
| Modify tool output | `updatedMCPToolOutput: ...` | Changes MCP tool results after execution |
| Custom permission | `permissionDecision: "allow"/"deny"` | Override permission system |
| Stop reason | `stopReason: "..."` | Message shown when blocking |
| System message | `systemMessage: "..."` | Warning shown to user |

### PDS Hook Usage (Current vs. Available)

| Event | PDS Uses? | Current Implementation | Opportunity |
|-------|----------|----------------------|-------------|
| SessionStart | **Yes** | Injects version, key skills, worktree info | Solid |
| PermissionRequest | **Yes** | LLM-based allow/deny routing | Solid |
| Stop | **Yes** | Completion verification for implementation sessions | Solid |
| TaskCompleted | **Yes** | Test runner gate | Solid |
| TeammateIdle | **Yes** | Uncommitted changes check | Solid |
| WorktreeCreate | **Yes** | Event logging | Minimal — just appends to log |
| InstructionsLoaded | **Yes** | Event logging | Minimal — just appends to log |
| PreToolUse | No | — | **High value**: gate tool calls with PDS policy |
| PostToolUse | No | — | **High value**: usage telemetry, pattern tracking |
| SubagentStart | No | — | **High value**: enforce agent roster |
| UserPromptSubmit | No | — | **Medium**: inject relevant PDS skill suggestions |
| PreCompact | No | — | **Medium**: preserve PDS context during compaction |
| PostCompact | No | — | **Medium**: re-inject PDS state after compaction |
| FileChanged | No | — | **Low**: watch PDS artifact changes |
| SubagentStop | No | — | **Low**: collect agent performance data |
| TaskCreated | No | — | **Low**: validate task structure |

### Matchers

Hooks support matchers — regex patterns that filter which tool calls trigger the hook:

```json
{
  "matcher": "Bash|Write|Edit",
  "hooks": [{ "type": "command", "command": "..." }]
}
```

This lets PDS target specific tools without firing on every tool call.

---

## Plugin System

PDS is a Claude Code plugin. Understanding the plugin system tells us what we can and can't do.

### Plugin Manifest (`plugin.json`)

```json
{
  "name": "pds",
  "description": "Portable Development System",
  "version": "4.5.1",
  "repository": "https://github.com/rmzi/portable-dev-system"
}
```

### What a Plugin Can Provide

| Component | Mechanism | PDS Uses? |
|-----------|-----------|-----------|
| **Skills** | Markdown files in `skills/` directory | Yes — 18 skills |
| **Agents** | Markdown files in `agents/` directory | Yes — 9 agents |
| **Hooks** | `hooks.json` file | Yes — 6 events |
| **MCP servers** | MCP config in manifest | No |
| **Settings overlay** | Plugin-scoped settings | Partially — env vars |

### Plugin Loading

1. Plugins are discovered from `~/.claude/plugins/` and marketplace sources
2. `loadSkillsDir.ts` (34k) walks the skills directory, parses frontmatter from each `SKILL.md`
3. Skills appear in the Skill tool's available commands listing
4. Agent definitions are loaded by `loadAgentsDir.ts` (26k) and appear in the Agent tool's available types
5. Hooks from `hooks.json` are merged into the global hook registry

### Enterprise Controls

Claude Code supports enterprise lockdown via managed settings:

- **`strictPluginOnlyCustomization`** — Blocks non-plugin skills, agents, hooks, MCP servers. If an enterprise enables this, only plugin-provided customizations work. **PDS survives this because it is a plugin.**
- **`strictKnownMarketplaces`** — Only plugins from approved marketplaces can be installed.
- **`allowManagedHooksOnly`** — Only hooks from `managed-settings.json` execute. User/project/plugin hooks are ignored. **This would block PDS hooks** — something to be aware of for enterprise deployments.

### Skill Loading Optimization

Skills are loaded lazily — only the frontmatter (name, description, whenToUse) is sent to the model upfront. The full skill content (the SKILL.md body) is only loaded when the model invokes the skill via the Skill tool. This is why PDS skills can be arbitrarily detailed without inflating the base context.

---

## Agent / Team System

### How Agents Spawn

When the model calls the `Agent` tool:

1. `AgentTool.tsx` (234k) processes the request
2. If `subagent_type` matches a defined agent (PDS's 9 agents — namespaced `pds:<name>`, since they ship in a plugin — or built-in types like `Explore`, `Plan`), that agent's definition is loaded
3. `runAgent.ts` (36k) forks a new Claude Code subprocess
4. The child process gets:
   - Its own system prompt (from agent definition's `getSystemPrompt()`)
   - Filtered tool list (only tools the agent is allowed to use)
   - Permission mode (from agent definition: `default`, `bypassPermissions`, `bubble`, etc.)
   - Optional worktree isolation (`isolation: "worktree"`)
   - Optional model override (for swarm tiers: `model: "haiku"` for lite workers)

### Coordinator Mode

A special mode (`CLAUDE_CODE_COORDINATOR_MODE=1`) transforms Claude Code into a multi-agent orchestrator:

- The coordinator's system prompt changes entirely (defined in `coordinatorMode.ts`)
- Coordinator role: break work into tasks, dispatch to workers, manage dependencies
- Workers get a defined subset of tools (Bash, Read, Edit, Glob, Grep, etc.)
- Workers also get MCP tools from connected servers
- A scratchpad directory enables cross-worker knowledge sharing

**PDS comparison:** PDS's swarm model (orchestrator → researcher → worker → validator → reviewer → documenter → scout) is more structured than Claude Code's generic coordinator mode. PDS adds: role specialization, phase gates, swarm tiers, pull-model task claiming, and artifact-based coordination. The coordinator mode is the platform; PDS provides the methodology on top.

### Fork Subagent (New)

A feature flag (`FORK_SUBAGENT`) enables forking the parent's full conversation context into a child agent. The child inherits:
- Parent's system prompt (byte-exact, for cache efficiency)
- Full conversation history
- Same tool pool

This is different from PDS's agent model where each agent starts fresh with its own system prompt. Fork subagents are for "do this subtask with full context" rather than "play this specialized role."

### Communication

Agents communicate via:
- **SendMessage** — Direct message between agents (by name)
- **TaskCreate/TaskUpdate** — Shared task system (visible to all agents in a team)
- **Scratchpad** — Shared filesystem directory for durable cross-agent knowledge

---

## Settings Hierarchy

Claude Code uses a 4-layer settings system with specific merge semantics:

```
Layer 1: policySettings (managed-settings.json)
  │       Enterprise admin, highest priority for deny rules
  │       Path: /Library/Application Support/ClaudeCode/managed-settings.json
  ↓
Layer 2: userSettings (~/.claude/settings.json)
  │       User preferences, API keys, model selection
  ↓
Layer 3: projectSettings (.claude/settings.json)
  │       Repo-level, checked into git
  │       This is where PDS installs its config
  ↓
Layer 4: localSettings (.claude/settings.local.json)
          Per-machine overrides, gitignored
```

### Merge Semantics

- **Deny rules are additive** — deny lists from all layers are merged. If any layer denies something, it's denied.
- **Allow rules are intersective** — the effective allow set is the intersection across layers (tightest wins).
- **Scalar values** — higher-priority layers override lower ones.
- **Arrays** — behavior varies by field (some merge, some override).

### Key Settings for PDS

| Setting | Type | PDS Relevance |
|---------|------|--------------|
| `permissions.allow/deny/ask` | Array of rules | PDS uses deny rules for credential protection |
| `permissions.defaultMode` | Enum | PDS could recommend `auto` mode with policy hooks |
| `hooks` | Hook config | PDS's primary enforcement mechanism |
| `env` | Key-value pairs | PDS injects `PDS_VERSION`, `PDS_PLUGIN_ROOT` |
| `worktree.symlinkDirectories` | String array | PDS recommends `node_modules` symlinks |
| `worktree.sparsePaths` | String array | Monorepo optimization |
| `sandbox.network.allowedHosts` | String array | PDS adds GitHub API access |
| `model` | String | Can be overridden per-session |
| `availableModels` | String array | Enterprise model allowlist |
| `modelOverrides` | Key-value | Map model IDs to provider-specific IDs |

---

## Context Window Management

Claude Code invests heavily in context efficiency. This is their most sophisticated subsystem.

### Compaction Strategy

When the context window fills up, Claude Code compacts old messages:

1. **Auto-compact** (`services/compact/autoCompact.ts`, 13k) — Monitors token usage, triggers compaction before hitting the limit
2. **Micro-compact** (`services/compact/microCompact.ts`, 20k) — Small, targeted compaction of individual tool results
3. **Reactive compact** (`services/compact/reactiveCompact.ts`, feature-gated) — Real-time compaction during streaming
4. **Context collapse** (feature-gated) — Aggressive context folding
5. **History snip** (feature-gated) — Trim old conversation history entirely

The main compaction (`compact.ts`, 61k) uses the LLM itself to summarize old messages. It creates a compact boundary message — everything before the boundary is summarized into a single message. Messages after the boundary are preserved verbatim.

### Token Estimation

`services/tokenEstimation.ts` (17k) estimates token counts without calling the API. This is used for:
- Deciding when to compact
- Budgeting tool result sizes
- Monitoring context usage in the status bar

### Tool Result Storage

Large tool results are stored externally and replaced with references. When a tool returns a huge file read or bash output, the content is:
1. Stored in a content replacement map
2. Replaced with a short reference in the message
3. The reference persists in the conversation; the full content is available if the model requests it

### Why This Matters for PDS

Long swarms can hit compaction mid-phase. When compaction fires, the LLM's summary of earlier messages may lose PDS-specific context (current phase, task statuses, decisions made). This is why PreCompact/PostCompact hooks are valuable — PDS can snapshot its state before compaction and re-inject it after.

---

## Where the LLM Lives

### The Short Answer

The LLM is hardwired to Anthropic. There is no abstraction layer.

### The Detailed Answer

**API call site:** `services/api/claude.ts` (126k) constructs API requests using Anthropic SDK types directly:

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

These types are used throughout the codebase — in message construction, tool result parsing, streaming event handling, token counting, and error handling. There is no intermediate message format.

**Provider factory:** `services/api/client.ts` supports 4 providers:

```typescript
export type APIProvider = 'firstParty' | 'bedrock' | 'vertex' | 'foundry'
```

All 4 are **different deployment targets for Claude models:**
- `firstParty` — api.anthropic.com (direct API)
- `bedrock` — AWS Bedrock (Claude via AWS)
- `vertex` — Google Cloud Vertex AI (Claude via GCP)
- `foundry` — Azure AI Foundry (Claude via Azure)

There is no OpenAI provider, no Ollama provider, no generic LLM interface.

**Model registry:** `utils/model/configs.ts` defines 11 model configurations:

| Model | First-Party ID | Bedrock ID | Vertex ID |
|-------|---------------|------------|-----------|
| Haiku 3.5 | claude-3-5-haiku-20241022 | us.anthropic.claude-3-5-haiku-... | claude-3-5-haiku@... |
| Haiku 4.5 | claude-haiku-4-5-20251001 | us.anthropic.claude-haiku-4-5-... | claude-haiku-4-5@... |
| Sonnet 3.5 v2 | claude-3-5-sonnet-20241022 | ... | ... |
| Sonnet 3.7 | claude-3-7-sonnet-20250219 | ... | ... |
| Sonnet 4.0 | claude-sonnet-4-20250514 | ... | ... |
| Sonnet 4.5 | claude-sonnet-4-5-20250929 | ... | ... |
| Sonnet 4.6 | claude-sonnet-4-6 | ... | ... |
| Opus 4.0 | claude-opus-4-20250514 | ... | ... |
| Opus 4.1 | claude-opus-4-1-20250805 | ... | ... |
| Opus 4.5 | claude-opus-4-5-20251101 | ... | ... |
| Opus 4.6 | claude-opus-4-6 | ... | ... |

All Claude. No hooks for custom or local models.

### What This Means

1. **You cannot run Claude Code with a different model.** The `ANTHROPIC_MODEL` env var selects between Claude models, not between model providers.
2. **The `ANTHROPIC_BASE_URL` env var** can point to a proxy, but the proxy must speak the Anthropic API format (not OpenAI's).
3. **PDS's extension points are already model-agnostic.** CLAUDE.md, skills, agents, hooks, and settings are markdown, JSON, and shell — they don't import from `@anthropic-ai/sdk`. If PDS ever builds its own harness, these artifacts port directly.

---

## Feature Flag Roadmap

Claude Code uses GrowthBook for feature flagging. The `feature('FLAG_NAME')` function is a compile-time gate — Bun eliminates dead code paths at build time. We observed 30+ flags:

### Context Management (Highest Investment)

| Flag | What It Does | PDS Implication |
|------|-------------|-----------------|
| `REACTIVE_COMPACT` | Real-time compaction during streaming | Free benefit — longer swarms before context issues |
| `CONTEXT_COLLAPSE` | Aggressive context folding | Free benefit — more room for PDS context |
| `HISTORY_SNIP` | Trim old conversation history | Risk: may trim PDS-relevant history. PreCompact hook mitigates. |
| `CACHED_MICROCOMPACT` | Cache-friendly small compactions | Performance improvement for tool-heavy sessions |

### Agent Coordination

| Flag | What It Does | PDS Implication |
|------|-------------|-----------------|
| `COORDINATOR_MODE` | Multi-agent orchestration mode | PDS's swarm is more structured; this is the platform underneath |
| `FORK_SUBAGENT` | Fork parent context to child | Different model from PDS agents; could complement for quick subtasks |
| `BG_SESSIONS` | Background session management | Enables async agent workflows |

### Automation & Triggers

| Flag | What It Does | PDS Implication |
|------|-------------|-----------------|
| `AGENT_TRIGGERS` | Scheduled/event-driven agent runs | Relates to issue #80 (auto-claude research) |
| `AGENT_TRIGGERS_REMOTE` | Remote trigger execution | CI/CD integration potential |
| `WORKFLOW_SCRIPTS` | Custom workflow automation | PDS hooks already provide this |

### Intelligence / Classification

| Flag | What It Does | PDS Implication |
|------|-------------|-----------------|
| `BASH_CLASSIFIER` | ML-based bash command safety | Better auto-mode permission decisions |
| `TRANSCRIPT_CLASSIFIER` | Classify conversations for auto-mode | Enables auto permission mode (less prompting) |
| `EXPERIMENTAL_SKILL_SEARCH` | Semantic skill matching | Better skill discovery (currently keyword-based) |
| `EXTRACT_MEMORIES` | Auto-extract memories from conversations | Similar to PDS instinct system goal |

### New Interfaces

| Flag | What It Does | PDS Implication |
|------|-------------|-----------------|
| `BRIDGE_MODE` | IDE bridge (VS Code, JetBrains) | PDS doesn't need to replicate UI |
| `CCR_MIRROR` | Claude Code Remote mirroring | Enterprise remote development |
| `KAIROS` | New interaction paradigm (heavily gated) | Unknown — appears in bridge, session mgmt, and UI code |
| `BUDDY` | Companion/assistant mode | Unknown |
| `VOICE_MODE` | Voice interaction | Modality expansion |

### Where PDS Leads

- **Structured agent workflows** — PDS's 6-phase SDLC with role-specific agents is more opinionated than their generic coordinator mode
- **Workflow enforcement** — PDS's grill → implement → verify → finish pipeline has no Claude Code equivalent
- **Quality gates** — PDS hooks enforce SDLC stages; Claude Code's hooks are general-purpose
- **Swarm tiers** — Cost-aware model selection per agent role

### Where They Lead

- **Context management** — 61k of compaction code vs. PDS's zero investment here (we get it free)
- **Intelligence** — ML-powered classifiers for bash safety and permission auto-mode
- **IDE integration** — Native VS Code/JetBrains bridge
- **Memory** — Auto-memory extraction (PDS instinct system exists but is unused)

---

## What This Means for PDS

### Immediate Wins (Low Effort, High Impact)

1. **Add PostToolUse hook for usage telemetry** — Log every skill invocation and agent spawn to `.claude/telemetry.jsonl`. We currently have zero visibility into which PDS features are actually used. This is the single most important next step.

2. **Add SubagentStart hook for roster enforcement** — Validate that spawned agents match PDS's 8-agent roster. Warn on unknown types. Prevents ad-hoc agents from bypassing the role model.

3. **Add UserPromptSubmit hook for skill discovery** — Keyword-match the user's prompt to suggest relevant PDS skills. Makes PDS more discoverable without bloating CLAUDE.md.

### Medium-Term Improvements

4. **Add PreCompact/PostCompact hooks** — Snapshot PDS state before compaction, re-inject after. Critical for long swarms that hit context limits mid-phase.

5. **Wire instinct system into telemetry** — Auto-detect patterns from telemetry data (skill used 3+ times/session, recurring failures). Feed into `.claude/instincts.md` automatically instead of relying on manual `/pds:instinct` invocation.

6. **Teach scout agent to consume telemetry** — Phase 6 analysis should include a Usage section with hard data on which skills and agents were invoked during the swarm.

### Long-Term Strategic

7. **Model-agnostic abstraction research** — Document which PDS features depend on Claude-specific capabilities. Evaluate OpenAI-compatible adapter feasibility. Low priority per current direction — PDS's extension points are already portable.

8. **Enterprise readiness** — Understand that `allowManagedHooksOnly` would disable PDS hooks. Consider providing PDS as a managed-settings-compatible package for enterprise deployments.

---

## Appendix: Cost Model

Per-model pricing from `utils/modelCost.ts` (per million tokens):

| Model | Input | Output | Cache Write | Cache Read |
|-------|-------|--------|-------------|------------|
| Haiku 3.5 | $0.80 | $4.00 | $1.00 | $0.08 |
| Haiku 4.5 | $1.00 | $5.00 | $1.25 | $0.10 |
| Sonnet (all) | $3.00 | $15.00 | $3.75 | $0.30 |
| Opus 4.0/4.1 | $15.00 | $75.00 | $18.75 | $1.50 |
| Opus 4.5 | $5.00 | $25.00 | $6.25 | $0.50 |
| Opus 4.6 (fast) | $30.00 | $150.00 | $37.50 | $3.00 |

**PDS cost implications:**
- PDS swarm lite tier (haiku workers) is **10-20x cheaper** than default sonnet workers
- Prompt caching means PDS CLAUDE.md content costs cache-read rates ($0.30/Mtok for sonnet), not full input rates ($3/Mtok)
- Each agent spawn creates a new conversation with its own prompt cache — cache efficiency is per-agent, not shared across the swarm

---

## Update — Observed 2026-08-03

Consistent with this document's own stated practice (a point-in-time snapshot, not a living reference — see "How We Got Here"), the March 31 tables above are left as-is. This addendum records what's changed since, confirmed against current official Claude Code documentation rather than re-inferred from source:

- **`TeamCreate` and `TeamDelete` no longer exist as tools** — removed as of Claude Code v2.1.178. Team formation and cleanup are now automatic: a team forms on the first teammate spawn, and tears down when the session ends. The Tool System table above (`Agent` category) still lists both under the March snapshot; that entry is now stale. See `docs/adr/0007-teardown-gate-migration-from-teamdelete-to-stop.md` for how PDS adapted its `TeamDelete`-gated teardown check to this removal.
- **Team and task state paths confirmed**: team config lives at `~/.claude/teams/session-<id>/config.json` (removed automatically at session end); task state lives at `~/.claude/tasks/session-<id>/` and persists after the session ends — but neither directory syncs across machines or users. Team names follow the pattern `session-` + the first 8 characters of the session ID.
- **`Stop` hook payload confirmed to include `cwd`**, identical to `PreToolUse` — a command-type `Stop` hook receives the same JSON-stdin shape (`session_id`, `prompt_id`, `transcript_path`, `cwd`, `permission_mode`, `hook_event_name`, plus a `last_assistant_message` field specific to `Stop`) rather than the `$ARGUMENTS`-only surface PDS's one prior `Stop` hook (a prompt-type hook in `validator.md`) used. Command-type `Stop` hooks support the same exit-code-2 blocking that `PreToolUse` hooks do.
- **Multiple `Stop` hooks compose as AND**: all matching hooks run in parallel; a block from any one of them blocks the stop, and none silently overrides another. This was confirmed directly rather than inferred from the general hook-execution model.
- **`SessionEnd` is advisory-only and cannot block** — exit code 2 shows a message to the user but does not prevent the session from ending, and JSON output on `SessionEnd` is ignored entirely. This is why PDS's teardown-gate migration targets `Stop`, not `SessionEnd`, despite `SessionEnd`'s name reading like the more obvious fit.

---

*Last updated: 2026-03-31, addendum 2026-08-03. Point-in-time snapshot from compiled source. Internal implementation may have changed since this analysis.*
