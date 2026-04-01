---
skill: trim
---
# Eval: /pds:trim

## Scenarios

### Scenario: Baseline comparison with growth
**Setup:** Skills + agents total exceeds baseline by 50%+. Several skills have verbose explanations of standard git/markdown concepts. One skill duplicates a checklist from another skill verbatim.
**Prompt:** Run /pds:trim
**Expected:**
- [ ] Inventories all files in `skills/*/SKILL.md` and `agents/*.md`
- [ ] Runs `wc -l` on each file and reports total
- [ ] Compares total to baseline stated in trim/SKILL.md
- [ ] Identifies the duplicated checklist and replaces with `See /skillname`
- [ ] Trims LLM-known content (e.g., explaining what `git rebase` does)
- [ ] Reports line count reduction with before/after numbers
**Anti-patterns:**
- [ ] Skips inventory step, trims only a few files ad hoc
- [ ] Reports "looks fine" without measuring line counts
- [ ] Deletes functional content (checklists, tool call sequences, templates)

### Scenario: Cross-reference validation
**Setup:** Three skills contain `See /oldskill` references where `/oldskill` was renamed to `/newskill`. CLAUDE.md skills table lists 22 skills but `skills/` directory has 23.
**Prompt:** Run /pds:trim
**Expected:**
- [ ] Detects broken `See /oldskill` cross-references
- [ ] Flags CLAUDE.md skill count mismatch (22 vs 23)
- [ ] Fixes cross-references to point to `/newskill`
- [ ] Updates CLAUDE.md skills table to match actual directory contents
**Anti-patterns:**
- [ ] Ignores cross-reference validation entirely
- [ ] Fixes references but doesn't check CLAUDE.md table
- [ ] Only checks skills, skips agents

### Scenario: Style rule enforcement
**Setup:** Two skills have 3+ quotes each. One skill has a 25-line code block. Several files use passive voice hedging ("It's important to remember that...").
**Prompt:** Run /pds:trim on current codebase
**Expected:**
- [ ] Flags files exceeding max 1 quote rule
- [ ] Flags code block exceeding 10-line max
- [ ] Rewrites hedging phrases to terse imperatives
- [ ] Preserves all functional content while applying style rules
- [ ] Runs validation checklist after trimming
**Anti-patterns:**
- [ ] Applies style rules but breaks functional content
- [ ] Only fixes one style issue, ignores others
- [ ] Skips validation checklist at the end

### Scenario: No-op when already lean
**Setup:** All skills are within baseline. No duplications. No style violations. Cross-references valid.
**Prompt:** Run /pds:trim
**Expected:**
- [ ] Completes full inventory and measurement
- [ ] Reports total is at or below baseline
- [ ] Reports "no trimming needed" with current count
**Anti-patterns:**
- [ ] Trims aggressively despite no waste
- [ ] Skips measurement and just says "looks good"

## Baseline
Without `/trim`, agents don't measure context cost. They may add verbose explanations, duplicate content across files, or let skills grow unbounded. Periodic trimming is never done spontaneously.
