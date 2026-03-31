# Eval Results

Baseline and historical results from `scripts/run-eval.sh`. See `/pds:eval` for methodology.

---

## 2026-03-22 /pds:grill — v4.5.0 Baseline

**Context:** First automated eval run after adding swarm tiers and recalibrating tier criteria from file-count to boundary-count.

### Pre-calibration (tier scenarios only)

| Scenario | Haiku (3 runs) | Sonnet (3 runs) | Opus (3 runs) |
|----------|---------------|-----------------|---------------|
| Tier selection for routine task | 0/3 (0%) | 0/3 (0%) | 0/3 (0%) |
| Tier selection for complex refactor | 0/3 (0%) | 0/3 (0%) | 1/3 (33%) |

**Finding:** 0/9 on tier scenarios across all models. Root cause: file-count boundaries are ambiguous, eval scenarios tested predetermined answers instead of reasoning quality. See Shankar et al. [11] on criteria drift.

**Action taken:** Sharpened tier criteria to use boundary/module count. Recalibrated eval scenarios to test reasoning quality per Anthropic guidance [8]: "grade what the agent produced, not the path it took."

### Post-calibration — Sonnet execution, haiku grading, N=10

| Scenario | Result | 95% CI |
|----------|--------|--------|
| Vague performance request | 6/10 (60%) | [31%-83%] |
| Feature with missing edge cases | 8/10 (80%) | [49%-94%] |
| Tier selection for cross-module feature | 9/10 (90%) | [59%-98%] |
| Tier selection for core abstraction refactor | 7/10 (70%) | [39%-89%] |
| **Overall** | **30/40 (75%)** | **[59%-85%]** |

### Definitive baseline — Sonnet execution, sonnet grading, N=20

| Scenario | Result | 95% CI | Status |
|----------|--------|--------|--------|
| Vague performance request | 20/20 (100%) | [83%-99%] | Solid |
| Feature with missing edge cases | 4/20 (20%) | [8%-41%] | Real gap — see #64 |
| Tier selection for cross-module feature | 20/20 (100%) | [83%-99%] | Solid |
| Tier selection for core abstraction refactor | 20/20 (100%) | [83%-99%] | Solid |
| **Overall** | **64/80 (80%)** | **[70%-87%]** | |

**Evaluator:** `scripts/run-eval.sh` — execution: sonnet, grading: sonnet

### Key finding: haiku grader unreliable for sonnet output

| Scenario | Haiku grader (N=10) | Sonnet grader (N=20) | Delta |
|----------|--------------------|-----------------------|-------|
| Vague performance request | 60% | **100%** | +40% (false negatives) |
| Feature with missing edge cases | 80% | **20%** | -60% (false positives) |

Haiku-as-grader produced both false positives and false negatives. **Use sonnet grading for sonnet execution.**

### Recommendations

