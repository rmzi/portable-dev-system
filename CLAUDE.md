<!-- PDS:START -->
# Portable Development System

AI-assisted development methodology. Skills for consistency. Agents for scale.

## Plugin Architecture

PDS is a Claude Code plugin. Skills and agents are distributed via the plugin system. Security settings are installed to `~/.claude/settings.json`.

### Workflow

1. **At session start**: PDS plugin loads automatically (skills, agents, hooks)
2. **Before any task**: Check if a PDS skill exists for it — if so, read it first
3. **During work**: Follow skill documentation before performing actions
4. **When stuck**: Read `docs/ethos.md` for principles, `/pds:grill` for structured thinking

### Rule

**Before performing ANY action, check if a skill exists for it. If a relevant skill exists, read it FIRST.**

### Available Skills (14)

| Skill | When to Use |
|-------|-------------|
| `/pds:swarm` | Launch agent team for parallel work (includes branch merging) |
| `/pds:team` | Agent roster, roles, capabilities, dispatch modes |
| `/pds:grill` | Requirement interrogation before implementation |
| `/pds:verify` | Completion self-check before declaring done |
| `/pds:finish` | Branch completion protocol for merge readiness (includes quick ship) |
| `/pds:worktree` | Branch isolation, parallel work |
| `/pds:contribute` | Contributing to PDS itself — whitepaper alignment |
| `/pds:bugfix` | Test-first bug fix loop |
| `/pds:bump` | Version bump and changelog update |
| `/pds:eval` | Test whether skills produce correct agent behavior |
| `/pds:rebase` | Focused rebase against target branch |
| `/pds:pr-review` | Address PR review comments systematically |
| `/pds:pause` | Save session state, WIP commit, resume later |
| `/pds:triage` | Triage insights into GitHub issues across repos |

See `/pds:team` for the 8-agent roster (orchestrator, researcher, worker, validator, reviewer, documenter, scout, auditor).

---

## Project Structure

```
.claude-plugin/    — Plugin manifest (plugin.json)
agents/            — 8 agent definitions + shared-rules.md
skills/            — 14 workflow skills (dir/SKILL.md format)
hooks/             — Quality gates (SessionStart, Stop, TaskCompleted, TeammateIdle, SubagentStart, PreCompact, PostCompact, UserPromptSubmit, PostToolUse, WorktreeCreate, InstructionsLoaded)
scripts/           — Utility scripts (telemetry-summary, detect-patterns)
crates/            — Rust binaries (cg — code graph TUI browser)
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

No branches are protected by default. To protect branches, add patterns below. `/pds:finish` will prompt for confirmation before pushing to a matching branch. GitHub branch protection rules are the server-side enforcement — this is the client-side "are you sure?" prompt.

To configure, ask PDS to set up protected branches — it will prompt for each one individually.

<!-- Uncomment and add patterns:
- main
- master
- release/*
-->
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
