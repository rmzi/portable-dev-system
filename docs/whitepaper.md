# Agentic SDLC: A Technical Whitepaper

**Version 2.1 | February 2026**

---

## Executive Summary

This whitepaper details a model for software development where AI agents operate as autonomous collaborators. Rather than treating AI as sophisticated autocomplete, we propose infrastructure where agents plan, execute, validate, and document work with minimal human intervention.

The goal is amplification, not replacement. A single engineer orchestrates multiple agents working in parallel, each in isolated environments, producing work that flows through automated validation before human review. The human remains architect and final authority. The agents become a scalable workforce.

This document provides the technical depth required to implement this model: the conceptual framework, isolation architecture, tooling requirements, adoption path, and governance framework.

---

## The Problem

Traditional development workflows hit fundamental limits as AI capabilities improve:

**Human attention becomes the bottleneck.** When AI generates code faster than humans can review it, cognitive bandwidth—not typing speed—becomes the constraint.

**Context switching destroys productivity.** Supervising multiple agents fragments attention. The cost compounds throughout the day.

**Idle time accumulates.** When developers leave, work stops. When CI runs, work stops. These gaps represent unrealized capacity.

**The feedback loop stays slow.** Write-test-fix-test requires human presence at each iteration. Autonomous iteration would compress this cycle dramatically.

The agentic SDLC addresses these limitations by restructuring development around autonomous agents operating within well-defined boundaries.

---

## The Model

Six phases, each with clear inputs, outputs, and transition criteria. Human involvement concentrates at phase boundaries.

### Phase 1: Requirements and Planning

Work begins when requirements arrive. The developer engages with an orchestrating agent to refine requirements into an actionable plan.

The orchestrator runs `/grill` — a structured requirement interrogation protocol — to validate requirements before decomposition. This protocol covers: restating the problem, defining scope boundaries, establishing verifiable acceptance criteria, surfacing constraints, challenging assumptions, identifying risks, ranking priorities, and performing a MECE check to ensure requirements don't overlap and all cases are covered. Ambiguous requirements are the primary source of wasted tokens in agentic workflows.

The orchestrator may spawn a **researcher** agent to gather context: querying documentation, searching codebases, accessing external APIs. The orchestrator synthesizes this research and produces a structured task specification.

The critical output is explicit acceptance criteria—unambiguous and mechanically verifiable. "The API should be fast" becomes "p99 latency for /users under 200ms with 1000 concurrent connections."

### Phase 2: Task Decomposition and Dispatch

The orchestrator decomposes the plan into discrete work units for parallel execution. Each unit becomes a task assigned to a worker agent.

The orchestrator uses TaskCreate to build a task DAG, defining dependencies between work units. It then spawns worker agents via the Task tool, each receiving its own git worktree—complete, independent working directories sharing the underlying git object store. Each worker operates on its own branch, in its own directory, with no merge conflicts during execution.

The orchestrator records session metadata: which agents work on which worktrees, which branches they correspond to, expected deliverables, and task dependencies. This enables monitoring, recovery, and coordination.

### Phase 3: Parallel Execution

Workers execute independently. They access the codebase within their worktree, read documentation, and write code.

**Workers favor independent execution for simplicity but can communicate via SendMessage when tasks require coordination.** The orchestrator manages dependencies through task DAGs (defined via TaskCreate/TaskUpdate), ensuring workers can coordinate when needed while keeping most work independent to minimize overhead.

Each worker produces a result artifact: code changes, summary, issues encountered. Workers commit to their branches but do not merge.

### Phase 4: Validation

A validator agent examines all worker output by monitoring TaskUpdate status changes. The validator operates in its own worktree, merging worker branches and running comprehensive tests.

Responsibilities: writing tests based on acceptance criteria, running the existing test suite, performing static analysis, checking for defects. The validator does not fix issues—it produces a structured report (via TaskUpdate) identifying failures, localizing them, and suggesting remediation.

If validation fails, the report flows to the orchestrator, which updates the task DAG and dispatches targeted fix requests. This cycle continues until validation passes or human intervention is required.

### Phase 5: Consolidation and Human Review

The orchestrator consolidates worker branches into a single pull request, rebasing or squashing as needed for clean history. A **reviewer** agent performs automated pre-review — checking code quality, security patterns, and consistency — producing a structured report before human review. A **documenter** agent updates user-facing documentation when changes warrant it.

