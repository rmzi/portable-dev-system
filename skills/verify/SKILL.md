---
description: Verifying work completeness before declaring done. Use before marking tasks complete, creating PRs, or claiming task status as done.
---
# /verify — Completion Self-Check

Claiming done without evidence is dishonesty, not efficiency. Run this protocol before declaring any task complete.

## Invocation

```
/verify              # Run completion self-check
```

## Self-Check Protocol

### 1. Re-read Acceptance Criteria
Open the original task description, PR body, or issue. Compare deliverables against each criterion. Partial completion is not completion.

### 2. Run Test Suite
Execute the full test suite — not just the tests you wrote. New code can break existing tests.

```bash
# Run project tests (adapt to your stack)
npm test          # Node.js
pytest            # Python
cargo test        # Rust
go test ./...     # Go
```

### 3. Scan for Debug Artifacts
Search for leftover debugging code:

```bash
grep -rn 'console\.log\|debugger\|TODO\|FIXME\|HACK\|XXX' --include='*.ts' --include='*.js' --include='*.py' src/
```

Remove anything that shouldn't ship.

### 4. Check git status
Run `git status` and `git diff`. Ensure:
- No untracked files that should be committed
- No unstaged changes that belong to this task
- No accidentally staged files from other work

### 5. Review Own Diff
Read your complete diff as if reviewing someone else's code:

```bash
git diff main...HEAD    # or appropriate base branch
```

Look for: missing error handling, hardcoded values, unclear names, dead code.

### 6. Confirm Docs Updated
If your change affects user-facing behavior, verify documentation is current. Missing docs create support burden.

## Output Format

```
/verify — [task description]
✓ Acceptance criteria met (N/N)
✓ Test suite passes
✓ No debug artifacts
✓ git status clean
✓ Diff reviewed
✓ Docs current
Result: PASS
```

Or if issues found:

```
/verify — [task description]
✓ Acceptance criteria met (N/N)
✗ Test suite — 2 failures in auth.test.ts
✓ No debug artifacts
✗ git status — untracked migration file
Result: FAIL — fix before declaring done
```

## See Also

- `/pds:finish` — branch completion protocol (calls /verify)