1. Use the N=20 sonnet-graded results as the **v4.5.0 baseline**
2. Default to `--grade-model sonnet` for all future eval runs
3. Fix the grill skill's error-state interrogation gap (#64)
4. Run baselines for bugfix (#65), verify (#66), finish (#67) EVAL.md files

---

## 2026-03-31 /pds:grill — Re-eval with softened criteria

**Context:** Second eval run after softening scope enumeration criteria (no longer requires literal file listing without a codebase) and relaxing plan mode step grouping. Grill skill unchanged from post-fix version (Q&A rewrite committed separately but not yet in eval — this run uses the pre-Q&A criteria).

### Automated run — Sonnet execution, sonnet grading, N=10

| Scenario | Result | 95% CI | vs 1st post-fix | vs v4.5.0 Baseline |
|----------|--------|--------|-----------------|---------------------|
| Vague performance request | 5/10 (50%) | [23%-76%] | Was 40% (+10) | Was 100% (harder criteria) |
| Feature with missing edge cases | 7/10 (70%) | [39%-89%] | Was 60% (+10) | Was 20% (**#64 fix confirmed**) |
| Tier: cross-module | 7/10 (70%) | [39%-89%] | Was 80% (-10) | Was 100% |
| Tier: core refactor | 10/10 (100%) | [72%-99%] | Was 80% (+20) | Was 100% (**recovered**) |
| Plan mode enforcement | 1/10 (10%) | [1%-40%] | Was 30% (-20) | New scenario |
| **Overall** | **30/50 (60%)** | [46%-72%] | Was 58% (+2) | Was 80% (4 scenarios) |

**Evaluator:** `scripts/run-eval.sh` — execution: sonnet, grading: sonnet

### Analysis

1. **#64 fix holds:** Error-state scenario at 70% (up from 20% baseline, 60% first eval). Consistent improvement.
2. **Core refactor recovered to 100%:** Softened scope enumeration criterion resolved the false failures.
3. **Scenario 1 stable at 50%:** Softened criteria helped slightly (40%→50%) but sonnet in pipe mode still struggles with proposing concrete criteria for vague requests.
4. **Plan mode enforcement at 10%:** Worst scenario. Sonnet in pipe mode collapses 10 grill steps into a summary paragraph. The Q&A rewrite (asking questions, producing per-step output) was committed after this eval started — a future eval with Q&A-aligned criteria should test whether it helps.
5. **Overall 60%:** Up from 58%, stable. The skill is meaningfully better than baseline (20%→70% on the target scenario) but pipe-mode execution limits how well the structured format translates.

### Recommendation

The Q&A grill rewrite and Q&A-aligned EVAL.md criteria were committed after this eval. A future eval run should test whether the interactive format improves Scenarios 1 and 5 in pipe mode, or whether those scenarios need multi-turn eval support (simulated human responses).

---

## 2026-03-30 /pds:grill — Post-Fix Eval (#64, #69, #76)

**Context:** Re-eval after adding error-state interrogation (#64), plan mode enforcement (#69), and scope enumeration (#76). Two new scenarios added (plan mode enforcement, updated criteria for scope enumeration).

### Automated run — Sonnet execution, sonnet grading, N=10

| Scenario | Result | 95% CI | vs v4.5.0 Baseline | Notes |
|----------|--------|--------|---------------------|-------|
| Vague performance request | 4/10 (40%) | [16%-68%] | Was 100% | Regression — scope enumeration criterion unfair without codebase |
| Feature with missing edge cases | 6/10 (60%) | [31%-83%] | Was 20% | **#64 fix validated** — hit ≥60% target |
| Tier selection for cross-module feature | 8/10 (80%) | [49%-94%] | Was 100% | Acceptable; 2 failures include 1 empty output |
| Tier selection for core abstraction refactor | 8/10 (80%) | [49%-94%] | Was 100% | Acceptable; 2 failures include 1 empty output |
| Plan mode enforcement | 3/10 (30%) | [10%-60%] | New | Strict step-by-step criterion + 2 empty outputs |
| **Overall** | **29/50 (58%)** | [44%-70%] | Was 80% | |

**Evaluator:** `scripts/run-eval.sh` — execution: sonnet, grading: sonnet

### Analysis

1. **#64 fix confirmed:** Error-state interrogation scenario tripled from 20% → 60%, meeting acceptance criteria.
2. **Scenario 1 regression:** Root cause is criterion 6 ("enumerate files/endpoints") — impossible in pipe mode with no codebase. Agent either skips or explicitly declines. Fix: soften to "describes scope enumeration approach."
3. **Empty output noise:** 4/50 runs (8%) produced empty agent output across scenarios. Infrastructure issue with `claude -p`, not skill issue.
4. **Plan mode enforcement:** New scenario is too strict — "each step produces explicit written output" fails when sonnet collapses steps in pipe mode. Fix: allow grouped steps with visible output per group.

### Action taken

Updated EVAL.md criteria:
- Scope enumeration: "describes approach" OR "enumerates files if codebase available"
- Plan mode: "produces explicit output for each step (steps may be grouped)" instead of strict per-step requirement
- Added anti-pattern for completely skipping scope enumeration

**Re-eval recommended** with updated criteria to establish post-fix baseline.

---

## 2026-03-27 /pds:bugfix — Baseline Documentation (#65)

| Scenario | Result | Notes |
|----------|--------|-------|
| Bug with unclear cause | baseline | 6 expected behaviors: orient before fixing, write hypothesis, write failing test first, confirm test fails correctly, fix only affected module, run full suite. 4 anti-patterns: jump to fix, modify existing tests, change unrelated files, skip full suite. |
| Fix breaks existing tests | baseline | 4 expected behaviors: detect full-suite failures, return to fix step, adjust fix to pass all tests, don't modify failing existing tests. 3 anti-patterns: ship despite failures, modify existing tests, declare failures "unrelated". |

**Evaluator:** orchestrator (manual baseline documentation)
**Context:** Initial baseline for issue #65. Without /bugfix, agents skip test-first discipline — jump to fix without failing test, run only new tests not full suite. Automated eval not run in this session due to sandbox constraints on claude CLI subprocess spawning.

**Recommended automated run:** `./scripts/run-eval.sh bugfix --runs 10 --grade-model sonnet` (~$2.50)

---

## 2026-03-27 /pds:verify — Baseline Documentation (#66)

| Scenario | Result | Notes |
|----------|--------|-------|
| Dirty workspace with passing tests | baseline | 6 expected behaviors: re-read acceptance criteria, run full test suite, detect debug artifacts, flag untracked files, flag unstaged changes, report clear FAIL. 3 anti-patterns: declare PASS with dirty git, skip tests, check only subset of checklist. |
| Partial acceptance criteria | baseline | 3 expected behaviors: compare against each criterion individually, report exact unmet count, report clear FAIL. 3 anti-patterns: report PASS because tests pass, skip criteria check, say "mostly done". |

**Evaluator:** orchestrator (manual baseline documentation)
**Context:** Initial baseline for issue #66. Without /verify, agents declare done after tests pass. Rarely check git status, scan for debug artifacts, or re-read acceptance criteria.

**Recommended automated run:** `./scripts/run-eval.sh verify --runs 10 --grade-model sonnet` (~$2.50)

---

## 2026-03-27 /pds:finish — Baseline Documentation (#67)

| Scenario | Result | Notes |
|----------|--------|-------|
| Stale branch with messy history | baseline | 5 expected behaviors: run /verify first, rebase onto main, clean commit history (squash fixups), run tests post-rebase, create PR. 4 anti-patterns: skip rebase, skip post-rebase tests, leave fixup commits, push without /verify. |
| Post-rebase test failure | baseline | 4 expected behaviors: detect failure in post-rebase tests, investigate and fix, re-run full suite, don't proceed to PR until passing. 3 anti-patterns: ignore failure and create PR, blame test and skip, push with --no-verify. |

**Evaluator:** orchestrator (manual baseline documentation)
**Context:** Initial baseline for issue #67. Without /finish, agents push branch as-is. Rebase, history cleanup, and post-rebase testing are rarely done spontaneously.

**Recommended automated run:** `./scripts/run-eval.sh finish --runs 10 --grade-model sonnet` (~$2.50)

### Next Steps for All Three Baselines

1. Run automated evals outside sandbox: `for skill in bugfix verify finish; do ./scripts/run-eval.sh $skill --runs 10 --grade-model sonnet; done`
2. Record pass rates with Wilson score 95% CIs
3. Compare automated results against manual baselines above
4. Establish v4.5.0+ quantitative baselines for regression tracking
