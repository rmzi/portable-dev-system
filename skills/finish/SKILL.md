---
description: Completing a development branch for merge readiness. Use when implementation and tests pass and the branch needs formal preparation for review and merge.
---
# /finish — Branch Completion Protocol

The gap between "code works" and "branch is ready" is where quality lives. This protocol ensures branches are clean, tested, and reviewable.

## Invocation

```
/finish patch [target-branch]    # Verify, clean, bump patch, ship
/finish minor [target-branch]    # Verify, clean, bump minor, ship
/finish major [target-branch]    # Verify, clean, bump major, ship
```

Default target: main.

## Protocol

### 1. Verify Completeness
Run `/pds:verify` first. Do not proceed until it passes.

### 2. Rebase onto Target
Ensure your branch is current with the target:

```bash
git fetch origin
git rebase origin/main    # or target branch
```

Resolve any conflicts. Each conflict resolution should maintain both sides' intent — don't blindly accept one side.

### 3. Clean Commit History
Review your commits:

```bash
git log --oneline main..HEAD
```

If there are fixup commits or WIP entries, squash them non-interactively:

```bash
# Squash all branch commits into one clean commit
git reset --soft origin/main
git commit -m "feat(scope): descriptive message"

# Or use autosquash for commits prefixed with fixup!/squash!
git rebase --autosquash origin/main
```

Each commit should be atomic and meaningful. Use conventional commit format: `<type>(<scope>): <subject>`. Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `perf`. Subject in imperative mood, max 72 chars. Body explains *what* and *why*, not *how*.

**Do NOT use `git rebase -i`** — interactive rebase requires terminal input and will hang in agent contexts.

### 4. Run Tests Post-Rebase
Tests must pass *after* rebase, not just before:

```bash
# Run full test suite again
npm test    # or equivalent
```

Rebasing can introduce subtle breakage — verify.

**If the branch touched `agents/`, `hooks/`, or any spawn syntax in `skills/`, also run the live dispatch smoke test:**

```bash
scripts/smoke-dispatch.sh          # researcher + worker (covers both spawn paths)
scripts/smoke-dispatch.sh --all    # every spawnable agent type
```

This is not optional paranoia. PDS has twice shipped a release in which the orchestrator could not spawn a single agent — #170 and #181 — and the full static suite was green both times, because the contract being violated was Claude Code's, not PDS's. The static guards (`install.sh --test`) catch the two *known* shapes; only an actual spawn proves dispatch still works. It needs an authenticated `claude`, so CI cannot run it — a human must, before shipping.

### 5. Permission Audit

Review `.claude/settings.local.json` for permission patterns that should be promoted to `.claude/settings.json`:

1. Read both files
2. Identify glob-style allow patterns in local (e.g., `Bash(git *:*)`, `Bash(gh *:*)`, tool names) that aren't already in project settings
3. Exclude one-off entries (specific file paths, session-specific `rm` commands, temp artifacts)
4. If promotable patterns exist, add them to `.claude/settings.json` `permissions.allow` and remove from `settings.local.json`
5. If no promotable patterns exist, skip — do not modify either file

This ensures permission improvements ship with the code rather than accumulating silently in local settings.

### 6. Extract Knowledge

If `.claude/swarm/` exists in the current worktree, preserve ephemeral state as its own commit before shipping:

1. **Archive artifacts to git.** Copy all `*.md` files from `.claude/swarm/` to `docs/swarm-reports/<YYYY-MM-DD-HHmm>/`:
   ```bash
   REPORT_DIR="docs/swarm-reports/$(date +%Y-%m-%d-%H%M)"
   mkdir -p "$REPORT_DIR"
   cp .claude/swarm/*.md "$REPORT_DIR/"
   git add "$REPORT_DIR"
   git commit -m "chore: archive swarm artifacts to docs/swarm-reports"
   ```
2. **Distill to auto-memory.** Review the archived artifacts and write **1-2** auto-memory entries (project or feedback type) capturing:
   - WHY key decisions were made and what alternatives were rejected
   - Surprising findings or constraints discovered during the swarm
   - Skip anything derivable from code, git history, or existing docs

Auto-memory writes happen outside git (under `~/.claude/projects/`) and survive worktree removal automatically.

Extraction lives here — after the branch is clean and audited, before ship — so the archive commit is atomic and reviewable in the PR, never mixed into a verify/rebase/clean step. If `.claude/swarm/` does not exist, skip to Step 7.

