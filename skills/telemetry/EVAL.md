---
skill: telemetry
---
# Eval: /pds:telemetry

## Scenarios

### Scenario: Enable/disable toggle
**Setup:** PDS_TELEMETRY is unset or 0 in settings. No telemetry file exists.
**Prompt:** Enable telemetry, then disable it.
**Expected:**
- [ ] Reads current settings before modifying
- [ ] Adds PDS_TELEMETRY=1 to env in .claude/settings.json or .claude/settings.local.json
- [ ] Confirms telemetry is enabled with specific message
- [ ] When disabling, sets PDS_TELEMETRY=0 (does not delete the key)
- [ ] Does not delete existing telemetry data when disabling
**Anti-patterns:**
- [ ] Modifies settings without reading first
- [ ] Deletes telemetry data on disable
- [ ] Uses shell commands instead of settings.json modification

### Scenario: View report with data
**Setup:** .claude/telemetry.jsonl exists with 50+ entries covering skill_invoked, agent_spawned, and file_modified events.
**Prompt:** Show me the telemetry report.
**Expected:**
- [ ] Calls or references scripts/telemetry-summary.sh
- [ ] Shows top skills by invocation count
- [ ] Shows top agents by spawn count
- [ ] Lists zero-usage skills (skills in skills/ with no telemetry entries)
- [ ] Shows date range of telemetry data
**Anti-patterns:**
- [ ] Manually parses JSONL instead of using the summary script
- [ ] Shows raw JSONL data without summarization
- [ ] Ignores zero-usage skills

### Scenario: Rotate with large file
**Setup:** .claude/telemetry.jsonl has 15000 lines.
**Prompt:** Rotate the telemetry log.
**Expected:**
- [ ] Checks line count before rotating
- [ ] Archives to .claude/telemetry-{date}.jsonl.bak
- [ ] Keeps last 10000 lines in new .claude/telemetry.jsonl
- [ ] Reports number of archived entries
**Anti-patterns:**
- [ ] Deletes old entries without archiving
- [ ] Rotates when under 10000 lines
- [ ] Loses data during rotation

### Scenario: View with empty/missing file
**Setup:** No .claude/telemetry.jsonl file exists.
**Prompt:** Show me the telemetry report.
**Expected:**
- [ ] Detects missing or empty file gracefully
- [ ] Shows helpful message about enabling telemetry
- [ ] Does not error or show stack traces
**Anti-patterns:**
- [ ] Crashes or shows error on missing file
- [ ] Shows empty report without guidance

## Baseline

Without /telemetry, agents have no standard way to manage PDS usage tracking. They might manually grep JSONL files or modify settings inconsistently.
