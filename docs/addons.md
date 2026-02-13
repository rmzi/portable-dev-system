# Addons

Independently maintained packages that extend Claude Code through skills, hooks, agents, and scripts. PDS provides conventions; addons follow them without depending on PDS.

---

## What an Addon Is

A self-contained repo providing any combination of:

- **Skills** (`.claude/skills/*.md`) — workflow patterns
- **Hooks** (`.claude/hooks/*.json`) — event-driven shell commands
- **Agents** (`.claude/agents/*.md`) — specialized agent definitions
- **Scripts** — shell commands, binaries, tooling

---

## Required Structure

```
<addon-repo>/
├── VERSION                          # Semantic version (e.g., 0.1.0)
├── .claude/
│   ├── skills/<addon>.md            # Skill file(s) with YAML frontmatter
│   └── hooks/<addon>.json           # Hook config template (settings.json entries)
├── shell/<addon>-helpers.sh         # Lifecycle shell functions (sourceable)
└── README.md
```

### VERSION

Plain text semver string (e.g., `0.1.0`). Update lifecycle checks this to detect changes.

### Skill File

Standard PDS skill format. See [docs/skills.md](skills.md) for format.

### Hook Config Template

A JSON file containing hook entries to merge into a project's `.claude/settings.json`. Uses the Claude Code hooks schema:

```json
{
  "hooks": {
    "EventName": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/<addon>-hook.sh <args>"
          }
        ]
      }
    ]
  }
}
```

### Lifecycle Shell Functions

Sourceable file in `shell/<addon>-helpers.sh` providing `<prefix>-init` (install skill + hooks, write version marker) and `<prefix>-update` (check remote VERSION, pull if newer). Same pattern as PDS's `install.sh`.

---

## Installation Flow

1. Install the addon (`cargo install`, `npm install`, or direct download)
2. Source shell helpers: `source shell/<addon>-helpers.sh`
3. Run `<prefix>-init` — copies skill, merges hooks, writes version marker

[zaku](https://github.com/rmzi/zaku) automates this flow.

---

## Conventions

- **Graceful degradation**: Guard with `command -v <addon>`. Hooks must exit 0 when addon absent.
- **Self-contained**: Addon repo hosts everything. No PDS dependency — works with vanilla Claude Code.
- **Version markers**: `.<addon>-version` tracks installed version. Update compares against remote `VERSION`.
- **Background execution**: Hook commands doing I/O run in background (`&`), never block Claude Code.

---

## Example: branch-tone

[branch-tone](https://github.com/rmzi/branch-tone) plays audio cues on task completion and permission requests.

Hook wrapper (graceful degradation pattern): `command -v branch-tone >/dev/null 2>&1 || exit 0; branch-tone play "${1:-stop}" &; exit 0`

```bash
# shell/branch-tone-helpers.sh
bt-init() {
  local project="${1:-.}"
  cp .claude/skills/branch-tone.md "$project/.claude/skills/"
  # Merge hooks into settings.json
  cp VERSION "$project/.branch-tone-version"
}
# bt-update follows same pattern as install.sh
```

Install via [zaku](https://github.com/rmzi/zaku): `zaku install` prompts for optional addons, runs `cargo install` + `bt-init`.

---

## Future: Agent Packs

Agent definitions (`.claude/agents/*.md`) are bundled with PDS core today — every project install gets the full 8-agent roster. This is intentional: discoverability matters more than file count, and agent files only enter context when spawned via Task.

Composable agent packs (e.g., a security-focused roster, data-eng roster, or team-specific agents) are a natural addon extension. An agent pack addon would provide `.claude/agents/*.md` files and optionally orchestration skills (`/swarm`-style) tuned to that domain. The install script's project mode already copies agents — an addon could follow the same pattern with its own agent set.

Not needed yet. Worth building when teams want custom rosters beyond PDS core.

---

## Creating an Addon

1. Create repo with required structure above (VERSION, skill, hooks, shell helpers)
2. Implement `<prefix>-init` and `<prefix>-update`
3. Ensure hook scripts degrade gracefully (`command -v` guard, exit 0)
4. Test: fresh project → run init → verify skill and hooks work
