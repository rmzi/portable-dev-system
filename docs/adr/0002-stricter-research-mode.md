# ADR 0002: Stricter Research Mode

## Status
Proposed

## Context

Issue #62 requests a toggle for stricter citation constraints in research mode. Currently, the researcher agent operates in plan mode (read-only) but has no explicit constraints around:
- Citation accuracy — claims can be made without source references
- Uncertainty — agents tend to fabricate rather than say "I don't know"
- Quotation fidelity — paraphrasing can drift from the original meaning

## Decision

### Design: `strict: true` frontmatter flag

Add an optional `strict` field to agent frontmatter that activates citation constraints:

```yaml
---
name: researcher
strict: true    # activates citation constraints
---
```

When `strict: true` is set, the following rules apply:

### 1. Citation Constraints
Every factual claim about the codebase must include a source reference:
- File path and line number for code references: `path/to/file.ts:42`
- Commit hash for historical claims: `abc1234`
- Documentation path for doc references: `docs/api.md`

Format: `[claim] (source: path:line)` or inline code block with path.

### 2. "I Don't Know" Permission
Agents operating in strict mode are explicitly permitted — and encouraged — to say:
- "I don't know" when they lack information
- "I'm not sure" when evidence is ambiguous
- "I couldn't find evidence for this" when searches return empty

This overrides the default tendency to provide confident-sounding answers regardless of certainty.

### 3. Direct Quote Support
When referencing code or documentation:
- **Use exact text** in code blocks, not paraphrased descriptions
- **Include surrounding context** (2-3 lines before/after) for clarity
- **Mark omissions** with `[...]` when quoting partial sections
- Never claim code does something without showing the relevant lines

### Implementation

#### Option A: Frontmatter flag (recommended)
Add `strict: true` to agents/researcher.md frontmatter. The agent definition body includes the rules. No hook changes needed — the rules are self-enforcing via the agent prompt.

```yaml
---
name: researcher
strict: true
# ... rest of frontmatter
---
```

And in the body:
```markdown
## Strict Mode (active when `strict: true` in frontmatter)
- Every factual claim requires a source reference
- Say "I don't know" when uncertain
- Use direct quotes, not paraphrases
```

#### Option B: Shared-rules section
Add a `## Strict Research Mode` section to shared-rules.md that all agents inherit but only activates for agents with `strict: true`.

#### Option C: Prompt parameter
Pass `strict=true` as a spawn parameter: `Task(researcher, strict=true, ...)`. More flexible but less discoverable.

### Recommendation
**Option A** — frontmatter flag. It's the simplest, most discoverable approach. The researcher agent already has unique constraints (read-only, plan mode). Adding citation rules to its definition keeps related rules together.

The flag defaults to `false` (current behavior). Users and orchestrators can opt in by spawning with the flag or editing the agent definition.

## Consequences

### Positive
- Reduces fabrication in research reports
- Makes uncertainty explicit — better for downstream decision-making
- Direct quotes prevent meaning drift
- Opt-in design avoids disrupting current workflows

### Negative
- Strict mode increases output verbosity (citations add tokens)
- "I don't know" answers may frustrate users expecting confident responses
- Not mechanically enforceable — relies on agent compliance
- May slow down research tasks due to citation overhead

### Open Questions
- Should strict mode be on by default for the researcher agent?
- Should other agents (reviewer, auditor) also support strict mode?
- Is there a way to mechanically verify citations (PostToolUse hook that checks file:line references)?
