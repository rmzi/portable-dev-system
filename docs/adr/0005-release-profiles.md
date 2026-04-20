# ADR 0005: Release Profiles — Declarative Release Methodology

## Status
Proposed

## Context

PDS has no first-class concept of "release." `/pds:checkpoint` and `/pds:finish` both end at `git push`. Nothing expresses, per project, how the code at `origin/main` becomes a live, consumable artifact.

For PDS itself, the consequence is a recurring drift bug. The marketplace cache keys on `marketplace.json`'s version field, but `/pds:bump` only updates `VERSION` and `plugin.json`. Marketplace drifted twice that we know of: fixed manually in 4.11.1 ("Synced all co-located version files") and again in 4.13.1 ("Sync marketplace.json version with project version") — both as point interventions rather than systemic prevention. The drift is silent because there is no schema to check against.

More broadly: every project has a different release methodology. PDS publishes as a plugin marketplace entry. An npm package publishes via `npm publish`. A Vercel app deploys on push. A GitHub-hosted CLI cuts releases. PDS should be able to assist with each without forking a skill per project type.

### What exists elsewhere

All ecosystems that got this right separate **methodology** (shared) from **instantiation** (per-project):

| System | Shared methodology | Per-project declaration |
|--------|-------------------|-------------------------|
| GitHub Actions | Reusable workflows (`uses: org/repo/.github/workflows/foo.yml@v1`) | Workflow file that `uses` a shared ref |
| CircleCI | Orbs (packaged, versioned config fragments) | `orbs: foo: org/foo@1.0` |
| Google Release Please | Release strategies per language | Repo-level config naming the strategy |
| semantic-release | Plugins (@semantic-release/git, /github, /npm) | `.releaserc` declaring plugin list |

PDS currently has neither layer.

### The gap

```
Code changes  →  /pds:checkpoint or /pds:finish  →  git push  →  (project-specific nothing)
```

What's missing: a declarative statement of *what makes this project released*, and a shared library of methodologies that most projects can adopt by name.

## Decision

Introduce two artifacts:

1. **Project declaration**: a `## Release` section in each project's CLAUDE.md, naming the profile and listing any per-project specifics.
2. **Profile registry**: `docs/release-profiles/<name>.md` in PDS, each file defining one named methodology (version-file list, post-push steps, validation rules).

Skills read both. The declaration is small; the methodology is shared.

### Schema: `## Release` section in CLAUDE.md

```markdown
## Release

Profile: <profile-name>

Version files (must stay in sync):
- <path>
- <path> (`<jq-path-into-json>`)

Post-push:
- <description>: <shell command, can use $VERSION>
- <description>: <another command>

Validation:
- <optional project-specific precondition>
```

Rules:
- `Profile:` line is required and names a file in `docs/release-profiles/`.
- `Version files:` list overrides the profile's default. Omit to inherit the profile's list as-is.
- `Post-push:` entries append to (not replace) the profile's post-push steps. Explicit `Post-push: (none)` suppresses all.
- `Validation:` entries are additional preconditions specific to this project.

### Schema: `docs/release-profiles/<name>.md`

```markdown
# Profile: <name>

## Use when
<One-paragraph description of the project shape this profile fits.>

## Required project files
- <path> — <what it must contain>

## Bump behavior
<How version is incremented across declared files. Explicit about which keys/fields.>

## Post-push steps
1. <description>: <command>
2. ...

## Validation
- <invariant that must hold pre- or post-bump>

## Extends (optional)
<name-of-another-profile>
```

Profile composition: a profile can `Extends:` another. Post-push steps concatenate (base first, then derived). Version files merge by path (derived wins on conflict).

### Integration with existing skills

| Skill | Change |
|-------|--------|
| `/pds:bump` | Reads `## Release` section for version-file list. Updates all declared files atomically. Falls back to legacy `VERSION`+`package.json` detection if no section present. Refuses to bump if any declared file is missing — drift detection at source. |
| `/pds:checkpoint` | Unchanged. Stays lightweight: bump + commit + push. No publish side effects. Use for routine feature commits that should not trigger release artifacts. |
| `/pds:finish` | Gains Step 7 (Publish). Reads Release section, executes profile's post-push steps in order, prompting per-command for confirmation. No Release section → publish step is a no-op. |
| `/pds:init` (new) | Project-type detection (signals: `.claude-plugin/plugin.json` → `claude-plugin-marketplace`; `package.json` → `npm-package` or `github-release-only`; `vercel.json` → `vercel-auto-deploy`). Offers matching profile, prompts for confirmation, appends Release section. Also generates `.claude/settings.json` stub and optionally adds Protected Branches section. |

### Profile catalog (initial)

| Name | Shape |
|------|-------|
| `claude-plugin-marketplace` | Bumps VERSION + plugin.json + marketplace.json. Post-push: tag as `v$VERSION`, push tags. No GitHub release required. |
| `npm-package` | Bumps package.json (+ package-lock.json). Post-push: tag, optionally `npm publish` (gated on `NPM_PUBLISH=1` env). |
| `github-release-only` | Bumps VERSION. Post-push: `gh release create v$VERSION --generate-notes`. |
| `vercel-auto-deploy` | Bumps package.json. Post-push: (none) — Vercel webhook handles deployment. Validation: confirm vercel.json exists. |
| `static` | Bumps VERSION. Post-push: (none). For projects where "released" equals "on main." |

