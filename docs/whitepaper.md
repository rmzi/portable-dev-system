# Agentic SDLC: A Technical Whitepaper

**Version 1.2 | January 2025**

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

The orchestrator may spawn research subagents to gather context: querying documentation, searching codebases, accessing external APIs. The orchestrator synthesizes this research and produces a structured task specification.

The critical output is explicit acceptance criteria—unambiguous and mechanically verifiable. "The API should be fast" becomes "p99 latency for /users under 200ms with 1000 concurrent connections."

### Phase 2: Task Decomposition and Dispatch

The orchestrator decomposes the plan into discrete work units for parallel execution. Each unit becomes a task assigned to a worker agent.

The orchestrator creates isolated environments using git worktrees—complete, independent working directories sharing the underlying git object store. Each worker operates on its own branch, in its own directory, with no merge conflicts during execution.

The orchestrator records session metadata: which agents work on which worktrees, which branches they correspond to, expected deliverables. This enables monitoring and recovery.

### Phase 3: Parallel Execution

Workers execute independently. They access the codebase within their worktree, read documentation, and write code.

**Workers do not communicate with each other.** This is intentional. Inter-agent communication introduces coordination overhead and deadlocks. Workers assume their task is self-contained. If coordination is needed, the task was decomposed incorrectly.

Each worker produces a result artifact: code changes, summary, issues encountered. Workers commit to their branches but do not merge.

### Phase 4: Validation

A validator agent examines all worker output. The validator operates in its own worktree, merging worker branches and running comprehensive tests.

Responsibilities: writing tests based on acceptance criteria, running the existing test suite, performing static analysis, checking for defects. The validator does not fix issues—it produces a structured report identifying failures, localizing them, and suggesting remediation.

If validation fails, the report flows to the orchestrator, which dispatches targeted fix requests. This cycle continues until validation passes or human intervention is required.

### Phase 5: Consolidation and Human Review

The orchestrator consolidates worker branches into a single pull request, rebasing or squashing as needed for clean history.

The developer reviews with full context: requirements, plan, validation results, issues encountered. The developer can request changes (flowing back through the orchestrator) or approve for merge.

Agents may participate in PR discussion—performing additional checks, raising concerns, asking questions. The developer arbitrates and makes final decisions.

### Phase 6: Knowledge Capture

Before merging, the orchestrator reviews what happened: patterns emerged, architectural decisions made, unexpected challenges.

This knowledge flows into the lexicon—a persistent repository of engineering knowledge spanning tasks, repositories, and team members. The lexicon captures lessons learned, gotchas, and patterns.

Agents query the lexicon during future planning and execution, avoiding repeated mistakes and building on proven patterns.

---

## Core Technical Concepts

### Git Worktrees

A worktree is an additional working directory associated with a repository. Unlike a clone, it shares the object store (commits, blobs, trees) with the main repository. Creation is nearly instantaneous with minimal disk overhead.

```bash
git worktree add ../task-123-worker-1 -b task-123/worker-1
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

**Docker Sandbox Architecture** (Docker Desktop 4.58+):

Modern container isolation uses MicroVM architecture—hypervisor-level isolation, not just namespaces:

- **Private Docker daemon** per sandbox (no shared socket)
- **Network filtering proxy** at `host.docker.internal:3128` with allowlist-based access
- **Filesystem isolation** limited to workspace directory
- **Resource limits**: 1 CPU, 2GB RAM per container (configurable)
- **No host credential access** by default

This provides defense-in-depth: even if an agent escapes the container, the MicroVM boundary contains the blast radius.

**Permission Tiers**:

| Agent Type | Network | Filesystem | Credentials |
|------------|---------|------------|-------------|
| Worker | None | Own worktree only | None |
| Validator | Test databases | Own worktree + read others | Test DB credentials |
| Orchestrator | External APIs (Jira, Slack) | All worktrees | API tokens (no prod) |

### Execution Environments

Agents can execute locally or in the cloud. The `ExecutionEnvironment` abstraction allows the same agent specification to run in either context:

```rust
pub trait ExecutionEnvironment: Send + Sync {
    async fn setup(&self, task_id: &str, branch: &str) -> Result<()>;
    async fn run_agent(&self, spec: &AgentSpec) -> Result<TaskResult>;
    async fn get_files(&self, path: &str) -> Result<Vec<u8>>;
    async fn put_files(&self, path: &str, content: &[u8]) -> Result<()>;
    async fn cleanup(&self) -> Result<()>;
}
```

**Local (Docker Sandbox)**: Uses Docker Compose with MicroVM isolation. The worktree is mounted directly—no file sync overhead. Best for active development and fast iteration.

**Cloud (E2B)**: Uses E2B's cloud sandbox service. Files are synced to/from remote sandboxes. Best for overnight execution, CI integration, and scaling beyond local resources.

Both implementations provide identical isolation guarantees and MCP server access. The choice is operational, not architectural.

See [Execution Environments](./execution-environments.md) for implementation details and cost analysis.

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

The primary orchestration interface is the terminal. Graphical IDEs assume one project, one set of files, one debug session. Agentic workflows involve multiple worktrees and rapid context switching.

**Core tools**:
- **tmux**: Terminal multiplexing, persistent sessions
- **yazi** or similar: Terminal file manager for worktree navigation
- **neovim + telescope**: Editor with multi-worktree support

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

## Resolved Questions

These questions from v1.0 have been resolved through research and implementation experience:

| Question | Resolution |
|----------|------------|
| **Inter-agent communication** | Not needed. Orchestrator coordinates all work. File-based handoff via worktree if absolutely necessary. If workers need to communicate, decompose differently. |
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
| Terminal | tmux | Session management |
| Terminal | yazi | File navigation |
| Terminal | neovim + telescope | Multi-worktree editing |
| Version Control | git worktree | Core functionality |
| Version Control | lazygit | Terminal UI |
| Dependencies | uv | Python (fast) |
| Dependencies | pnpm | Node.js (efficient) |
| Agent Runtime | Claude | Underlying model |
| Agent Runtime | MCP servers | Tool integrations |
| Agent Coordination | Subtask | Parallel worktree execution |
| Agent Coordination | Ralph Wiggum | Persistent autonomous loops |
| Infrastructure | Docker Sandbox | Local isolation |
| Infrastructure | Kubernetes | Cloud orchestration |
| Execution | LocalDockerEnvironment | Local agent execution |
| Execution | E2bEnvironment | Cloud agent execution (future) |
| Configuration | data-sources.yaml | MCP and credential registry |

---

## Appendix B: Glossary

**Orchestrator**: Primary agent that plans, dispatches workers, and consolidates results.

**Worker**: Agent executing a specific subtask in an isolated worktree.

**Validator**: Agent responsible for testing and reporting validation results.

**Worktree**: Git feature providing independent working directory sharing the repository's object store.

**MCP**: Model Context Protocol—standard for agent interaction with external tools.

**Lexicon**: Persistent repository of engineering knowledge, queryable by agents.

**Acceptance Criteria**: Specific, mechanically verifiable conditions defining task completion.

**Human Gate**: Principle that no agent work reaches production without human approval.

**Docker Sandbox**: MicroVM-based isolation environment for agent execution.

**Subtask**: Tool for spawning parallel subagents in isolated git worktrees with minimal context.

**Ralph Wiggum**: Technique for persistent autonomous agent loops where progress lives in files, not context. Named after the Simpsons character. See [Agent Tooling](./agent-tooling.md).
