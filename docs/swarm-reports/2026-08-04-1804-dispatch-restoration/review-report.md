# Review Report — #181 / #182 dispatch restoration

Branch: `fix/orchestrator-agent-namespace` · Commit: `4da0866`

## Scope

21 files. Two one-line-class root causes, a rewritten hook, a new hook, three
test artifacts, and doc propagation.

## Correctness

**#181 — allowlist namespacing.** The fix is a rename, and the risk in a rename
is missing a site. `grep -rn "Task("` across `skills/`, `agents/`, and `docs/`
was used to enumerate every occurrence, and each was either updated or
consciously left: `docs/conversations/` and `docs/swarm-reports/` are historical
transcripts and were deliberately not rewritten — falsifying a record of what
was said at the time would be worse than leaving a stale example in an archive.
`docs/adr/0002` mentions `Task(researcher, strict=true, ...)` inside a
"rejected alternative" section; also left, for the same reason.

`scripts/check-agent-roster.py` derives the expected set from the filesystem
rather than a hardcoded list, so a future agent added to `agents/` fails the
check until it is wired into the allowlist. That is the property that would have
caught `pds:shepherd`, which had simply been forgotten.

**#182 — worktree hook.** The rewrite inverts the script's responsibility, so it
was reviewed against the failure modes that inversion introduces:

- *Optional work suppressing required output* — this was the original bug's
  shape. The path is now printed at line ~72, before any symlink logic, and
  every subsequent step exits 0 without affecting stdout. Test case 5 pins this.
- *Untrusted-payload path traversal* — `remove-agent-worktree.sh` runs
  `git worktree remove --force`, which deletes files, against a path taken from
  hook stdin. Constrained to `$REPO_ROOT/.worktrees/*` with an explicit `case`
  guard; test case 11 asserts a path outside that prefix survives.
- *Failing a session over cleanup* — the remove hook exits 0 on every path.
- *Branch-name collision* — `worktree add -b` falls back to `--detach`.
- *Repo-root resolution from inside a worktree* — uses `--git-common-dir`, not
  `--show-toplevel`, per the CLAUDE.md rule. Relevant because the spawning agent
  may itself already be in a worktree.
- *Timeout* — raised 5s → 30s, since the hook now does `git worktree add` rather
  than a symlink. 5s would have been a flaky failure on a large repo.

## Process observations

**The static suite passed through both bugs, twice.** That is the finding worth
carrying forward, and it is why this branch adds `scripts/smoke-dispatch.sh`
rather than only another assertion. Both defects were violations of *Claude
Code's* contract, not PDS's — no amount of self-consistency checking reaches
them. The new CI job raises the floor; only the live probe touches the ceiling,
and it cannot run in CI, so `/pds:finish` and `/pds:contribute` now name a human
as the enforcement mechanism. That is a real, acknowledged weak point, not a
solved problem.

**#171 is a cautionary case.** It diagnosed this exact symptom one layer too
high, concluded named-teammate nesting was the blocker, shipped a plausible
remedy, and closed. The remedy was correct on its own terms and changed nothing
about the failure. The generalizable error: the platform's error text was read
as an explanation rather than as one more thing to verify. Both root causes here
were instead pinned by measurement — differential headless probes for #181, an
instrumented hook capturing the live payload for #182.

**Model narration was discarded as evidence.** An early probe in this session
reported a spawn as successful whose underlying tool result was an error. Every
subsequent verification parsed `--output-format stream-json` tool results
directly. Worth institutionalizing: `smoke-dispatch.sh` is built this way.

## Concerns carried forward

1. `WorktreeRemove` is unit-tested but never observed firing live; the probe
   worktree persisted past session end. The payload shape is inferred. If
   worktrees still leak post-merge, that hook is where to look.
2. `smoke-dispatch.sh` is unrun end to end — it necessarily resolves against the
   *published* plugin, so it cannot pass until this merges. First real exercise
   is post-merge. Filed as a follow-up rather than blocking.
3. The installed plugin cache was hand-patched during this session to make live
   verification possible. It must be refreshed after merge or a stale cache will
   keep masking the state of the repo — noted in the PR body.
4. `docs/teams.md` and `docs/whitepaper.md` still say "8 agents" where the roster
   is 9 (shepherd). Pre-existing, unrelated to dispatch, deliberately out of
   scope. Worth its own small issue.

## Verdict

Approve. Root causes are measured rather than inferred, both fixes are verified
by live spawn, the guards were shown to fail on reintroduced defects, and the
limits of what was verified are stated rather than papered over.
