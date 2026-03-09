---
description: Testing whether skills produce correct agent behavior. Use after modifying a skill, during periodic review, or when model upgrades may affect skill relevance.
---
# /eval — Skill Evaluation

Skills need tests like code does. A modified skill that silently degrades is worse than no skill — it creates false confidence. This protocol defines how to write, run, and report skill evals.

## When to Run

- After modifying a skill's protocol or constraints
- During periodic review (scout Phase 6)
- When a model upgrade may make a skill redundant
- On request, to validate skill effectiveness

## EVAL.md Format

Each skill can have a companion `EVAL.md` in its directory. Structure:

```markdown
---
skill: skill-name
---
# Eval: /pds:skillname

## Scenarios

### Scenario: [descriptive name]
**Setup:** [Context — files present, task state, branch state]
**Prompt:** [The situation that should trigger this skill]
**Expected:**
- [ ] [Observable behavior — binary, not subjective]
- [ ] [Another expected behavior]
**Anti-patterns:**
- [ ] [Thing the agent should NOT do]

## Baseline
[Behavior WITHOUT the skill — for A/B comparison]
```

**Rules for scenarios:**
- Expected behaviors are binary: did it or didn't. No "good enough."
- Anti-patterns catch the failure modes the skill was created to prevent.
- 2-3 scenarios per skill. Cover the happy path and the key failure mode.

## Execution Protocol

### Manual Eval
1. Read the skill's `EVAL.md`
2. For each scenario: spawn a worker with the setup and prompt
3. Observe worker behavior against the expected checklist
4. Record results

### Scout Eval (Phase 6)
Scout reads EVAL.md for skills exercised during the swarm. Grades against rubric based on observed agent behavior in that swarm — no re-execution needed.

## Results

Record in `.claude/eval-results.md`:

```markdown
## [YYYY-MM-DD] /pds:skillname

| Scenario | Result | Notes |
|----------|--------|-------|
| Name | pass/partial/fail | [what happened] |

**Evaluator:** scout | human
**Context:** [what triggered this eval]
```

## Scoring

| Result | Criteria |
|--------|----------|
| **pass** | All expected behaviors observed, no anti-patterns |
| **partial** | >50% expected behaviors, minor anti-pattern violations |
| **fail** | <50% expected behaviors OR critical anti-pattern |

## A/B Comparison

To test whether a skill adds value over baseline:
1. Run a scenario **without** the skill loaded (baseline behavior)
2. Run the same scenario **with** the skill
3. Compare against the Baseline section in EVAL.md

Use when: questioning whether a model upgrade made a skill redundant.

## See Also

- `/pds:instinct` — pattern lifecycle (evals complement instinct validation)
- `/pds:verify` — work output verification (eval checks skill adherence)
- Scout agent — runs evals during Phase 6
