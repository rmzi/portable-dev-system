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
