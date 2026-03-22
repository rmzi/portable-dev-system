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

### Post-calibration — Sonnet, 10 runs

| Scenario | Result | 95% CI | Notes |
|----------|--------|--------|-------|
| Vague performance request | 6/10 (60%) | [31%-83%] | Possible haiku grader limitation on rich sonnet output |
| Feature with missing edge cases | 8/10 (80%) | [49%-94%] | Sonnet occasionally skips cascade failure questions |
| Tier selection for cross-module feature | 9/10 (90%) | [59%-98%] | Strong — boundary-based criteria well-calibrated |
| Tier selection for core abstraction refactor | 7/10 (70%) | [39%-89%] | Good — some runs downgrade to med |
| **Overall** | **30/40 (75%)** | **[59%-85%]** | |

**Evaluator:** `scripts/run-eval.sh` — execution: sonnet, grading: haiku

### Known limitations

- **Haiku grader bottleneck:** Haiku may under-credit sonnet/opus output that is correct but verbose. "Vague performance request" scored 100% at 3 runs but 60% at 10, suggesting grader variance not model variance. Future work: test sonnet-as-grader.
- **Wide CIs at N=10:** Most CIs span 30-40 percentage points. N=20 would narrow to ~25 points.

### Recommendations

1. Use these as the **v4.5.0 baseline**. After skill modifications, run `./scripts/run-eval.sh grill --runs 10 --model sonnet` and compare.
2. Investigate sonnet-as-grader for future runs to reduce grader noise.
3. The "missing edge cases" scenario (80%) could be sharpened — sonnet's cascade failure coverage is inconsistent.
