---
description: Triage insights into actionable GitHub issues across repos. Use after running /insights to convert analysis into tracked work.
---
# /triage — Insights Triage

Reads Claude Code `/insights` output (report + facets + session-meta), analyzes each section systematically, and creates GitHub issues across repos with confirmation at every step.

## Mode

**Plan mode with interactive confirmation.** Enter plan mode (`EnterPlanMode`) before starting. Phases 1-3 are automated data gathering. Phases 4-5 are interactive — the agent proposes, the user confirms. No issues are created without explicit approval.

**Model:** Use Opus for analysis (heavy-tier reasoning). The cross-referencing and issue-grouping logic benefits from maximum capability.

## Prerequisites

- `/insights` has been run (`~/.claude/usage-data/report.html` exists)
- `gh` CLI is authenticated (`gh auth status`)
- Repos referenced in session-meta have git remotes

## Invocation

```
/pds:triage                       # Full triage of latest insights
/pds:triage --section friction    # Triage only the friction section
/pds:triage --repo <name>         # Triage for one repo only
/pds:triage --dry-run             # Analyze and propose but don't create issues
```

## Protocol

### Phase 1: Load

1. Verify insights data exists:
   ```bash
   test -f ~/.claude/usage-data/report.html && echo "report found" || echo "MISSING — run /insights first"
   ls ~/.claude/usage-data/facets/*.json 2>/dev/null | wc -l
   ls ~/.claude/usage-data/session-meta/*.json 2>/dev/null | wc -l
   ```
   If report is missing, abort: "Run `/insights` first to generate the report."

2. Check report freshness:
   ```bash
   stat -f '%Sm' -t '%Y-%m-%d' ~/.claude/usage-data/report.html
   ```
   If older than 24 hours, warn: "Report is N days old. Consider re-running `/insights` for fresh data."

3. Check `gh` authentication:
   ```bash
   gh auth status 2>&1 | head -3
   ```
   If not authenticated, abort: "Run `gh auth login` first."

4. Load deduplication history:
   ```bash
   cat ~/.config/pds/insights/*/manifest.json 2>/dev/null
   ```
   Build fingerprint set from all prior `issues_created` entries.

### Phase 2: Parse

1. **Read report.html.** Extract content from each section by HTML id:

   | Section ID | Name | Actionability | Issue Category |
   |------------|------|---------------|----------------|
   | `section-work` | What You Work On | Context | *(informational)* |
   | `section-usage` | How You Use Claude Code | Medium | `workflow-improvement` |
   | `section-wins` | Impressive Things You Did | Context | *(reinforcement)* |
   | `section-friction` | Where Things Go Wrong | **High** | `friction`, `dx-improvement` |
   | `section-features` | Existing CC Features to Try | **High** | `claude-md-update`, `feature-gap` |
   | `section-patterns` | New Ways to Use Claude Code | Medium | `workflow-improvement` |
   | `section-horizon` | On the Horizon | Medium | `enhancement` |

2. **Build repo index.** Read session-meta files and build mapping:
   ```
   project_path → { repo: "owner/name", sessions: N, friction_score: N }
   ```
   
   Resolution rules:
   - Strip `/.worktrees/<anything>` suffix (including deeper subdirs) to get base repo path
   - Run `git -C <path> remote get-url origin 2>/dev/null` for each unique base path
   - Parse `owner/repo` from remote URL (handles `git@` and `https://` formats)
   - Cache the mapping — do not re-resolve within the same run
   
   Filter out:
   - Observer sessions (`/.claude-mem/` in path)
   - Bare directories (no `.git`)
   - External volumes (`/Volumes/`)
   - Repos with fewer than 2 sessions

3. **Join facets to repos.** For each facet, look up `session_id` in session-meta to get the repo. Aggregate per repo:
   - Total friction score (sum of `friction_counts` values)
   - Top friction types
   - Outcome distribution (fully/mostly/partially/not achieved)
   - Goal categories

4. **Present summary to user:**
   ```
   Insights loaded: N analyzed sessions across M repos
   
   Top repos by friction:
   1. owner/repo-a  (43 sessions, friction: 39)
   2. owner/repo-b  (31 sessions, friction: 42)
   3. owner/repo-c  (22 sessions, friction: 21)
   
   Report sections: 7 (3 high-actionability, 2 medium, 2 context-only)
   Prior triage runs: K (J issues already created)
   ```

### Phase 3: Analyze

For each actionable section (friction, features, patterns, horizon), cross-reference with per-repo facet aggregation:

1. **Friction section**: Match each friction category to repos where it occurs most. Use `friction_detail` from facets as evidence. Propose groupings — multiple friction points for same root cause become one issue.

2. **Features section**: Map each CLAUDE.md suggestion and feature recommendation to the repos where the friction was observed. Group CLAUDE.md additions into a single checklist issue per repo.

3. **Patterns section**: Map each workflow pattern to repos/sessions that would benefit.

4. **Horizon section**: Map capability suggestions to repos where they'd have highest impact. Label as `enhancement`.

### Phase 4: Section Walk-Through (Interactive)

For each actionable section, present findings and ask for confirmation. **One section at a time, no skipping.**

**For each section:**