The developer reviews with full context: requirements, plan, validation results, reviewer findings, issues encountered. The developer can request changes (flowing back through the orchestrator) or approve for merge. The reviewer's automated pre-review supplements but never replaces the human gate.

### Phase 6: Knowledge Capture

Before merging, the orchestrator reviews what happened: patterns emerged, architectural decisions made, unexpected challenges. A **scout** agent analyzes the completed swarm for meta-improvements — workflow optimizations, skill gaps, configuration updates.

This knowledge flows into the lexicon—a persistent repository of engineering knowledge spanning tasks, repositories, and team members. The lexicon captures lessons learned, gotchas, and patterns.

An **auditor** agent may be spawned periodically (not per-swarm) to scan for tech debt, code smells, and missing tests, filing findings as GitHub issues.

Agents query the lexicon during future planning and execution, avoiding repeated mistakes and building on proven patterns.

---

## Core Technical Concepts

### Git Worktrees

A worktree is an additional working directory associated with a repository. Unlike a clone, it shares the object store (commits, blobs, trees) with the main repository. Creation is nearly instantaneous with minimal disk overhead.

```bash
git worktree add .worktrees/task-123-worker-1 -b task-123/worker-1
```

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

### Agent Isolation

Agents must operate within well-defined boundaries. Unrestricted access to production systems is unacceptable risk.

**Claude Code Permission Model**:

Rather than heavyweight container isolation, PDS uses Claude Code's native permission system combined with git worktree filesystem isolation:

- **Permission hooks** route agent actions through policy evaluation (see `/permission-router` skill)
- **Worktree isolation** limits each worker to its own `.worktrees/<task-id>/` directory
- **The human gate** ensures all changes flow through PR review before reaching production
- **Message routing** enables orchestrator oversight of all inter-agent communication
- **Token budgets** prevent unbounded costs and runaway agents

This approach favors lightweight isolation over heavyweight containers. The blast radius of a misbehaving worker is limited to its worktree branch. No changes reach production without human approval.

**Permission Tiers**:

| Agent Type | Network | Filesystem | Credentials |
|------------|---------|------------|-------------|
| Worker | Limited | Own worktree only | None |
| Validator | Test databases | Own worktree + read others | Test DB credentials |
| Orchestrator | External APIs (Jira, Slack) | All worktrees | API tokens (no prod) |

### Native Agent Teams

Agents execute as native Claude Code teams—no containers, no file synchronization, no heavyweight orchestration.

**TeamCreate** establishes a team with a shared task list. The orchestrator uses this to coordinate multiple agents working on related tasks.

**TaskCreate** defines work units with dependencies, forming task DAGs. Workers can depend on each other's completion, enabling sophisticated workflows while maintaining clarity about execution order.

**Task tool** spawns worker agents. Each worker receives its own git worktree (via `git worktree add`), providing filesystem isolation without containerization overhead. Workers operate in `.worktrees/<task-id>/` directories.

**SendMessage** enables direct and broadcast communication. Workers can ask questions, share findings, or coordinate when decomposition requires it. The orchestrator receives all messages and can route or respond as needed.

This approach eliminates Docker/container overhead while maintaining isolation through git worktrees and Claude Code's permission system. Agents run natively with full access to local tools (language servers, build tools, formatters) without the complexity of mounting volumes or synchronizing files.

### Instruction Architecture

