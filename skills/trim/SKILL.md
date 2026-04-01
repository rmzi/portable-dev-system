---
description: Maintaining context efficiency of PDS artifacts. Use when skills or agents grow beyond baseline, or during periodic context audits.
---
# /trim — Context Efficiency Maintenance

Keep PDS artifacts lean. Every line in `.claude/` costs context tokens at session start.

## Mode

**Always run trim as a plan with Q&A.** Before starting, enter plan mode (`EnterPlanMode`). Trim is a collaborative audit — the agent presents findings, the human approves or rejects each proposed change. No edits until the human confirms.

**Format:** For each step, the agent:
1. Presents its analysis with specific findings
2. Proposes concrete changes (with before/after examples)
3. Waits for the human's response before advancing
4. Only applies approved changes after the full walkthrough

Do not skip steps or combine them. Do not edit files without explicit human approval.

## Invocation

```
/trim              # Audit all skills + agents
/trim [file]       # Audit a specific file
```

## Protocol

### 1. Inventory and Measure

```
Bash("wc -l skills/*/SKILL.md agents/*.md | sort -rn")
```

Present:
- Total line count vs. baseline (~3,180 as of v5.0)
- Top 5 largest files
- Files that grew since last baseline

> "Current total: [N] lines (baseline: ~3,180). Here are the largest files: [table]. Does anything look unexpectedly large?"

### 2. Duplication Scan

Search for content that appears in multiple files:
- Repeated checklists, tables, or procedures
- Copy-pasted examples
- Concepts explained in more than one skill

Present each duplicate with the two source files and proposed resolution (which file keeps it, which gets `See /skillname`).

> "I found [N] duplications: [list with file pairs]. Here's my proposed canonical source for each. Agree, or should a different file own it?"

### 3. Style Violations

Scan against the style rules and report violations:

| Rule | Description |
|------|-------------|
| Structure | Keep frontmatter, titles, invocation blocks, checklists, tables, templates |
| Prose | Terse imperative. Cut filler. Active voice. One idea per sentence |
| Quotes | Max 1 per file |
| Code blocks | Max 10 lines each |
| Cross-refs | `See /skillname` instead of duplicating |
| LLM-known | Don't explain git, markdown, standard tooling. Keep multi-step sequences where skipping a step causes failure |
| No hedging | Drop "It's important to...", "Remember that...", "Note:" |

Present violations grouped by file with proposed rewrites.

> "Found [N] style issues across [M] files. Here are the proposed changes — which should I apply?"

### 4. Cross-Reference Validation

Check that:
- Every `See /skillname` points to a real skill in `skills/`
- `CLAUDE.md` skills table matches actual `skills/` directory contents
- No broken frontmatter or invocation blocks

Present any mismatches.

> "Cross-reference check: [N findings]. Here are the mismatches — should I fix these?"

### 5. Proposed Change Summary

Synthesize all approved changes into a summary before applying:
- Files to edit (with specific line ranges)
- Expected line count after changes
- Content being removed (bullet list)
- Content being moved (from → to)

> "Here's the full change plan: [summary]. Ready to apply, or adjustments needed?"

### 6. Apply

Only after human confirms step 5:
- Apply approved edits
- Update baseline in this file if total changed significantly
- Run validation checklist

## Validation Checklist

- [ ] Total line count reduced (or justified if not)
- [ ] Fidelity: spot-check 3 skills — do they still convey the same workflow?
- [ ] Cross-references: every `See /skillname` points to a real skill
- [ ] `CLAUDE.md` skills table matches actual plugin `skills/` contents
- [ ] No broken frontmatter or invocation blocks

## Baseline

| Version | Lines | Commit | Notes |
|---------|-------|--------|-------|
| v4.3 (initial) | ~1,442 | `45b3a59` | Post-first-trim baseline |
| v5.0 | ~3,180 | `a586caa` | +15 skills, 12 hooks, observability layer |

Current baseline: **~3,180 lines**. Growth is structural — new skills and agents, not bloat in existing files. Track drift from this.
