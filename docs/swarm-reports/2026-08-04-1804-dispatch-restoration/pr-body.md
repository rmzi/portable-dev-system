## TL;DR

Agent dispatch was completely dead. Two independent defects, either one sufficient on its own to make every swarm undispatchable. Both shipped with a fully green test suite.

Fixed, verified by live spawn, and guarded three ways.

Closes #181
Closes #182

## #181 — the orchestrator could not spawn *any* agent

`agents/orchestrator.md` declared its spawn allowlist with bare names:

```yaml
- Task(researcher, worker, validator, reviewer, documenter, scout, auditor)
```

PDS ships its agents inside a plugin, and plugin-provided agents register as `pds:<name>`. The allowlist matched zero agents — and Claude Code's response to a zero-match allowlist is to empty the spawn roster *entirely*. Every spawn then failed with:

```
Agent type 'researcher' not found. Available agents:
```

Nothing after the colon. `general-purpose` gone too. That empty list is why this survived so long: it reads as "the plugin didn't load," not "the allowlist is misnamed."

Isolated with differential headless probes rather than inference:

| Probe `tools:` | `subagent_type` | Result |
|---|---|---|
| `[Read, Task]` unfiltered | `pds:researcher` | spawned |
| `[Read, Task(pds:researcher, helper)]` | `pds:researcher` | spawned |
| `[Read, Task(helper)]` — bare, *project*-scope agent | `helper` | spawned |
| bare-name allowlist, *plugin*-scope agents | `researcher` | **empty roster** |

So the parameterized `Task(a, b)` syntax works fine and was never at fault. Plugin agents resolve only as `pds:<name>`; project agents under `.claude/agents/` resolve bare. The orchestrator mixed the two conventions.

Also adds **`pds:shepherd`**, which was missing from the allowlist entirely despite `/pds:swarm` spawning it in Phase 1 — it would have failed even after the namespace fix.

## #182 — `pds:worker` still unspawnable

With #181 fixed, worker spawns stopped failing with "not found" and started failing with:

```
WorktreeCreate hook failed: hook succeeded but returned no worktree path
```

That change in error shape is what identified this as a separate defect rather than a leftover symptom.

**Registering a `WorktreeCreate` hook replaces Claude Code's native git worktree creation.** The hook is not notified that a worktree was made — it is the thing that makes it. Captured by swapping in an instrumented hook and spawning a real worker:

```
PWD=/Users/rmzi/dev/tools/portable-dev-system        <- MAIN REPO, no worktree yet
stdin={"cwd":"/Users/rmzi/dev/tools/portable-dev-system",
       "agent_type":"pds:orchestrator",
       "hook_event_name":"WorktreeCreate",
       "name":"agent-a82e29b9ac3d6a485"}
```

v5.0.0 closed #170 by printing `$(pwd)` behind a guard requiring `git rev-parse --git-dir` to contain `worktrees` — on the stated premise that "Claude Code already switched into the worktree before firing this hook." It does not. CWD is the main repo, `--git-dir` is plain `.git`, the guard never matched, and the script exited 0 with no stdout on every real firing. That is precisely the reported failure.

Worth stating plainly: the hook had never done anything but symlink `settings.local.json`. Purely by being registered, it took worktree creation away from Claude Code and then created nothing.

Now it owns the lifecycle properly — parses the payload, resolves the repo root via `--git-common-dir`, creates the worktree at `$REPO_ROOT/.worktrees/$name` per the in-repo hygiene rule, prints the path, *then* does the symlink as best-effort work that can never suppress the path. Plus the missing `WorktreeRemove` counterpart, since owning creation means owning teardown or leaking a worktree per worker.

## #181, third site — roster-check hook

`hooks/scripts/roster-check.sh` (a `SubagentStart` hook) matched `agent_type` against bare names too. Live spawns report `pds:<name>` — straight from a captured payload, `{"agent_type":"pds:orchestrator", ...}`. So it printed

```
[PDS] Warning: unknown agent type 'pds:worker' — not in PDS roster or Claude Code built-ins
```

on **every legitimate spawn**, while staying silent on genuinely unknown ones. Exactly inverted. It exits 0 unconditionally, so the cost was noise rather than broken dispatch — but it's the same root cause sitting in a second file, and it predated the shepherd and never listed it either.

Now strips the namespace before matching and derives the roster from the plugin's own `agents/` directory when `CLAUDE_PLUGIN_ROOT` resolves, so adding an agent requires no edit here. Static list retained as a fallback.

