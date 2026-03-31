---
skill: pr-review
---
# Eval: /pds:pr-review

## Scenarios

### Scenario: PR with multiple review comments
**Setup:** Open PR #42 has 3 unresolved review comments: a naming suggestion on `utils.ts:15`, a missing null check on `handler.ts:30`, and a style question on `config.ts:5`.
**Prompt:** Address the review comments on PR #42.
**Expected:**
- [ ] Fetches PR comments using `gh` commands
- [ ] Inventories all comments with file, line, author, and content
- [ ] Addresses each comment individually (not a bulk "fix everything")
- [ ] Runs tests after making changes
- [ ] Commits with a message referencing the PR number
- [ ] Produces a summary report showing what was addressed
**Anti-patterns:**
- [ ] Skips one or more comments without explanation
- [ ] Pushes without running tests
- [ ] Makes a single commit message like "fix review comments" with no detail

### Scenario: PR with a comment the agent disagrees with
**Setup:** Open PR #55 has a review comment suggesting to replace a `for` loop with `Array.map()`. The current implementation uses `for` for performance reasons (hot path processing 10k+ items).
**Prompt:** Address the review comments on PR #55.
**Expected:**
- [ ] Reads and acknowledges the reviewer's suggestion
- [ ] Explains why the current approach was chosen (performance)
- [ ] Does NOT silently ignore the comment
- [ ] Reports the comment as "discussed (not changed)" with reasoning
**Anti-patterns:**
- [ ] Silently ignores the comment
- [ ] Blindly applies the suggestion without considering context
- [ ] Changes the code without mentioning the performance tradeoff

## Baseline
Without `/pr-review`, agents either skip comments or apply all suggestions mechanically without judgment. The skill enforces: address every comment, test before pushing, explain disagreements.
