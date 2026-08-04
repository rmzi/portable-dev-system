---
description: Eval scenarios for /pds:pause skill — verifies correct save-state behavior.
---
# /pause — Eval Scenarios

## Scenario 1: Uncommitted Changes

**Setup:** Working tree has modified/untracked files.

**Invoke:** `/pds:pause "wrapping up auth work"`

**Expected behavior:**
1. `git status` shows changes
2. Relevant files are staged and committed: `wip: pausing session <ISO timestamp>`
3. `pause.json` written with `uncommitted_files > 0` and `note: "wrapping up auth work"`
4. Confirmation message printed

**Anti-pattern:** Changes left unstaged — session state not preserved. Or `git add -A` used — risks committing secrets/artifacts.

---

## Scenario 2: Clean Working Tree

**Setup:** Working tree is clean — nothing to commit.

**Invoke:** `/pds:pause`

**Expected behavior:**
1. `git status` shows clean
2. No commit created
3. `pause.json` written with `uncommitted_files: 0` and auto-generated note from `git log --oneline -3`
4. Confirmation message printed

**Anti-pattern:** Empty commit created on a clean tree — pollutes git history with meaningless entries.

---

## Scenario 3: Active Swarm

**Setup:** `.claude/swarm/phase` exists and contains a phase name.

**Invoke:** `/pds:pause`

**Expected behavior:**
1. `pause.json` written with correct `phase` and `tier` values
2. Suggestion printed to consider shutting down swarm agents
3. No agents force-stopped

**Anti-pattern:** Agents silently killed without warning — could corrupt in-progress work.

---

## Scenario 4: Ticketed Swarm — Pause Note Posted

**Setup:** `.claude/swarm/ticket` contains a numeric issue number (e.g. `42`). Working tree has uncommitted changes.

**Invoke:** `/pds:pause "finished auth, next: tests"`

**Expected behavior:**
1. `pause.json` written as in Scenario 1
2. `gh issue comment 42 --body "..."` is run, including branch, phase, tier, and the note
3. Confirmation message printed

**Anti-pattern:** Comment omitted despite a real ticket number present. Or the pause blocked/failed because `gh` errored (should degrade silently — see Rules).

---

## Scenario 5: No Ticket or Fallback Marker

**Setup:** `.claude/swarm/ticket` is absent, or contains a fallback marker (e.g. `none (no github remote)`).

**Invoke:** `/pds:pause`

**Expected behavior:**
1. `pause.json` written normally
2. No `gh issue comment` call attempted
3. No error surfaced to the user

**Anti-pattern:** Skill errors out or prints a warning about the missing ticket — this is a normal, silent no-op path.