## Roster said 8; it's 9

`README.md`, `docs/teams.md`, `docs/whitepaper.md`, `docs/claude-code-extension-catalog.md`, `docs/claude-code-source-analysis.md` — all omitting the shepherd. The same agent missing from the spawn allowlist and from the roster-check hook. A stale count is how a whole agent stays invisible, so `check-agent-roster.py` now cross-checks documented counts *and* the hook's fallback list against `agents/` on disk. Both verified by reintroducing the drift.

## A guard that disabled the suite

Worth recording, since it happened inside this PR. A CI step was added named:

```yaml
- name: SubagentStart roster check handles pds: namespace
```

Colon+space ends a plain YAML scalar. `ci.yml` stopped parsing. GitHub reported only *"This run likely failed because of a workflow file issue"* — no line number, no job breakdown — and skipped every job, so the check list went **empty rather than red**. A typo inside a newly added regression guard silently disabled the entire suite it belonged to.

Fixed, and `scripts/check-workflows.py` added to catch the class. Real parse when PyYAML is importable, dependency-free lint otherwise, so the markdown/bash/python3/jq portability contract holds. Verified against the exact typo — it reports the line number GitHub wouldn't.

## Verification

Live, through a real headless orchestrator, parsing `stream-json` tool results — not model narration. An early probe in this session reported a spawn as successful whose underlying tool result was an error, so narration was discarded as evidence throughout.

- `pds:researcher` → spawned, returned `R_OK`
- `pds:worker` → spawned, returned `W_OK`, worktree at `.worktrees/agent-a76d7ea488f3c20cd`

Both new guards were run against deliberately reintroduced defects and rejected them:

- bare-name allowlist → rejected
- allowlist missing `pds:shepherd` → rejected
- hook exiting 0 with empty stdout → rejected (test case 8)

Suites: `install.sh --test` 92/92 · worktree hooks 12/12 · pr-gate 8/8 · teardown-gate 14/14 · secret-scrub 25/25.

## Preventing recurrence

The static suite passed through both bugs, twice. That is the actual problem, and one more assertion does not solve it — both defects violated *Claude Code's* contract rather than PDS's, and no amount of self-consistency checking reaches those.

- **`scripts/check-agent-roster.py`** — allowlist is `pds:`-namespaced, names nothing undefined, and covers every agent on disk. Derives the expected set from the filesystem, so a newly added agent fails until wired up.
- **`hooks/tests/test-worktree-hooks.sh`** — 12 cases pinning the `WorktreeCreate`/`WorktreeRemove` contract, including a named guard against #170's exact exit-0-with-no-output shape.
- **`scripts/smoke-dispatch.sh`** — the live one. Drives a real headless orchestrator against a throwaway git repo and asserts agents actually spawn. Default run covers both spawn paths (`pds:researcher` plain, `pds:worker` worktree); `--all` covers every type. Failure output names the specific cause and the file to check.
- **New `dispatch-contract` CI job** — runs the static guards, the roster-check and worktree hook suites, the workflow validator, and `install.sh --test` on every push and PR.
- **`/pds:finish` step 4 and `/pds:contribute` step 2** now require a human to run the live probe whenever a branch touches `agents/`, `hooks/`, or spawn syntax in `skills/`. It needs an authenticated `claude`, so CI cannot do it. That human step is a real weak point, named rather than hidden.
- **"Dispatch Is Load-Bearing"** section added to `CLAUDE.md`, with the namespacing rule and its empty-roster signature.

## Note on #171

#171 diagnosed this same symptom one layer too high — concluded named-teammate nesting was the blocker and removed `name=` from every spawn call. Spawns were failing before ever reaching that check. Its change remains correct on its own terms; it simply never restored dispatch. The generalizable error was reading the platform's error text as an explanation instead of as one more thing to verify.

## After merging

Refresh the installed plugin. The local cache was hand-patched during this session to make live verification possible, and a stale `~/.claude/plugins/cache/` copy will otherwise keep masking the state of the repo.

## Known gaps

- `WorktreeRemove` is unit-tested against synthetic payloads but never observed firing live; its payload shape is inferred, so the hook accepts both `worktreePath` and `name`. If worktrees still leak, look there first.
- `smoke-dispatch.sh` has not been run end to end — it resolves against the *published* plugin and so cannot pass until this merges. First real exercise is post-merge.