Profiles compose. Example: a project that's *both* a Vercel app and wants a GH release can use `vercel-auto-deploy` and add a Post-push line to create the release, or `Extends: vercel-auto-deploy` from a new project-local profile.

### Rollout phases

| Phase | Deliverable | Gate |
|-------|-------------|------|
| 1 | This ADR (schemas + rationale) | User review / approval |
| 2 | `docs/release-profiles/claude-plugin-marketplace.md`. Append `## Release` section to PDS's own CLAUDE.md. Fix marketplace.json drift by bumping manually as test of the schema. | Schema survives one real use |
| 3 | Teach `/pds:bump` to read Release section. Refactor to use declared file list. | Existing bump test still passes; new drift guard works |
| 4 | Add Publish step to `/pds:finish`. Per-command confirmation prompts. | Dogfooded through at least one PDS release |
| 5 | Author `/pds:init` skill. Project-type detection + ceremony. | Tested against at least two project types |
| 6 | Expand profile registry: `npm-package`, `github-release-only`, `vercel-auto-deploy`, `static`. Each validated against a real project. | Each profile has a reference project |

## Consequences

### Positive
- Drift eliminated at source. `/pds:bump` refuses to proceed if declared version files are inconsistent or missing.
- Per-project release methodology expressible without forking a skill per project type.
- PDS adoption becomes ceremonial (`/pds:init`) rather than accidental.
- Profile registry evolves independently of the skill layer — adding a new methodology is a doc file + optional validation, not a skill rewrite.
- Release step becomes reviewable: `git diff` on CLAUDE.md shows what "released" means changed.

### Negative
- New config surface. Schema drift between CLAUDE.md Release sections and profile registry is possible.
- LLM executes shell commands declared in profile files. Attack surface even if the files are in PDS itself — a malicious PR to a profile could inject commands.
- Profile composition (`Extends:`) adds conceptual weight. Over-use will recreate the mess the profile system exists to solve.
- Adoption requires each existing project to add a Release section. Legacy fallback softens this but creates a "some projects have it, some don't" split.

### Mitigations
- Profile files live in PDS itself and are subject to normal PR review. Document the security expectation in the profile schema itself.
- `/pds:finish` Publish step prompts for confirmation per profile-declared command. Never silent execution.
- Profile schema is intentionally small. No conditionals, no loops — if a project needs more, it writes a project-local script and declares it in Post-push as a single command.
- Legacy fallback in `/pds:bump` is kept indefinitely. Projects opt in when the value is visible.

## Alternatives considered

### A. Single YAML/TOML file per project (`.pds/release.yml`)

Pros: schema clarity; standard parsers; no LLM interpretation required.
Cons: new file type to maintain alongside CLAUDE.md; breaks the established pattern of declarative sections in CLAUDE.md (Protected Branches); humans less likely to read it than a markdown section.

Rejected: consistency with `Protected Branches` is more valuable than parser strictness, given LLM-mediated execution.

### B. Standalone shell scripts per project (`scripts/release.sh`)

Pros: fully general; no schema to learn.
Cons: no shared methodology — every project reinvents its release script; no validation; no drift detection.

Rejected: this is the status quo and is the reason drift exists.

### C. Defer entirely to CI/CD (GitHub Actions, etc.)

Pros: leverages existing ecosystem; separates concerns.
Cons: hides methodology from PDS-mediated workflows; no local shipping flow; assumes every project has CI, which not all do.

Rejected as sole mechanism, accepted as composable: profiles can declare post-push steps that trigger workflows (`gh workflow run`). Profiles and CI are not mutually exclusive.

### D. Inline release spec in each skill

Put the release methodology inside `/pds:finish` itself, branching on project type.

Rejected: this is exactly the skill fork per project type that the profile system exists to prevent. Would not survive the fourth project type.

## Open questions

1. **Profile versioning.** Should profiles be versioned (`Profile: npm-package@2`)? Needed if breaking changes occur, but adds complexity. Defer until a breaking profile change is actually required.
2. **Per-environment profiles.** Some projects distinguish staging vs prod releases. Current schema is single-track. Expressible via a second profile (`Profile-staging:`)? Deferred — add only when a real project needs it.
3. **Interaction with semantic-release / Release Please.** Projects already using these tools may want PDS to defer to them. A `Profile: semantic-release` that is effectively `Post-push: npx semantic-release` works, but validation becomes the tool's concern, not PDS's. Document but don't enforce.
4. **Secrets in post-push commands.** Commands like `npm publish` may require tokens. Profile schema says nothing about secret injection. Current assumption: secrets live in the shell environment; PDS's job is execution, not secret management. Revisit if this breaks down.
5. **Rollback.** Profile schema has no "undo a release" concept. Most systems (marketplace, npm) treat releases as immutable. Document the expectation; don't try to generalize.
