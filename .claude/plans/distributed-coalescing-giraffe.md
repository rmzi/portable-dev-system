# Plan: Context Protocol, Headless Agents, and Efficiency Measurement

## Context

PDS swarms have three structural gaps identified through source analysis and community research:

1. **Context loss on agent spawn** — Workers start fresh, losing orchestrator's plan/research/decisions. The community has 10+ issues requesting fork+specialization (anthropics/claude-code#24316, #16153, #4908). Source analysis confirms fork and agent-type are separate code paths — no hidden combination exists.

2. **No headless agent story** — Background/scheduled agents (preflight, instinct capture, cleanup) don't exist despite Claude Code providing `CronCreate`, `RemoteTrigger`, and `run_in_background`. The orchestrator does work that could be offloaded.

3. **No efficiency measurement** — PDS has no way to measure or visualize waste in the agentic workflow. Value Stream Mapping (Ohno, 1988) and XP's "eliminate waste" principle (Beck, 2004; Poppendieck, 2003) provide the framework but PDS doesn't implement it.

## Approach

### 1. Whitepaper Updates (docs/whitepaper.md)

**A. Context Gap — Known Gap + Path Forward**
- Replace hand-wavy "complementary" framing at line 249 with proper Known Gap
- Document the three-system disconnect (subagents vs teams vs fork) with community evidence
- Document dual-dispatch model: orchestrator chooses fork (quick/invisible) vs teammate (long-running/visible) at runtime
- Document structured context protocol (`.claude/swarm/context.md`)

**B. New Section: "Efficiency Measurement"**
- Ground in Value Stream Mapping (Toyota Production System, Ohno 1988)
- Define seven wastes mapped to agentic SDLC (waiting, transport/context loss, over-processing, defects, inventory, motion, overproduction)
- Define efficiency chart: binary value signal over time per agent, identify waste gaps between events
- Cite XP (Beck 2004), Lean Software Development (Poppendieck 2003)
- Connect to PDS telemetry as the measurement mechanism
- Add references to Appendix C

**C. Headless Agents**
- New subsection under Core Technical Concepts documenting headless dispatch mode
- Three-mode dispatch table: team teammate vs fork subagent vs headless/triggered
- Use cases: preflight, instinct capture, telemetry analysis, cleanup, scheduled audits
- What's safe from source analysis: CronCreate, RemoteTrigger, run_in_background, SessionStart/Stop hooks

**D. Adoption Path Phase 3 Update**
- Headless agents make Phase 3 partially achievable today (scheduled local agents, not just cloud)

### 2. Swarm Skill Update (skills/swarm/SKILL.md)

- Add context protocol to Phase 2: orchestrator writes `.claude/swarm/context.md`
- Add dual-dispatch guidance to Phase 3: when to fork vs spawn teammate
- Add efficiency measurement to Phase 6: scout calculates efficiency ratio from telemetry timestamps

### 3. Agent Updates

- `agents/orchestrator.md` — Add dual-dispatch decision guidance, context file generation
- `agents/worker.md` — Add "read `.claude/swarm/context.md` first" to init
- `agents/shared-rules.md` — Add context file reading to shared init, add efficiency event logging
- `agents/scout.md` — Add efficiency analysis to Phase 6 duties

### 4. Telemetry Expansion

- Update `hooks/scripts/telemetry-log.sh` or equivalent to timestamp phase transitions
- Events to capture: grill_start, grill_end, plan_approved, worker_spawn, worker_first_commit, worker_complete, validation_start, validation_end, review_start, review_end, pr_created
- Each event: `{"event": "...", "timestamp": "...", "agent": "...", "phase": "..."}`

### 5. Efficiency Visualization

- New `scripts/efficiency-chart.sh` — reads telemetry.jsonl, produces ASCII efficiency chart
- Shows per-agent value-creating vs idle time
- Calculates efficiency ratio: η = Σ(value time) / Σ(total time)
- Identifies top waste points with bookending events

### 6. New Skill: /pds:dispatch (or headless)

- Skill for kicking off headless/background agents
- Use cases: preflight at session start, instinct capture post-swarm, scheduled audits
- Documents when to use headless vs interactive
- Wraps CronCreate/RemoteTrigger/run_in_background

## Critical Files

| File | Action |
|------|--------|
| `docs/whitepaper.md` | Add context gap, headless agents, efficiency measurement sections |
| `skills/swarm/SKILL.md` | Context protocol, dual-dispatch, efficiency measurement |
| `agents/orchestrator.md` | Dual-dispatch guidance, context file generation |
| `agents/worker.md` | Context file reading on init |
| `agents/shared-rules.md` | Context file reading, efficiency event logging |
| `agents/scout.md` | Efficiency analysis in Phase 6 |
| `skills/dispatch/SKILL.md` | NEW — headless agent dispatch skill |
| `scripts/efficiency-chart.sh` | NEW — telemetry visualization |
| `CHANGELOG.md` | New entry |
| `VERSION` | Bump |

## New References (for Appendix C)

- Ohno, T. (1988). *Toyota Production System: Beyond Large-Scale Production.* Productivity Press. — Value stream mapping, seven wastes (muda), continuous flow
- Beck, K. (2004). *Extreme Programming Explained: Embrace Change.* 2nd ed. Addison-Wesley. — Feedback loops, eliminate waste, simplicity, sustainable pace
- Poppendieck, M. & T. (2003). *Lean Software Development: An Agile Toolkit.* Addison-Wesley. — Bridges TPS to software: eliminate waste, amplify learning, deliver fast

## Verification

1. `grep -c "Value Stream Mapping" docs/whitepaper.md` returns ≥1
2. `grep -c "Known gap" docs/whitepaper.md` returns ≥8 (6 phases + 1 hook + 1 context)
3. `grep -c "efficiency" docs/whitepaper.md` returns ≥3
4. `ls skills/dispatch/SKILL.md` exists
5. `ls scripts/efficiency-chart.sh` exists
6. `grep "context.md" skills/swarm/SKILL.md` returns ≥1
7. `grep "context.md" agents/shared-rules.md` returns ≥1
8. `grep "Ohno" docs/whitepaper.md` returns ≥1
9. All 3 new references appear in Appendix C
10. No code files modified (only docs, skills, agents, scripts)
