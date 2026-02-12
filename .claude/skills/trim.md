---
description: Maintain context efficiency of PDS skills and agent definitions
---
# /trim — Context Efficiency Maintenance

Keep PDS artifacts lean. Every line in `.claude/` costs context tokens at session start.

## Invocation

```
/trim              # Audit all skills + agents
/trim [file]       # Audit a specific file
```

## Style Rules

1. **Preserve structure.** Keep frontmatter, titles, invocation blocks, checklists, tables, templates.
2. **Terse imperative prose.** Cut filler words. Use active voice. One idea per sentence.
3. **Max 1 quote per file.** Quotes are memorable; more than one dilutes impact.
4. **Max 10 lines per code block.** Trim examples to the minimum that teaches.
5. **Cross-reference, don't repeat.** Use `See /skillname` instead of duplicating content.
6. **Cut LLM-known content.** Don't explain git, markdown, or standard tooling. The model knows.
7. **No hedging or preamble.** Drop "It's important to...", "Remember that...", "Note:".

## Audit Process

1. **Inventory.** List all files in `.claude/skills/` and `.claude/agents/`.
2. **Measure.** `wc -l` each file. Record total. Compare to baseline if known.
3. **Identify waste.**
   - Duplicated content across files → keep in canonical source, replace elsewhere with `See /skillname`
   - Verbose explanations of standard concepts → cut
   - Redundant examples → keep one, remove rest
   - Passive voice or hedging → rewrite terse
4. **Trim.** Apply style rules. Preserve all functional content and checklists.
5. **Validate.** Run the checklist below.

## Validation Checklist

- [ ] Total line count reduced (or justified if not)
- [ ] Fidelity: spot-check 3 skills — do they still convey the same workflow?
- [ ] Cross-references: every `See /skillname` points to a real skill
- [ ] `CLAUDE.md` skills table matches actual `.claude/skills/` contents
- [ ] No broken frontmatter or invocation blocks

## Duplication Resolution

When content appears in multiple files:

1. Identify the **canonical source** (the skill where the topic is primary).
2. Keep full content there.
3. Replace elsewhere with: `See /skillname for [topic].`

## Baseline

After the initial trim (commit `45b3a59`): ~1,442 lines across skills + agents. Track drift from this.
