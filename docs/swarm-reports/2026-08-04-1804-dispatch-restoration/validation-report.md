# Validation Report — #181 / #182 dispatch restoration

Branch: `fix/orchestrator-agent-namespace`
Commit: `4da0866`

## Note on method

This swarm ran solo. The bug under repair is the orchestrator's inability to
spawn agents, so no validator could be dispatched to validate it — the fix had
to bootstrap itself. Everything below was executed directly, and every claim is
backed by a command that ran, not by inspection.

## Static suites

| Suite | Result |
|---|---|
| `install.sh --test` | 90/90 pass (was 89 pre-change; +1 roster check, +1 worktree contract check) |
| `hooks/tests/test-worktree-hooks.sh` | 12/12 pass (new) |
| `hooks/tests/test-orchestrator-pr-gate.sh` | 8/8 pass |
| `hooks/tests/test-orchestrator-teardown-gate.sh` | 14/14 pass |
| `scripts/test-hooks.sh` | 25/25 pass |

## Negative tests — do the new guards actually catch the bugs?

A regression guard that has never failed is not a guard. Both were run against
deliberately reintroduced defects:

| Injected defect | `check-agent-roster.py` verdict |
|---|---|
| Bare-name allowlist `Task(researcher, worker, ...)` | rejected — "un-namespaced entries [...] empty the entire spawn roster (#181)" |
| Namespaced allowlist with `pds:shepherd` removed | rejected — "agents present on disk but absent from the orchestrator allowlist: ['shepherd']" |
| Correct allowlist | pass |

`test-worktree-hooks.sh` case 8 is an explicit named guard against #170's exact
shape: exit 0 with empty stdout on a valid payload.

## Live dispatch verification

Run headlessly against the real installed plugin with the fix staged, parsing
`--output-format stream-json` tool results rather than model narration — the
first two probe rounds in this session showed a model confidently reporting
success for a spawn whose tool result was an error, so narration was discarded
as evidence throughout.

| Probe | Before | After |
|---|---|---|
| `Agent(subagent_type='researcher')` | `not found. Available agents:` (empty) | n/a — bare name, correctly still invalid |
| `Agent(subagent_type='pds:researcher')` | `not found. Available agents:` (empty) | spawned, returned `R_OK` |
| `Agent(subagent_type='pds:worker')` | `not found` → then `WorktreeCreate hook failed` | spawned, returned `W_OK`, worktree at `.worktrees/agent-a76d7ea488f3c20cd` |

The intermediate state matters: after the #181 fix alone, `pds:worker` stopped
failing with "not found" and started failing with "WorktreeCreate hook failed."
That change in error shape is what isolated #182 as a genuinely separate defect
rather than a lingering symptom of the first.

## Contract capture (#182)

The `WorktreeCreate` contract was measured, not assumed, by swapping in an
instrumented hook and spawning a real worker:

```
PWD=/Users/rmzi/dev/tools/portable-dev-system        <- main repo, no worktree yet
stdin={"session_id":"...","cwd":"/Users/rmzi/dev/tools/portable-dev-system",
       "agent_type":"pds:orchestrator","hook_event_name":"WorktreeCreate",
       "name":"agent-a82e29b9ac3d6a485"}
```

This directly falsifies the premise of the v5.0.0 fix for #170 ("Claude Code
already switched into the worktree before firing this hook").

## Cleanup

All probe worktrees removed; `.worktrees/` empty; `git worktree list` shows the
main checkout only. Scratch fixtures live under `$TMPDIR`, nothing committed.

## Not verified

- `WorktreeRemove` was unit-tested against synthetic payloads but not observed
  firing live — the probe worktree persisted after session end and was removed
  manually. The real payload shape for that event is inferred from the binary's
  `worktreePath` symbol, so the hook accepts both `worktreePath` and `name`.
- `scripts/smoke-dispatch.sh` was authored against the same probe mechanics used
  successfully throughout, but has not itself been run end to end — it targets a
  throwaway repo whose spawns would resolve against the *published* plugin, which
  will not carry this fix until the PR merges and the plugin updates. It is a
  post-merge verification tool by construction.
- `--all` tier (validator, reviewer, documenter, scout, auditor, shepherd) not
  individually spawned. They share `pds:researcher`'s non-worktree spawn path and
  are all covered by the roster check; only `pds:worker` declares
  `isolation: worktree`, and that path was verified directly.
