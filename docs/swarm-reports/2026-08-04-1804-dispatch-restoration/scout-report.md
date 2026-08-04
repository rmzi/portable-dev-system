# Scout Report — #181 / #182 dispatch restoration

Merged: `becbb3a` (squash) · v5.1.1 · PR #183

## What was actually wrong

Four defects, all one root cause wearing different clothes: **PDS agents ship in
a plugin and therefore register as `pds:<name>`, but three separate places in
the codebase matched them by bare name.**

| Site | Effect | Severity |
|---|---|---|
| `agents/orchestrator.md` `Task(...)` allowlist | Zero matches → roster emptied → **no agent could spawn at all** | fatal |
| `hooks/scripts/roster-check.sh` | Warned on every valid spawn, silent on invalid ones — inverted signal | noise |
| Docs saying "8 agents" | Shepherd invisible in prose | cosmetic, but see below |
| `hooks/scripts/sync-worktree-permissions.sh` | Separate bug: hook never created the worktree it was responsible for | fatal |

The cosmetic one is not cosmetic. The shepherd was the agent missing from the
allowlist, missing from the roster-check hook, and missing from every documented
count. The wrong number is *how* an entire agent stayed unnoticed across two
releases.

## Patterns worth keeping

**1. An empty list in an error message is a signal, not an absence.**
`Available agents:` with nothing after the colon read as "the plugin failed to
load." It actually meant "your filter matched zero things, so I discarded the
whole set." Whenever a system reports emptiness where you expected a subset,
suspect the filter before suspecting the source.

**2. Differential probing beats reading code.** Both root causes were pinned by
constructing minimal variants and comparing outcomes — plugin-scope vs
project-scope agents, filtered vs unfiltered `Task`, bare vs namespaced names.
Reading `orchestrator.md` a fourth time would not have revealed which of the
four plausible explanations was true.

**3. Never accept the model's account of a tool result.** An early probe in this
session reported a spawn as successful whose underlying tool result was an
error. Every verification afterward parsed `--output-format stream-json`
directly. `scripts/smoke-dispatch.sh` is built on that discipline, and it should
be the default for any future capability check.

**4. A changed error message is progress, and often a second bug.** After the
allowlist fix, `pds:worker` stopped failing with `not found` and began failing
with `WorktreeCreate hook failed`. Treating that as "still broken" would have
merged one fix and shipped the other defect. The shape of a failure is data.

**5. Verify the premise, not just the conclusion.** #170's fix rested on
"Claude Code switches into the worktree before firing this hook." Nobody checked.
One instrumented hook falsified it in a single spawn. #171 made the same class of
error, reading the platform's error text as an explanation rather than as another
claim to test.

**6. Registering a hook can take ownership you didn't intend to accept.**
`sync-worktree-permissions.sh` existed to symlink a settings file. By existing at
all it displaced Claude Code's native worktree creation and then created nothing.
When a platform offers a hook, establish whether it observes or replaces.

## Process finding — the one that generalizes

**Both fatal bugs shipped through a fully green test suite, twice.** Neither was
detectable by any self-consistency check, because the contract being violated
belonged to Claude Code, not PDS. PDS was internally coherent and totally
non-functional at the same time.

The structural response is the three-layer guard now in place:

- static, CI: `check-agent-roster.py`, `test-worktree-hooks.sh`,
  `test-roster-check.sh`, `check-workflows.py`
- live, human: `scripts/smoke-dispatch.sh`, required by `/pds:finish` and
  `/pds:contribute`

Every static guard was verified by reintroducing its defect and watching it fail.
A guard that has never failed is not known to be a guard.

The live layer cannot run in CI — it needs an authenticated `claude`. That human
step is the weakest link in the chain and is documented as such rather than
papered over.

## Self-referential finding

A CI step added *in this changeset*, to guard against this very bug class, was
named `- name: SubagentStart roster check handles pds: namespace`. The colon+space
broke YAML parsing. GitHub reported only "workflow file issue" with no line
number and skipped every job — so the PR's check list went **empty rather than
red**. A typo in a regression guard silently disabled the suite it belonged to,
and the empty-vs-red distinction is the same perceptual trap as bug #1.

`scripts/check-workflows.py` now catches it, and degrades gracefully when PyYAML
is unavailable, per Portability of Operation.

## Verification of record

`smoke-dispatch.sh --all` against the published v5.1.1 plugin: **8/8 agent types
spawn** — researcher, worker, validator, reviewer, documenter, scout, auditor,
shepherd. `.worktrees/` clean afterward. `install.sh --test` 92/92. Main CI green
at `becbb3a`.

## Follow-ups

- `WorktreeRemove` is unit-tested but its live payload shape is still inferred;
  the hook accepts both `worktreePath` and `name` defensively. Revisit if
  worktrees leak.
- Worth an issue: audit every remaining place PDS matches an agent name, skill
  name, or plugin resource by string, for the same namespace assumption.
