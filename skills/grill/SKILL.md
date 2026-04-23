---
description: Interrogating requirements to validate before building. Use before swarm decomposition, design decisions on ambiguous features, or when scope creep risk is high.
---
# /grill — Requirement Interrogation

Structured process for validating requirements before implementation. Ambiguous requirements are the #1 source of wasted tokens — a swarm that builds the wrong thing costs 10x more than grilling first.

## Mode

**Always run grill as a plan with Q&A.** Before starting, enter plan mode (`EnterPlanMode`). Grill is a structured conversation — the agent asks questions, the human answers, and each step builds on prior answers. No file writes, no code edits, no tool calls beyond search/read.

**Format:** For each step, the agent:
1. States its analysis or best-guess interpretation
2. Asks **one sharp question** via `AskUserQuestion` with yes/no or 2-4 numbered options
3. Waits for the human's response before advancing

No diagrams. PDS runs in a terminal where graphical blocks render as unreadable text — use prose lists, file paths, and concrete counts instead.

Do not skip steps or combine them. Do not proceed past a step without the human's input — the structured Q&A prevents premature convergence and surfaces assumptions early.

## Question Discipline

Five rules govern every question in the protocol:

1. **One sharpest question per turn.** Each step may surface multiple uncertainties — pick the one whose answer most constrains the next step, ask that, queue the rest. Never stack 3+ questions in a single turn; the human can only hold one in working memory.
2. **No hedge trailers.** Do not end questions with "or am I missing something?", "does that sound right?", "anything else?". These invite "yes" and stall. End with the concrete ask.
3. **Calibrate confidence.** When uncertainty is uneven, name it in the analysis: *"I'm confident [X] is in scope. I'm uncertain whether [Y] is."* Then offer [Y]'s resolution as the numbered options.
4. **Lead with the sharp edge, not the restatement.** Drop generic openers like "Here's what I understand…" when the analysis is already visible above. Ask the question directly.
5. **Close the loop.** End each question with a concrete answer shape: yes/no, a choice between options, a number, a named file — never an open "what do you think?".

## Structured vs Freeform Questions

**Default: `AskUserQuestion` for every question.** The user's primary input is a number pad + voice. Numbered options (1-4) or yes/no are the fastest paths to acknowledgment. Freeform prose (typed or dictated) is reserved for when the system genuinely cannot enumerate reasonable answers.

Every grill question must:
- Be phrased so **yes/no or 2-4 numbered options** cover the common answers
- Use `AskUserQuestion` with those options as the default prompt
- Rely on the tool's auto-provided **"Other"** option when the user needs to speak freeform
- Only fall back to pure freeform prompts when no enumerable answer set is meaningful (e.g., "What's the deadline date?", proper nouns, novel technical specs the model cannot predict)

**Mapping grill steps to question types:**

| Step | Primary question type | Example options |
|------|----------------------|-----------------|
| 1. Restate | yes/no + reason | Yes / No, wrong word / No, wrong scope / Other |
| 2. Boundary | per-component yes/no | In / Out / Defer / Other |
| 3. Success | confirm criteria set | Yes / Add more / Remove some / Replace / Other |
| 4. Constraints | confirm list | Yes / Add more / Correct one / Other |
| 5. Assumptions | per-assumption truth | True / False / Unknown / Other |
| 6. Risks | recovery strategy | Roll back / Mark partial, manual repair / Idempotent retry / No recovery needed / Other |
| 7. Priority | per-item bucket | Must / Should / Could / Skip |
| 8. MECE | per-gap disposition | Now / Defer / Out of scope / Other |
| 9. Scope Enumeration | lower-confidence bucket | Yes, all / Yes, some / No, defer / Other |
| 10. Tier | execution strategy | no-swarm / swarm:lite / swarm:med / swarm:heavy |

When a step has multiple sub-questions (per-component boundary, per-assumption truth), ask them one at a time. Do not batch them into a single AskUserQuestion with multiSelect unless the options are genuinely independent acks.

## When to Use

- Before `/pds:swarm` decomposition (Phase 1 references this)
- Before architecture decisions on ambiguous features
- When a task description feels incomplete or assumes too much
- When scope creep risk is high
- When debugging: write your hypothesis before investigating (what you think is happening, evidence that would confirm/disprove)

## Protocol

### 1. Restate

State your best interpretation, naming the **load-bearing word** whose meaning determines the rest. If the requirement is vague, name two plausible readings.

Analysis format: *"Restated: [concrete 1-sentence restatement]. The load-bearing word is **[word]** — I'm reading it as [interpretation A] rather than [plausible interpretation B]."*

Then ask via `AskUserQuestion`:

```
Question: Does this restatement match your intent?
Options:
  1. Yes — interpretation A is correct
  2. No — you meant interpretation B
  3. No — the load-bearing word is different
  4. (Other — voice/freeform correction)
```

### 2. Boundary

Draft in-scope and out-of-scope lists. State them as plain prose lists — one line per component with its status. Include the component → component relationships if they clarify the boundary:

```
In scope:
  - auth/middleware.ts  (primary target)
  - auth/tokens.ts      (reads from middleware)
Out of scope:
  - session/store.ts    (unchanged interface)
  - logout flow         (separate ticket)
```

Ask one component at a time via `AskUserQuestion` when scope is ambiguous:

```
Question: Is [component X] in scope?
Options:
  1. In scope
  2. Out of scope
  3. Defer — decide later
  4. (Other)
```