### 7. Ship

Bump, commit, push, and create/update PR.

**Protected branch check.** Before pushing, check if the target branch is protected:

1. Read CLAUDE.md for a `Protected Branches` section listing branch patterns (e.g., `main`, `release/*`)
2. If the current branch or push target matches a protected pattern, **prompt the user** for confirmation before pushing
3. If no `Protected Branches` section exists in CLAUDE.md, no branches are protected — push freely

#### 7a. Commit Work

If uncommitted changes exist (staged or unstaged):
- Stage changes: `git add` relevant files (not `-A` — be deliberate)
- Commit with provided message, or derive from branch name and changes
- Use conventional commit format: `<type>(<scope>): <subject>`

If working tree is clean, skip to 7b.

#### 7b. Detect Bump Type (if not specified)

If no bump type was passed, scan git log since the last version tag:

```bash
git log $(git describe --tags --abbrev=0 2>/dev/null)..HEAD --oneline 2>/dev/null || git log --oneline
```

Apply the highest-precedence rule found:

| Commit prefix | Bump type |
|---------------|-----------|
| `BREAKING CHANGE` in body, or `!` after type (e.g. `feat!:`) | major |
| `feat:` | minor |
| `fix:`, `perf:`, `refactor:`, etc. | patch |

Default to **patch** if no conventional commits found.

#### 7c. Bump Version

Follow `/pds:bump` protocol:
1. Detect version file (VERSION, package.json, etc.)
2. Calculate new version based on bump type
3. Update version file(s) + CHANGELOG.md
4. Commit: `chore: bump version to X.Y.Z`

#### 7d. Push and PR

```bash
git push origin HEAD
```

**If the branch encodes a tracking issue** (`<type>/<issue>-<slug>` — same pattern 7e uses), create the PR from the slim template (`skills/ticket/templates/pr-body.md`) instead of `--fill`, per `docs/adr/0009-evolving-body-issue-and-slim-pr-format.md`: the issue is the source of truth, the PR just links to it — don't duplicate a TL;DR/AC/plan the issue already carries.

```bash
ISSUE="$(echo "$(git branch --show-current)" | sed -nE 's|^[a-z]+/([0-9]+)-.*|\1|p')"
if [ -n "$ISSUE" ]; then
  sed "s/{{ISSUE}}/$ISSUE/g; s/{{CONVERSATION_LINK}}//" \
    "$CLAUDE_PLUGIN_ROOT/skills/ticket/templates/pr-body.md" > /tmp/pr-body.md
  gh pr create --body-file /tmp/pr-body.md --title "<type>(<scope>): <subject>" 2>/dev/null \
    || gh pr view
else
  gh pr create --fill 2>/dev/null || gh pr view    # No issue encoded — fall back to --fill
fi
```

Work commit is separate from bump commit — clean git history.

#### 7e. Resolve Tracking Issue

