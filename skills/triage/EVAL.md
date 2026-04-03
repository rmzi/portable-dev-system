---
skill: triage
---
# Eval: /pds:triage

## Scenarios

### Scenario: Missing report aborts gracefully
**Setup:** No `~/.claude/usage-data/report.html` exists (rename or delete it).
**Prompt:** `/pds:triage`
**Expected:**
- [ ] Agent checks for report.html existence
- [ ] Agent aborts with clear message: "Run `/insights` first"
- [ ] No facets or session-meta files are read
- [ ] No `gh` commands are executed
**Anti-patterns:**
- [ ] Agent proceeds without report data
- [ ] Agent attempts to generate insights itself

### Scenario: Dry run skips issue creation
**Setup:** Report exists, `gh` is authenticated.
**Prompt:** `/pds:triage --dry-run`
**Expected:**
- [ ] Phases 1-4 complete normally (load, parse, analyze, walk-through)
- [ ] Phase 5 (issue creation) is skipped entirely
- [ ] No `gh issue create` commands are executed
- [ ] `analysis.json` is still written to `~/.config/pds/insights/`
- [ ] Summary notes "dry run — no issues created"
**Anti-patterns:**
- [ ] Agent creates issues despite --dry-run flag
- [ ] Agent skips persistence (Phase 6)

### Scenario: Deduplication flags prior issues
**Setup:** A prior `manifest.json` exists at `~/.config/pds/insights/2026-04-01/manifest.json` with an issue fingerprint matching a proposed issue.
**Prompt:** `/pds:triage`
**Expected:**
- [ ] Agent loads prior manifests in Phase 1
- [ ] During Phase 4/5, duplicate issues are flagged: "Similar issue already created: #N in owner/repo on DATE"
- [ ] Agent asks user whether to skip or create anyway
- [ ] Skipped items appear in manifest under `issues_skipped`
**Anti-patterns:**
- [ ] Agent creates duplicate issues without checking history
- [ ] Agent silently skips without informing user

### Scenario: Worktree paths resolve correctly
**Setup:** Session-meta contains paths like `/Users/rmzi/dev/project/.worktrees/feature-branch/subdir`.
**Prompt:** `/pds:triage`
**Expected:**
- [ ] Agent strips `/.worktrees/feature-branch/subdir` to get `/Users/rmzi/dev/project`
- [ ] Agent resolves git remote from the base path
- [ ] Sessions from different worktrees of the same repo are grouped together
- [ ] Repo summary shows correct session counts
**Anti-patterns:**
- [ ] Agent treats each worktree path as a separate repo
- [ ] Agent fails on worktree paths with deep subdirectories

### Scenario: Section filter limits scope
**Setup:** Report exists with all sections populated.
**Prompt:** `/pds:triage --section friction`
**Expected:**
- [ ] Only the friction section (section-friction) is analyzed in Phase 3
- [ ] Phase 4 walk-through covers only friction items
- [ ] Other sections (features, patterns, horizon) are skipped
- [ ] Summary reflects the limited scope
**Anti-patterns:**
- [ ] Agent processes all sections despite --section flag
- [ ] Agent skips Phase 2 parsing entirely (repo index is still needed)

### Scenario: Observer sessions filtered out
**Setup:** Session-meta includes paths containing `/.claude-mem/observer-sessions`.
**Prompt:** `/pds:triage`
**Expected:**
- [ ] Paths containing `/.claude-mem/` are excluded from repo index
- [ ] Observer sessions do not inflate friction scores or session counts
- [ ] Filtered sessions are not mentioned in the summary
**Anti-patterns:**
- [ ] Observer sessions appear as a "repo" in the analysis
- [ ] Agent attempts `git remote` on non-repo paths

## Baseline

Without the skill, the user would:
1. Run `/insights` and read the HTML report manually
2. Mentally map friction categories to specific repos
3. Manually create GitHub issues one by one
4. Have no deduplication across triage sessions
5. Have no persistent record of what was triaged

The skill automates steps 2-5 and makes step 1 actionable with systematic analysis.
