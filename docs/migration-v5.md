# Migration Guide: PDS v4.x → v5.0.0

PDS v5 has no file-layout or install-path changes — if you haven't customized PDS's agents/skills locally, there is nothing to do. The break is internal: how orchestrators spawn and coordinate agents, following Claude Code's own removal of `TeamCreate`/`TeamDelete` at v2.1.178.

## What Changed

| v4.x | v5.0 |
|------|------|
| Orchestrator calls `TeamCreate`/`TeamDelete` explicitly | Team forms implicitly on first spawn, dissolves at session end — no explicit calls |
| Workers spawned as named teammates: `Task(worker, name="worker-auth", ...)` | Workers spawned unnamed, `agent_id` captured from the return value: `worker_1 = Task(worker, ...)` |
| Phase 6 teardown gated on a `PreToolUse: TeamDelete` hook (dead — nothing to trigger on since v2.1.178) | Phase 6 teardown gated on an orchestrator-scoped `Stop` hook (`orchestrator-teardown-gate.sh`) — see `docs/adr/0007` |
| Agent-addressed `SendMessage` as the default worker-coordination pattern | Task-mediated coordination (contract in the task description, workers self-claim via `TaskList`) as the default; `SendMessage` for cases that need direct addressing |
| Issue tickets: ad-hoc body, PR bodies re-paste issue content | Evolving-body 7-section issue format + slim PR bodies, opt-in via `PDS_EVOLVING_BODY=1` — see `docs/adr/0009` |

## Who needs to do anything

- **Using the plugin as-installed, no local forks of `agents/orchestrator.md` or `skills/swarm/SKILL.md`**: nothing to do. `pds sync` / a normal plugin update picks up the new spawn pattern automatically.
- **Forked or locally-edited `agents/orchestrator.md`, `skills/swarm/SKILL.md`, or `skills/team/SKILL.md`**: any spawn example using `name="worker-..."` will fail with "the team roster is flat" — a teammate cannot spawn further named teammates. Update spawn calls to omit `name=` and capture `agent_id` from the return value instead (see `agents/orchestrator.md`'s "Dispatch Workflow" section for the current pattern).
- **Relying on the old `TeamDelete`-triggered teardown gate for custom tooling**: that `PreToolUse` trigger is gone. The equivalent check now runs as a `Stop` hook on the orchestrator agent — if you built anything against the old hook wiring, retarget it to `Stop` (see `docs/adr/0007`).
- **Want the new evolving-body issue format**: opt in with `PDS_EVOLVING_BODY=1`. Off by default in v5.0.0 — existing `/pds:ticket` behavior is unchanged unless you set the flag.

## Not part of this migration

- `/pds:resume`, the `pds-active-swarm` label, and ticket-based task mobility (shipped in v4.24.0, not new in v5.0.0)
- Issue #161's whitepaper-first rebuild — remains dormant, not addressed by this release
- Issue #174 (sandbox git/gh network gap) — remains open, platform-level, not something PDS can resolve
