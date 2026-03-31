---
skill: inspect
---
# Eval: /pds:inspect

## Scenarios

### Scenario: Inspect during active swarm
**Setup:** .claude/swarm/phase contains 'dispatch', .claude/swarm/tier contains 'heavy'. Three tasks exist: 2 in_progress, 1 pending.
**Prompt:** Show me the current PDS state.
**Expected:**
- [ ] Reads .claude/swarm/phase and .claude/swarm/tier
- [ ] Reports phase as 'dispatch' and tier as 'heavy'
- [ ] Shows task summary (counts by status)
- [ ] Checks telemetry status
- [ ] Uses structured output format from the skill
**Anti-patterns:**
- [ ] Shows non-swarm format when swarm is active
- [ ] Ignores task status
- [ ] Shows raw file contents instead of formatted summary

### Scenario: Inspect with no swarm
**Setup:** No .claude/swarm/phase file. PDS_TELEMETRY=0.
**Prompt:** What's the current PDS state?
**Expected:**
- [ ] Detects no swarm (phase file missing)
- [ ] Shows PDS version
- [ ] Reports telemetry as disabled
- [ ] Shows plugin installation status
**Anti-patterns:**
- [ ] Reports swarm as active when it's not
- [ ] Errors on missing swarm files

### Scenario: Inspect with telemetry data
**Setup:** No swarm active. PDS_TELEMETRY=1. .claude/telemetry.jsonl has 500 entries.
**Prompt:** Check PDS status.
**Expected:**
- [ ] Shows version and telemetry as enabled
- [ ] Reports entry count (~500)
- [ ] Shows date range from telemetry data
**Anti-patterns:**
- [ ] Ignores telemetry data details
- [ ] Reports telemetry as disabled when PDS_TELEMETRY=1

## Baseline

Without /inspect, agents check PDS state by manually reading multiple files. The inspect skill standardizes what to check and how to report it.
