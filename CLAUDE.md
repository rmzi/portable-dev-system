<!-- PDS:START -->
# Portable Development System

AI-assisted development methodology. Skills for consistency. Agents for scale.

## Plugin Architecture

PDS is a Claude Code plugin. Skills and agents are distributed via the plugin system. Security settings are installed to `~/.claude/settings.json`.

### Workflow

1. **At session start**: PDS plugin loads automatically (skills, agents, hooks)
2. **Before any task**: Check if a PDS skill exists for it — if so, read it first
3. **During work**: Follow skill documentation before performing actions
4. **When stuck**: Run `/pds:ethos` for principles, `/pds:grill` for structured thinking

### Rule

**Before performing ANY action, check if a skill exists for it. If a relevant skill exists, read it FIRST.**

### Available Skills (19)

| Skill | When to Use |
|-------|-------------|
| `/pds:swarm` | Launch agent team for parallel work (includes branch merging) |
| `/pds:team` | Agent roster, roles, capabilities, dispatch modes |
| `/pds:grill` | Requirement interrogation before implementation |
| `/pds:verify` | Completion self-check before declaring done |
| `/pds:finish` | Branch completion protocol for merge readiness |
| `/pds:checkpoint` | Quick ship: bump, commit, push (when finish protocol isn't needed) |
| `/pds:worktree` | Branch isolation, parallel work |
| `/pds:contribute` | Contributing to PDS itself — whitepaper alignment |
| `/pds:bugfix` | Test-first bug fix loop |
| `/pds:bump` | Version bump and changelog update |
| `/pds:eval` | Test whether skills produce correct agent behavior |
| `/pds:rebase` | Focused rebase against target branch |
| `/pds:pr-review` | Address PR review comments systematically |
| `/pds:pause` | Save session state, WIP commit, resume later |
| `/pds:triage` | Triage insights into GitHub issues across repos |
| `/pds:ethos` | Core development principles — grounding ritual |
| `/pds:instinct` | Pattern lifecycle — record, validate, promote recurring patterns |
| `/pds:export` | Export session to human-readable markdown |
| `/pds:explore` | Structural codebase queries via codebase-memory-mcp index (fallback to Grep) |

See `/pds:team` for the 9-agent roster (orchestrator, researcher, worker, validator, reviewer, documenter, scout, auditor, shepherd). The **shepherd** is a persistent substantive advisor (opus) spawned after Phase 1 grill in med/heavy tiers — advisory-only, enforces the whitepaper/philosophy/ethos by citation.

---

## Project Structure

```
.claude-plugin/    — Plugin manifest (plugin.json)
agents/            — 9 agent definitions + shared-rules.md
skills/            — 19 workflow skills (dir/SKILL.md format)
hooks/             — Quality gates (SessionStart, Stop, TaskCompleted, TeammateIdle, SubagentStart, PreCompact, PostCompact, UserPromptSubmit, PostToolUse, WorktreeCreate, InstructionsLoaded)
scripts/           — Utility scripts (telemetry-summary, detect-patterns)
cli/               — Rust CLI (`pds sync`, `pds config get`, `pds archive`, `pds doctor`)
config-presets/    — Shipped permission presets (pds-default, dev-tools) — referenced from pds.config.yaml
examples/          — Example pds.config.yaml
terraform/         — S3 + Deep Archive lifecycle module + one-command apply root
.claude/           — Security settings (deny rules, sandbox config) — optional per-project
.claude/swarm/     — Active swarm state (phase, tier, checkpoint.json, reports) — runtime only
docs/              — Philosophy, whitepaper, team setup
docs/swarm-reports/ — Archived swarm artifacts (post-cleanup, per-swarm timestamped dirs)
install.sh         — Plugin installer + security settings
VERSION            — Current version (semver)
CHANGELOG.md       — Release history
```

---

## Rules

### Worktree Hygiene

Use `git worktree add` for branch isolation — never `git clone` (clones disconnect history).

- Always inside repo: `.worktrees/feature-branch/`
- Never `/tmp/`, never `../` siblings
- Always resolve REPO_ROOT first (relative paths nest incorrectly inside worktrees):
  ```bash
  REPO_ROOT="$(git rev-parse --path-format=absolute --git-common-dir | sed 's|/.git$||')"
  git worktree add "$REPO_ROOT/.worktrees/name" -b branch
  ```
- Never use `git rev-parse --show-toplevel` (returns worktree root, not repo root)

### Workflow

**Read `/pds:contribute` before modifying PDS.** Skills, agents, SDLC phases, or coordination patterns require the whitepaper-alignment checklist.

**Create or update a PR after pushing.** Don't wait to be asked.

### Protected Branches

Protected branches are declared in `pds.config.yaml` under `worktree.protected_branches`. `/pds:finish` reads the list via `pds config get worktree.protected_branches` and prompts for confirmation before pushing to a matching branch. GitHub branch protection rules are the server-side enforcement — this is the client-side "are you sure?" prompt.

To configure: edit `${XDG_CONFIG_HOME:-~/.config}/pds/config.yaml` and run `pds sync`.

### User preferences (`pds.config.yaml`)

Portable user preferences — permissions, health thresholds, plugin list, MCP servers, worktree cleanup policy — live in `${XDG_CONFIG_HOME:-~/.config}/pds/config.yaml`. Keep it in your personal dotfiles repo; `pds sync` fans it out to `~/.claude/settings.json`, `~/.claude.json`, global gitignore, and per-project seeds. See `docs/config.md` for the full schema.

<!-- PDS:END -->

---

## General Rules

- When asked to set a tool, editor, or config to a specific value, use EXACTLY what is specified. Do not substitute alternatives.
- Never fabricate answers or claim something is a known issue without verifying first. If you don't know, say so and offer to look it up.
- Don't refuse non-code tasks. Help with macOS, hardware setup, and general tech questions.

## Frontend / CSS

- For mobile/responsive CSS fixes, make aggressive changes on the first attempt. Font sizes, padding, and layout changes should be substantial — overshoot and dial back rather than iterating 5+ times.

## Development Workflow

- Always run commands in the correct project directory. Before running `npm install`, `expo prebuild`, or any build command, verify you're in the right directory with `pwd`.

## Troubleshooting

- Exhaust documentation and actual verification before hypothesizing. Fetch docs with WebFetch rather than guessing at configs or APIs.