> **Both pipelines below are experimental, off by default, and mutually exclusive — enable one, not both.** `PDS_DIARY=1` posts a diary as an issue *comment* (unchanged, original behavior). `PDS_EVOLVING_BODY=1` rewrites the issue *body* into a populated finish-writeup, preserving the prior body as a comment first (#154/#156 — see `docs/adr/0009-evolving-body-issue-and-slim-pr-format.md`). The evolving-body pipeline internally reuses the diary pipeline's data-gathering, so running both would post the same dev-diary content twice, once as a standalone comment and once inside the rewritten body. Prefer `PDS_EVOLVING_BODY=1` for issues created via the current `/pds:ticket` (7-section template) — `PDS_DIARY=1` remains for issues that predate that format and don't have sections to carry forward. Without either flag, skip straight to Cleanup.

```bash
case "${PDS_DIARY:-}${PDS_EVOLVING_BODY:-}" in
  *1*|*on*|*true*|*yes*) ;;
  *) echo "dev-diary and evolving-body both disabled (set PDS_DIARY=1 or PDS_EVOLVING_BODY=1)"; exit 0 ;;
esac
```

Parse the issue number from the branch name. The canonical pattern is `<type>/<issue>-<slug>` (see `/pds:worktree` issue-tied creation):

```bash
BRANCH="$(git branch --show-current)"
ISSUE="$(echo "$BRANCH" | sed -nE 's|^[a-z]+/([0-9]+)-.*|\1|p')"
```

**Legacy branches (no issue encoded).** If `$ISSUE` is empty:

1. Prompt the user: "This branch doesn't encode a tracking issue. Issue number for the diary, or `skip`?"
2. If they supply a number, rename the branch in place:
   ```bash
   NEW_BRANCH="<type>/<N>-$(echo "$BRANCH" | sed -E 's|^[a-z]+/||' | tr '/ ' '--')"
   git branch -m "$NEW_BRANCH"
   git push origin -u "$NEW_BRANCH" :"$BRANCH" 2>/dev/null || git push origin -u "$NEW_BRANCH"
   BRANCH="$NEW_BRANCH"; ISSUE="<N>"
   ```
3. If they say `skip`, proceed with an empty `$ISSUE`; both steps below are skipped with a note.

#### 7f. Post Dev Diary (`PDS_DIARY=1` only)

If `$ISSUE` is set and `PDS_DIARY=1`, invoke the diary assembler:

```bash
BRANCH="$BRANCH" ISSUE="$ISSUE" MODE=post bash "$CLAUDE_PLUGIN_ROOT/scripts/assemble-diary.sh"
```

The script:
- Derives a Summary from commit subjects, a Timeline from commit timestamps, and "What went well / wrong" from instincts, auto-memory, commit signals (fixups/reverts), and ★ Insight blocks parsed out of the raw transcript.
- Wraps the full `export-session.sh` output inside a collapsed `<details>` block.
- Looks up an existing diary comment on the issue by a stable `<!-- pds:diary -->` marker. If found, edits in place; otherwise posts a new comment (single canonical comment per issue).
- On `gh` failure, writes the assembled document to `$TMPDIR/pds-diary-<issue>-<ts>.md` and surfaces the path. Never silently swallows.

If `$ISSUE` is empty (user chose `skip`), skip this step and report it plainly.

#### 7g. Rewrite Evolving Body (`PDS_EVOLVING_BODY=1` only)

If `$ISSUE` is set and `PDS_EVOLVING_BODY=1`, invoke the finish-writeup assembler:

```bash
BRANCH="$BRANCH" ISSUE="$ISSUE" MODE=post bash "$CLAUDE_PLUGIN_ROOT/scripts/assemble-finish-writeup.sh"
```

The script:
- Fetches the issue's current body and posts it as a comment first — `### Kickoff (preserved)` the first time this issue goes through a rewrite, `### Snapshot (preserved) — <date>` on every rewrite after that. **Never overwrites the body without preserving what was there.**
- Carries forward Decisions, Risks, Acceptance Criteria, and Full Plan verbatim from the old body — these may already reflect mid-flight edits (checkbox flips, appended risks) per `/pds:ticket` section 3, and this step must not clobber that.
- Recomputes TL;DR as the final-outcome summary (not the kickoff intent) and populates Dev Diary + Full Conversation for the first time, reusing `assemble-diary.sh`'s data-gathering internally (dry-run, no side effects from that inner call).
- If the assembled transcript exceeds ~60k chars, commits it to `docs/conversations/<date>-<issue>-<slug>.md` and links it instead of embedding inline.
- On `gh` failure, writes the assembled writeup to `$TMPDIR/pds-finish-writeup-<issue>-<ts>.md` and surfaces the path. If the preserve-comment post itself fails, stops before touching the body — the old content is never lost.

If `$ISSUE` is empty (user chose `skip`), skip this step and report it plainly.

## Cleanup

After the branch is merged:

- [ ] Remove the worktree: `git worktree remove .worktrees/branch-name`
- [ ] Delete the branch: `git branch -d branch-name`
- [ ] Close related issues
- [ ] Update task status via TaskUpdate if working as a team agent

## When to Use

| Situation | Skill |
|-----------|-------|
| Formal ship: verify, rebase, clean, bump, push | `/finish` |
| Quick ship: bump, commit, push | `/pds:checkpoint` |
| Version bump only (no push) | `/pds:bump` |
| Verify before shipping | `/pds:verify` then `/finish` |

## After Shipping

After shipping, consider running `/pds:pause` — shipping is a natural break point. It saves session state so you can resume cleanly in the next session.

## See Also

- `/pds:bump` — version bump details
- `/pds:verify` — completion self-check (step 1)
- `/pds:pause` — save session state before stepping away
- `/pds:ticket` — owns the kickoff body this skill rewrites at ship time (step 7g)
- `docs/adr/0009-evolving-body-issue-and-slim-pr-format.md` — why the issue body gets rewritten and the PR stays slim