1. **Present analysis** with evidence:
   ```
   ## Friction: Wrong Approach Requiring Repeated Redirection
   
   Evidence: 38 occurrences across sessions
   Top repos: owner/repo-a (12), owner/repo-b (8), owner/repo-c (6)
   
   Examples from your sessions:
   - "Claude tried to instantiate providers hitting AWS..."
   - "Claude started executing code instead of working in plan mode..."
   
   Proposed action: Create CLAUDE.md rules in affected repos to constrain behavior.
   ```

2. **Ask the user:**
   - "Should this become an issue? (yes / no / modify)"
   - "Which repos? (all affected / specific subset)"
   - "What priority? (high / medium / low)"

3. **Wait for response before advancing to next item.**

### Phase 5: Issue Creation (Interactive)

After all sections are triaged, present the consolidated issue list grouped by repo:

```
## Proposed Issues

### owner/repo-a
1. [friction] "Add pattern-mirroring constraint to CLAUDE.md" — high
2. [friction] "Add environment preflight check for worktrees" — medium
3. [feature-gap] "Update CLAUDE.md with async job polling rules" — high

### owner/repo-b
4. [workflow] "Add plan-mode enforcement rule" — medium

Create all? (yes / review each / skip)
```

**For each confirmed issue:**

1. Pre-create labels if needed:
   ```bash
   gh label create "insights-triage" --repo owner/repo --color "7057ff" --force 2>/dev/null
   gh label create "<category>" --repo owner/repo --color "<color>" --force 2>/dev/null
   ```

2. Create issue:
   ```bash
   gh issue create --repo "owner/repo" --title "<title>" \
     --label "insights-triage,<category>" \
     --body "$(cat <<'EOF'
   ## Source
   Generated by `/pds:triage` from Claude Code `/insights` (DATE).
   
   ## Category
   CATEGORY_NAME
   
   ## Evidence
   - FRICTION_DETAIL or examples from report
   - N sessions affected, friction score: M
   
   ## Suggested Action
   ACTION_DESCRIPTION
   
   ---
   *Auto-generated by [PDS](https://github.com/rmzi/portable-dev-system) `/triage`*
   EOF
   )"
   ```

**Labels:**
| Label | Color | Applied When |
|-------|-------|-------------|
| `insights-triage` | `#7057ff` | Always (identifies PDS-generated issues) |
| `friction` | `#d73a4a` | From friction section |
| `dx-improvement` | `#0075ca` | Developer experience improvements |
| `claude-md-update` | `#e4e669` | Needs CLAUDE.md changes |
| `workflow-improvement` | `#0e8a16` | Process/workflow changes |
| `enhancement` | `#a2eeef` | Future capability items |

**If `--dry-run` was passed:** Complete Phases 1-4 but skip Phase 5. Still save `analysis.json` in Phase 6.

### Phase 6: Persist

1. Create persistence directory:
   ```bash
   TRIAGE_DIR=~/.config/pds/insights/$(date +%Y-%m-%d)
   mkdir -p "$TRIAGE_DIR"
   ```
   If directory exists (same-day re-run), append timestamp: `YYYY-MM-DDTHHMMSS`.

2. Copy report snapshot:
   ```bash
   cp ~/.claude/usage-data/report.html "$TRIAGE_DIR/report.html"
   ```

3. Write `analysis.json` — the aggregated per-repo data from Phase 3.

4. Write `manifest.json` — issue creation record for deduplication:
   ```json
   {
     "run_date": "ISO-8601",
     "report_hash": "sha256 of report.html",
     "issues_created": [
       {
         "repo": "owner/repo",
         "number": 42,
         "title": "...",
         "category": "friction",
         "insight_sections": ["section-friction"],
         "fingerprint": "sha256(title+category+repo)"
       }
     ],
     "issues_skipped": [],
     "repos_analyzed": 15,
     "session_count": 214
   }
   ```

5. Print summary:
   ```
   Triage complete.
   - N issues created across M repos
   - K items skipped (already tracked or deferred)
   - Saved to ~/.config/pds/insights/YYYY-MM-DD/
   ```

## Rules

- **Never create issues without user confirmation.** Every issue requires explicit yes.
- **Never modify CLAUDE.md directly.** Propose changes as issues; the user applies them.
- **Deduplicate aggressively.** Check prior manifests AND `gh issue list --search` before proposing.
- **One section at a time.** Walk through sequentially — do not batch-present all sections.
- **Filter noise.** Exclude observer sessions, bare directories, repos with <2 sessions.
- **Respect `--dry-run`.** Complete analysis but skip issue creation. Still persist analysis.

## Files Read

| File | Purpose |
|------|---------|
| `~/.claude/usage-data/report.html` | Insights report (7 sections) |
| `~/.claude/usage-data/facets/*.json` | Per-session analysis (goals, friction, outcomes) |
| `~/.claude/usage-data/session-meta/*.json` | Session metadata (project_path, tools, languages) |
| `~/.config/pds/insights/*/manifest.json` | Prior triage manifests for deduplication |

## Files Written

| File | Purpose |
|------|---------|
| `~/.config/pds/insights/YYYY-MM-DD/report.html` | Report snapshot |
| `~/.config/pds/insights/YYYY-MM-DD/analysis.json` | Aggregated per-repo analysis |
| `~/.config/pds/insights/YYYY-MM-DD/manifest.json` | Issue creation record |

## See Also

- `/pds:grill` — The interrogation pattern this skill adapts
- `/pds:bugfix` — For friction items that are actual bugs
