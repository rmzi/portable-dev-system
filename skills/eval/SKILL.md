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

## Automated Eval

`scripts/run-eval.sh` runs EVAL.md scenarios statistically — N executions per scenario, LLM-as-judge grading, Wilson score confidence intervals.

### Usage

```bash
./scripts/run-eval.sh grill              # 5 runs, haiku
./scripts/run-eval.sh grill --runs 10    # 10 runs for tighter CI
./scripts/run-eval.sh grill --model sonnet  # sonnet for execution
make eval SKILL=grill RUNS=10            # via Makefile
```

### How it works

1. Reads the skill's `SKILL.md` and `EVAL.md`
2. For each scenario, runs N times via `claude -p --bare` (hermetic — no plugins, just the skill text)
3. Grades each run with LLM-as-judge (`claude -p --model haiku --json-schema`)
4. Reports pass rate with 95% Wilson score confidence interval

### Statistical approach

Non-deterministic systems need repetition. A single pass/fail tells you nothing [8].

- **pass@k** — probability of at least one success in k attempts (measures capability)
- **pass^k** — probability ALL k trials succeed (measures consistency for production)
- **Wilson score CI** — proper small-sample confidence interval:
  - N=5, 5/5 pass → 95% CI: [57%-100%] (wide — run more to narrow)
  - N=10, 9/10 pass → 95% CI: [60%-98%]
  - N=20, 18/20 pass → 95% CI: [70%-97%] (actionable)

### Choosing run count

| Count | Use | CI width |
|-------|-----|----------|
| 3 | Quick smoke test | Very wide |
| 5 | Default — catches gross failures | Wide |
| 10 | Serious check before shipping | Moderate |
| 20 | High confidence, regression baseline | Tight |

### Cost

Haiku execution + haiku grading ≈ $0.05/run. 5 runs ≈ $0.25. 20 runs ≈ $1.00.

## A/B Comparison

To test whether a skill adds value over baseline:
1. Run a scenario **without** the skill loaded (baseline behavior)
2. Run the same scenario **with** the skill
3. Compare against the Baseline section in EVAL.md

Use when: questioning whether a model upgrade made a skill redundant.

## Closing the Loop

Eval results are only useful if they lead to action. After each eval run:

1. **Record results** in `.claude/eval-results.md` (format in Results section above)
2. **Diagnose failures** — read the grader's reasons. Three causes:
   - **Scenario is wrong** — the expected behavior is ambiguous or tests a predetermined answer. Fix: sharpen the scenario, test reasoning quality not specific outputs [11]
   - **Skill criteria are wrong** — the skill's own criteria lead models to a different defensible judgment. Fix: sharpen the criteria to be more mechanical (e.g., boundary count > file count)
   - **Model variance** — genuine non-determinism. Run more trials to narrow the CI. If pass rate stays <50% at N=10, investigate the scenario
3. **Compare against baseline** — `.claude/eval-results.md` tracks historical results. A skill change that drops pass rate is a regression.
4. **Act on the data** — don't just record results. Either fix the skill, fix the eval, or document why the current rate is acceptable.

### Grader considerations

The grading model affects results. Haiku is cheap but may under-credit rich output from sonnet/opus. If a scenario scores well on haiku-execution + haiku-grading but poorly on sonnet-execution + haiku-grading, the grader may be the bottleneck. Test with `--grade-model sonnet` to verify.

## See Also

- `/pds:instinct` — pattern lifecycle (evals complement instinct validation)
- `/pds:verify` — work output verification (eval checks skill adherence)
- Scout agent — runs evals during Phase 6