Repeat per ambiguous component. High-confidence components (obviously in or out) can be stated in the analysis without a question.

### 3. Success

Propose mechanically verifiable acceptance criteria — even if the requirement is vague. "Works correctly" is not a criterion. State the criteria, then ask:

```
Question: Do these acceptance criteria capture success?
Options:
  1. Yes — all captured
  2. Add more (will collect via follow-up)
  3. Remove some (will collect via follow-up)
  4. Replace with different criteria
  (Other — voice/freeform revision)
```

If the requirement is too ambiguous for exact criteria, propose best-guess criteria and flag them as assumptions to validate in step 5.

### 4. Constraints

Identify hard limits (technology, time, resources, compatibility). State them, then ask:

```
Question: Are these the right constraints?
Options:
  1. Yes — complete
  2. Add more (voice/freeform)
  3. Correct one (voice/freeform)
  4. (Other)
```

### 5. Assumptions

List each assumption explicitly. Ask one at a time:

```
Question: Assumption — [the database schema won't change]. Is this true?
Options:
  1. True
  2. False
  3. Unknown — need to check
  4. (Other)
```

Repeat per assumption. For assumptions that are clearly safe, state them in analysis and skip the question.

### 6. Risks

Rank risks by blast radius. Describe the failure chain as an inline sequence, e.g. *"operation starts → success? → if no, partial state → recovery? → rollback or manual intervention."*

For the highest-blast-radius risk, state the concrete failure mode, then ask:

```
Question: If [specific operation] fails after step N of M, leaving [specific partial state] — what's the recovery strategy?
Options:
  1. Roll back on failure
  2. Mark partial, require manual repair
  3. Idempotent retry until success
  4. No recovery needed (best-effort)
  (Other)
```

Hold secondary risk questions until the primary is answered. Do not stack multiple risk questions per turn.

### 7. Priority

For each item, ask the priority bucket:

```
Question: Priority for [item X]?
Options:
  1. Must — ship is blocked without this
  2. Should — expected but deferrable
  3. Could — nice to have
  4. Skip — drop from scope
```

Repeat per item. Queue low-importance items; lead with the item whose priority most changes the plan.

### 8. MECE Check

Check for gaps, overlaps, and edge cases. For each gap found, state it concretely and ask:

```
Question: Gap — [what happens when X and Y are both true]. Handle how?
Options:
  1. Address now (add to criteria)
  2. Defer — track as follow-up
  3. Out of scope — ignore
  4. (Other)
```

### 9. Scope Enumeration

Use Grep/Glob to find ALL files, functions, and patterns affected. Split into high-confidence matches (direct call sites) and lower-confidence matches (name collisions, tests, docs that may or may not need updating).

Analysis: *"Enumerated [N] affected files across [M] modules. High-confidence (direct call sites): [list-A, count]. Lower-confidence (collisions, tests, docs): [list-B, count]."*

Ask:

```
Question: Include lower-confidence matches in scope?
Options:
  1. Yes — include all lower-confidence matches
  2. Yes — include a subset (will collect via follow-up)
  3. No — defer to a follow-up task
  4. (Other)
```

If no codebase is available, describe the enumeration approach instead: what to search for, where to look, what patterns to match.

### 10. Swarm Decision + Tier

Based on the validated requirements, decide execution strategy. Produce the tier decision as an `AskUserQuestion` — **never free-form `Recommendation:` text**.

Analysis: state boundary count, pattern-match vs novel design, risk items identified. Name the recommended tier and why.

Ask:

```
Question: Execution strategy?
Options:
  1. no-swarm — single agent, < 30 turns, one module
  2. swarm:lite — 2 modules, follows existing patterns
  3. swarm:med — 2-3 boundaries, some design decisions
  4. swarm:heavy — 3+ boundaries, new interfaces or core abstraction refactor
```

Tier criteria (repeat the short description per option in the `AskUserQuestion` `description` field so the user sees the trade-off inline):

- **No-swarm** when: changes stay within a single module, no parallelism opportunity, single agent can complete in ~30 turns or less.
- **Lite** when: crosses 2 modules but follows existing patterns; low ambiguity; no new interfaces.
- **Med** when: crosses 2-3 architecture boundaries; some design decisions; may add new interfaces within existing conventions.
- **Heavy** when: crosses 3+ boundaries; new interfaces or contracts between modules; refactors a core abstraction; significant risks identified in step 6.

## Output

After completing the Q&A, synthesize a validated problem statement:
- Restated problem (1-2 sentences, confirmed by human)
- Scope boundary (in/out lists with architecture diagram)
- Acceptance criteria (mechanically verifiable, human-approved)
- Constraints and assumptions (explicit, challenged)
- Priority ranking (must/should/could/skip per item)
- Risk analysis with recovery strategies
- Scope enumeration (affected files/patterns with counts; lower-confidence bucket disposition)
- Swarm decision with tier (selected via AskUserQuestion, not free-form)

This feeds directly into `/pds:swarm` Phase 1 tier initialization and Phase 2 decomposition, and into `/pds:ticket` for the GitHub issue body (plan + acceptance criteria checklist).

## See Also

- `/pds:swarm` — Phase 1 runs /grill before decomposition
- `/pds:ticket` — plan + criteria from grill populate the GitHub issue body
- `/pds:voice` — grill is voice-OFF (deliberative register), but grill's caller (main session) may be voice-ON