Agent effectiveness depends on how instructions reach the model. [Vercel's agent evals](https://vercel.com/blog/agents-md-outperforms-skills-in-our-agent-evals) found that passive context (always-loaded AGENTS.md) achieves 100% pass rates for horizontal framework knowledge, while skills without explicit invocation instructions scored 53%. Skills with careful wording reached 79%.

PDS uses a dual-layer approach informed by these findings:

- **Passive context** (`CLAUDE.md`) — Always loaded. Carries rules, the skills table, and conventions that apply across all tasks. This is the horizontal layer.
- **Explicit skills** (`.claude/skills/`) — User-triggered vertical workflows (`/commit`, `/review`, `/grill`). Loaded on demand when the user or orchestrator invokes them. These encode multi-step protocols that would bloat passive context if always present.

The passive layer tells the agent *what skills exist and when to use them*. The skills themselves contain the detailed protocol. This avoids the failure mode identified in Vercel's research — agents not discovering skills during general tasks — while keeping context lean.

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

### The Lexicon

The lexicon is persistent engineering knowledge spanning tasks and team members.

**Recommended Structure**: Git-backed markdown files for version control and diffability, with a semantic search layer (vector database) for agent queries. This combines auditability with queryability.

The lexicon should be queryable during planning and execution. When agents encounter problems, they ask "has this been solved before?" and receive relevant context.

---

## Required Tooling

### Terminal Environment

The terminal provides a powerful interface for multi-worktree workflows. Graphical IDEs assume one project, one set of files, one debug session. Agentic workflows involve multiple worktrees and rapid context switching.

**Core tools** (optional but recommended):
- **tmux**: Terminal multiplexing, persistent sessions
- **yazi** or similar: Terminal file manager for worktree navigation
- **neovim + telescope**: Editor with multi-worktree support

Claude Code handles agent lifecycle natively through TeamCreate/TaskCreate/Task tools. tmux and terminal tools enhance the workflow but are not required for agent orchestration.

### Version Control

- **git worktree**: Core functionality
- **lazygit**: Terminal UI accelerating common operations
- Custom scripts for worktree lifecycle management

### Dependency Management

Each worktree needs dependencies. Prefer tools that make environment creation fast:

- **uv** (Python): Virtual environments in seconds, global package cache
- **pnpm** (Node.js): Content-addressable store, hard linking

### Agent Runtime

- **Claude**: Underlying model with extended thinking and tool use
- **Agent frameworks**: Scaffolding for autonomous operation
- **MCP servers**: Configured per agent type with appropriate permissions

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

### Phase 1: Supervised Single-Agent

One agent, active human oversight. Build familiarity with agent behavior, effective prompts, failure modes.

**Deliverable**: Each engineer completes five supervised agent tasks across different work types.

### Phase 2: Multi-Agent Local

Parallel workers on local machines. Learn task decomposition and resource management.

**Deliverable**: Each engineer completes three multi-agent tasks. Team documents best practices.

### Phase 3: Cloud Infrastructure

Agents run in isolated pods. Implement governance framework with IAM roles and network policies.

**Deliverable**: Infrastructure supports ten concurrent agents. At least one overnight execution without supervision.

### Phase 4: Full Autonomy

Agents execute complete tasks from requirements to PR. Human attention focuses on review and architecture.

**Deliverable**: Measurable increase in development capacity.

---

## Governance and Security

### The Human Gate

**Non-negotiable**: No agent action reaches production without human approval.

Agents write code, run tests, create PRs. They cannot merge, deploy, or affect users. The PR is the enforcement mechanism.

### Isolation Boundaries

**Network**: Workers have no network by default. Validators access test databases. Orchestrators access external APIs.

**Filesystem**: Agents access only their designated worktree.

**Credentials**: Scoped to role. No agent receives production credentials.

**Resources**: CPU/memory limits prevent runaway processes. Token budgets prevent unbounded costs.

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

Complex tasks: millions of tokens across phases. Substantial task: $10-50. Heavy daily usage: $100-500.

Token budgets provide control—tasks pause and request intervention when exhausted.

### Compute

Cloud execution scales with concurrent agents and duration. Spot instances work for ephemeral workers. On-demand for orchestrators and validators.

### Storage

Worktrees duplicate working files. 500MB repo with ten worktrees: ~5GB peak. Ephemeral—deleted on completion.

### Economics

Compare agent costs against developer time, not in isolation. Four hours of developer time typically exceeds agent costs for equivalent work.

Agents favor: parallelizable, well-defined, automatically validatable tasks.
Direct work favors: continuous judgment, ambiguous requirements.

---

## Context Compression

Agent configuration files consume context window. Compression is tempting but has a fidelity cliff — beyond a threshold, agents lose operational knowledge and produce worse results.

### What's Safe to Compress

- **Decorative formatting**: Horizontal rule dividers (`---`), excessive blank lines, redundant section headers. Markdown headers provide sufficient hierarchy.
- **Cross-file deduplication**: Content stated identically in multiple files. Define once, cross-reference elsewhere (e.g., file protocol defined in `/team`, agents say "See /team").
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

Before cutting a line, ask: "Would an agent behave differently without this?" If yes — or if you're unsure — keep it.

---

## Engineering Best Practices

PDS encodes two complementary layers of engineering guidance, designed to be MECE (mutually exclusive, collectively exhaustive):

**Principles** (`/ethos`) define *why* — the philosophy that grounds decisions. Understand before acting. Small reversible steps. Tests as specification. Explicit over implicit. Optimize for change. Fail fast. Automation as documentation.

**Techniques** (encoded across skills) define *how* — the concrete methods that implement principles:

| Technique | Skill | Principle it implements |
|-----------|-------|------------------------|
| Hypothesis-driven debugging | `/debug` | Understand before you act |
| git bisect for regression hunting | `/debug` | Automation as documentation |
| Rubber duck protocol | `/debug` | Explicit over implicit |
| TDD (RED/GREEN/REFACTOR) | `/test` | Tests as specification |
| Behavior-based test naming | `/test` | Explicit over implicit |
| Atomic commits | `/commit` | Small, reversible steps |
| Severity-categorized review | `/review` | Fail fast, recover gracefully |
| Rebasing-first merge coordination | `/merge` | Optimize for change |
| Requirement interrogation | `/grill` | Understand before you act |

This separation matters: principles are stable across projects and technologies, while techniques evolve with tooling and practice. An agent grounded in principles makes better judgment calls when no specific technique applies.

---

## Resolved Questions

These questions from v1.0 have been resolved through research and implementation experience:

| Question | Resolution |
|----------|------------|
| **Inter-agent communication** | Supported via SendMessage (direct, broadcast). Orchestrator coordinates through TaskCreate/TaskUpdate task DAGs. Independent execution preferred for simplicity; direct communication available when tasks require it. |
| **Lexicon structure** | Git-backed markdown (version controlled, diffable) + semantic search layer (vector DB). Combines auditability with queryability. |
| **Failure recovery** | Frequent commits + orchestrator checkpoints to manifest file. Worktree itself preserves partial work. |
| **Metrics** | Primary: tokens per task, validation cycles before pass, human intervention rate. Secondary: PRs merged, time to deployment. |
| **Organizational integration** | PR-based workflow is the integration point. Agents produce PRs that flow through existing review processes. No changes to sprint planning or on-call. |

---

## Conclusion

The agentic SDLC is a structural change in development. AI agents operate autonomously within well-defined boundaries. Infrastructure provides those boundaries. Clear interfaces separate humans and agents. Rigorous governance maintains safety.

The path is incremental: foundational skills, supervised use, parallel execution, cloud infrastructure, full autonomy.

The investment is substantial. The return—a step-change in development velocity with maintained quality—justifies it.

This is a starting point. The model evolves with implementation experience and improving AI capabilities. What matters now is to begin.

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
| Agent Runtime | Claude | Underlying model |
| Agent Runtime | MCP servers | Tool integrations |
| Agent Coordination | TeamCreate | Team setup and task list |
| Agent Coordination | TaskCreate/TaskUpdate | Task DAG management |
| Agent Coordination | SendMessage | Inter-agent communication |
| Agent Coordination | Task (worker) | Worker agent spawning |
| Infrastructure | Kubernetes | Cloud orchestration |

---

## Appendix B: Glossary

**Orchestrator**: Primary agent that plans, dispatches workers, and consolidates results. Core tier.

**Researcher**: Agent that gathers context during Phase 1 — querying documentation, searching codebases, mapping dependencies. Core tier.

**Worker**: Agent executing a specific subtask in an isolated worktree. Core tier (N instances per swarm).

**Validator**: Agent responsible for merging branches, running tests, and reporting validation results. Core tier.

**Reviewer**: Agent performing automated pre-review — code quality, security, consistency checks — before human Phase 5 review. Specialist tier.

**Documenter**: Agent updating user-facing documentation when changes warrant it. Specialist tier.

**Scout**: Agent analyzing completed swarms for PDS meta-improvements — workflow optimizations, skill gaps, configuration updates. Specialist tier.

**Auditor**: Agent scanning codebases for tech debt, code smells, and missing tests, filing findings as GitHub issues. Spawned periodically, not per-swarm. Specialist tier.

**Worktree**: Git feature providing independent working directory sharing the repository's object store.

**MCP**: Model Context Protocol—standard for agent interaction with external tools.

**Lexicon**: Persistent repository of engineering knowledge, queryable by agents.

**Acceptance Criteria**: Specific, mechanically verifiable conditions defining task completion.

**Human Gate**: Principle that no agent work reaches production without human approval.

**SendMessage**: Tool for direct and broadcast communication between agents in a team.

**TaskCreate**: Tool for defining work units with dependencies, forming task DAGs.

**TeamCreate**: Tool for establishing an agent team with shared task list and coordination.
