# The Agentic SDLC: A Proposal

**Version 1.2 | February 2026**

---

## The Thesis

Software development is approaching an inflection point. AI agents have become capable enough to operate autonomously within well-defined boundaries—planning work, writing code, running tests, and iterating on failures. The question is no longer whether agents can contribute meaningfully, but how we structure our development process to harness this capability safely and effectively.

The Agentic SDLC is a model where AI agents operate as autonomous collaborators, not sophisticated autocomplete. A single engineer orchestrates multiple agents working in parallel, each in isolated environments, producing work that flows through automated validation before human review. The human remains the architect and final authority. The agents become a scalable workforce.

---

## The Problem

Current development workflows, even with AI assistance, hit fundamental limits:

- **Human attention is the bottleneck.** When AI generates code faster than humans can review it, cognitive bandwidth—not typing speed—becomes the constraint.

- **Context switching destroys productivity.** Supervising one agent while thinking about another fragments attention. The cost compounds throughout the day.

- **Idle time accumulates.** When the developer leaves, work stops. When CI runs, work stops. These gaps represent unrealized capacity.

- **The feedback loop stays slow.** Write-test-fix-test still requires human presence at each iteration. An agent that could autonomously iterate would compress this cycle dramatically.

---

## The Model

The Agentic SDLC consists of six phases. Human involvement concentrates at phase boundaries, not within them. Agents execute in isolated environments—locally via Docker during development, or in cloud sandboxes (E2B) for overnight and production workloads.

```
┌─────────────────────────────────────────────────────────────────┐
│  1. PLANNING          Human + Orchestrator refine requirements  │
│         ↓                                                       │
│  2. DECOMPOSITION     Orchestrator splits work, creates         │
│         ↓             isolated worktrees for each task          │
│         ↓                                                       │
│  ┌──────┴──────┐                                                │
│  ↓      ↓      ↓                                                │
│  3. EXECUTION         Workers execute in parallel               │
│  ↓      ↓      ↓      (no inter-agent communication)            │
│  └──────┬──────┘                                                │
│         ↓                                                       │
│  4. VALIDATION        Validator merges, tests, reports          │
│         ↓             (loops back to workers if needed)         │
│         ↓                                                       │
│  5. CONSOLIDATION     Orchestrator creates PR for human review  │
│         ↓                                                       │
│  6. KNOWLEDGE         Lessons captured for future tasks         │
└─────────────────────────────────────────────────────────────────┘
```

---

## Core Principles

**The Human Gate**
No agent-produced change reaches production without explicit human approval. Agents write code, run tests, create pull requests. They cannot merge, deploy, or affect users. This is non-negotiable.

**Isolation by Default**
Agents operate in sandboxed environments with minimal permissions. Network access is restricted. Filesystem access is limited to the task's worktree. Credentials are scoped to role. A misbehaving agent's blast radius is contained.

**Parallel by Design**
Work is decomposed into independent units that execute concurrently. Workers do not communicate with each other—if they need to, the task was decomposed incorrectly. The orchestrator handles all coordination.

**Knowledge Compounds**
Every task contributes to a persistent knowledge base. Agents query this knowledge when planning and executing. The system learns from experience, avoiding repeated mistakes and building on proven patterns.

---

## The Adoption Path

| Phase | Focus | Outcome |
|-------|-------|---------|
| **Foundation** | Terminal fluency, git worktrees, environment setup | Engineers can navigate multi-worktree workflows |
| **Supervised Single-Agent** | One agent, active human oversight | Intuition for effective prompts and failure modes |
| **Multi-Agent Local** | Parallel workers on local machine | Task decomposition skills, resource management |
| **Cloud Infrastructure** | Agents run in isolated pods, overnight execution | Scalable autonomous development with governance |

---

## What This Enables

**Amplified capacity without proportional headcount.** One engineer orchestrating five agents produces more than one engineer alone—without the communication overhead of five humans.

**Continuous progress.** Agents work while you sleep, while you're in meetings, while you wait for review. Idle time becomes productive time.

**Higher-leverage human work.** Engineers focus on architecture, design, and review—the decisions that matter most. Agents handle the execution.

---

## Next Steps

1. **Read the whitepaper** for technical depth on isolation, tooling, and governance.
2. **Review the tooling guide** for [Subtask and Ralph Wiggum integration](./agent-tooling.md).
3. **Pilot with a small team** using the phased adoption path.
4. **Iterate on the model** based on real experience—this is a starting point, not a final answer.

The infrastructure for this future exists today. The question is whether we'll build the processes and discipline to use it responsibly.

---

*This proposal defines the what and why. The accompanying [whitepaper](./whitepaper.md) provides the how.*
