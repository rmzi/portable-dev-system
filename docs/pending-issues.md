# Pending Issues from Skill Consolidation Review (#131)

File these after `gh auth login -h github.com`:

```bash
# 1. (RESOLVED) Ledger was cut from PDS entirely — PDS lives standalone with no federation deps.
#    See commit removing ~/.ledger references from hooks; original issue was obsolete.

# 2. Eval-driven trim skill redesign
gh issue create --title "Eval-driven trim skill redesign" --label "enhancement" --body "## Context

Pruned \`/pds:trim\` skill during consolidation (#131). The skill had good intent (context efficiency for PDS artifacts) but lacked evidence that it produced correct behavior.

## What's needed

1. **Define eval criteria** — What does correct trim behavior look like?
2. **Write EVAL.md** — Rubric with pass/fail scenarios before reimplementing
3. **Reimplement with eval coverage** — Only ship if eval pass rate meets threshold

## Principle

Don't ship skills without evidence they work. The original trim was removed because we couldn't verify it produced value.

## Origin

Skill consolidation review — user verdict: keep deleted, redesign with eval-first approach."

# 3. Credential-path safety guardrail
gh issue create --title "Credential-path safety guardrail" --label "enhancement" --body "## Context

Pruned \`/pds:allow\` skill during consolidation (#131). The skill added paths to the sandbox write allowlist with a credential-path safety check. The safety check logic is still needed — the question is where it should live.

## What's needed

A guardrail that prevents adding credential-containing paths (e.g., \`~/.ssh\`, \`~/.aws\`, paths containing secret, credential, token) to the sandbox write allowlist.

### Options (TBD)
1. **Hook** (PreToolUse) — Intercept sandbox config changes and block credential paths
2. **Skill** — Restore as a focused skill that wraps settings.json edits
3. **install.sh check** — Add credential-path validation to the installer

## Origin

Skill consolidation review — user verdict: keep allow deleted, file issue for the safety guardrail."

# 4. install.sh --verify for config auditing
gh issue create --title "install.sh --verify for config auditing" --label "enhancement" --body "## Context

Pruned \`/pds:audit-config\` skill during consolidation (#131). The skill verified sandbox settings, deny rules, and autoMode config. This verification should be accessible as a CLI flag rather than requiring an active Claude session.

## What's needed

Add \`--verify\` flag to \`install.sh\` that:
1. Checks sandbox is enabled with correct defaults
2. Validates deny rules cover credential paths and protected branches
3. Confirms autoMode config is present (if applicable)
4. Verifies plugin structure integrity
5. Reports pass/fail with actionable fix suggestions

## Origin

Skill consolidation review — user verdict: keep audit-config deleted, absorb rubric into install.sh --verify."

# 5. Absorb preflight into swarm Phase 3 + SessionStart hook
gh issue create --title "Absorb preflight into swarm Phase 3 + SessionStart hook" --label "enhancement" --body "## Context

Pruned \`/pds:preflight\` skill during consolidation (#131). The skill validated the development environment before work began. This validation should happen automatically, not require manual invocation.

## What's needed

### SessionStart hook additions
- Check critical dependencies are available (git, gh, python3, jq)
- Verify sandbox is enabled and configured

### Swarm Phase 3 (Provision) integration
- Before spawning workers, validate environment can support the swarm
- Fail fast with actionable error if environment isn't ready

## Origin

Skill consolidation review — user verdict: keep preflight deleted, absorb into automatic hooks."

# 6. Finish: knowledge gathering on branch close
gh issue create --title "Finish: knowledge gathering on branch close" --label "enhancement" --body "## Context

During skill consolidation review (#131), \`/pds:checkpoint\` was restored as a separate skill from \`/finish\`. The user noted that \`/finish\` should gain knowledge-gathering capabilities.

## What's needed

Enhance \`/finish\` Step 0 to:
1. **Run instinct review** — Check if patterns should be recorded or promoted via \`/pds:instinct\`
2. **Memory distillation** — Auto-save 1-2 auto-memory entries capturing key decisions
3. **Scout integration** — Optionally trigger a lightweight scout analysis before closing

## Origin

Skill consolidation review — user verdict: finish gets knowledge gathering."
```
