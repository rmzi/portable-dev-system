# Migration Guide: PDS v3.x → v4.0.0

PDS v4 moves from project-level file copying to a Claude Code plugin.

## What Changed

| v3.x | v4.0 |
|------|------|
| Skills in `.claude/skills/*.md` | Skills in plugin `skills/X/SKILL.md` |
| Agents in `.claude/agents/*.md` | Agents in plugin `agents/*.md` |
| Hooks in `.claude/settings.json` | Hooks in plugin `hooks/hooks.json` |
| Install copies files to each project | Install once as plugin to `~/.claude/plugins/pds/` |
| Skill invocation: `/swarm` | Skill invocation: `/pds:swarm` |
| 23 skills | 16 skills (7 demoted, 1 cut) |

## Step-by-Step Migration

### 1. Install the v4 plugin

```bash
curl -sfL https://raw.githubusercontent.com/rmzi/portable-dev-system/main/install.sh | bash
```

This installs:
- Plugin to `~/.claude/plugins/pds/`
- Security settings to `~/.claude/settings.json`

### 2. Remove project-level PDS files

If your project was using PDS v3.x with project-level installation:

```bash
# Remove skills (now in plugin)
rm -rf .claude/skills/

# Remove agents (now in plugin)
rm -rf .claude/agents/

# Remove hooks from settings.json (now in plugin)
# Edit .claude/settings.json and remove the "hooks" key
# Keep: sandbox, permissions, env sections
```

### 3. Keep project-level files

These stay at project level — they are team/project-specific:

- `.claude/settings.json` — team-specific deny rules, domain overrides
- `.claude/instincts.md` — project-learned patterns
- `CLAUDE.md` — project rules, agent zones
- `.claude/.pds-version` — version tracking

### 4. Update CLAUDE.md skill references

Find-and-replace skill invocations:

| Old | New |
|-----|-----|
| `/swarm` | `/pds:swarm` |
| `/grill` | `/pds:grill` |
| `/verify` | `/pds:verify` |
| `/finish` | `/pds:finish` |
| `/merge` | `/pds:merge` |
| `/worktree` | `/pds:worktree` |
| `/team` | `/pds:team` |
| ... | `/pds:...` |

### 5. Update removed skill references

| Removed Skill | Replacement |
|---------------|-------------|
| `/commit` | Use `/pds:finish` (includes commit format) |
| `/debug` | Use `/pds:grill` (includes hypothesis-first) |
| `/design` | Use `/pds:contribute` (includes ADR convention) |
| `/ethos` | Still available as `/pds:ethos` |
| `/quickref` | Use `/pds:team` (agent roster) + CLAUDE.md (skill table) |
| `/review` | Review integrity is in `/pds:finish` and reviewer agent |
| `/test` | Standard testing knowledge — Claude knows this natively |
| `/merge-main` | Use `/pds:merge` ("Merge to Main" section) |

## Dev Workflow

For PDS contributors working on the plugin locally:

```bash
# Symlink local checkout as plugin
make install
# or: ./install.sh --plugin-dir .

# Changes to skills/agents/hooks are immediately active
# No need to re-install after edits
```
