# `pds.config.yaml` — portable user preferences

One config file, kept in your personal dotfiles repo, fans out to the sinks Claude Code actually reads. No more re-prompting for the same permissions on every new machine or worktree.

## Quick start

```sh
# 1. Copy the example.
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/pds"
cp <plugin_root>/examples/config.yaml "${XDG_CONFIG_HOME:-$HOME/.config}/pds/config.yaml"

# 2. Edit. Every key is optional — missing keys use PDS defaults.
$EDITOR "${XDG_CONFIG_HOME:-$HOME/.config}/pds/config.yaml"

# 3. Preview.
pds sync --dry-run

# 4. Apply.
pds sync
```

## Where things live (XDG)

| Kind     | Location                                          |
|----------|---------------------------------------------------|
| Config   | `${XDG_CONFIG_HOME:-~/.config}/pds/config.yaml`   |
| Data     | `${XDG_DATA_HOME:-~/.local/share}/pds/`           |
| Cache    | `${XDG_CACHE_HOME:-~/.cache}/pds/`                |

PDS never writes to `~/.pds/` — that path belongs to Bluesky/ATProto's Personal Data Server and would collide if you run one.

## What `pds sync` writes

Six sinks, in order:

1. `~/.claude/settings.json` — merged `allow`/`ask`/`deny` after preset expansion.
2. `$PWD/.claude/settings.json` — project-scope seed, only if `permissions.write_target = user_plus_project_seed`.
3. Global gitignore (`core.excludesFile` or `${XDG_CONFIG_HOME}/git/ignore`) — managed block between `# >>> pds managed >>>` and `# <<< pds managed <<<`.
4. `$PWD/CLAUDE.md` — content between `<!-- pds:start -->` and `<!-- pds:end -->` markers. Opt-in: no markers → no write.
5. Plugins listed in `plugins.install` — shelled out to `claude plugins install` (idempotent).
6. Nothing else is ever touched.

## Trust model (TOFU)

First `pds sync` on a new machine diffs everything and asks for confirmation. After apply, the config *shape* (top-level keys + preset names + plugin list) is fingerprinted at `${XDG_CACHE_HOME}/pds/sync-fingerprint.sha256`. Subsequent syncs:

- **Shape unchanged** → silent apply.
- **Shape changed** → re-prompt with a diff.

Rationale: TOFU matches the friction budget for a personal-dotfiles workflow. The trust boundary is "my dotfiles repo is trusted" — the same trust model as `~/.zshrc`. Use `--yes` in automation to skip the prompt.

## Hooks read config via `pds config get`

Hooks no longer embed `${PDS_HEALTH_SERIOUS_MIN:-180}`. They call `pds config get health.serious_min` with a shell fallback for installs that don't have the CLI yet. This means changing a threshold in `config.yaml` takes effect immediately — no env var wiring, no restart.

## Merge semantics

Final priority when Claude Code resolves a setting (highest wins):

1. PDS plugin defaults (shipped in the plugin repo)
2. `pds.config.yaml` (fanned out to `~/.claude/settings.json`, `~/.claude.json`, global gitignore)
3. Repo `.claude/settings.json` (committed, team-shared)
4. Repo `.claude/settings.local.json` (per-checkout, gitignored)
5. Repo `.mcp.json` (for MCP extras)
6. CLI flags for the session

PDS never overwrites content *outside* its managed regions (e.g., outside `<!-- pds:start -->` markers).

## Permission presets

Presets ship with the plugin under `config-presets/`. Each entry is annotated for auditability:

```yaml
name: pds-default
entries:
  - pattern: "Bash(git status:*)"
    verb: allow
    scope: user
    reason: "Read-only. Asked on every session start — prompt fatigue vs zero risk."
```

Reference them in your config:

```yaml
permissions:
  presets: [pds-default, dev-tools]
  allow: []   # your additions on top
```

Preset reasons never reach `settings.json` — they stay in the preset source so future-you understands why a rule exists.

## S3 archive (optional)

See [`terraform/examples/default/`](../terraform/examples/default/) for one-command provisioning of a bucket with a 30-day Standard → Deep Archive lifecycle. After `terraform apply`:

```yaml
capture:
  s3:
    enabled: true
    bucket: pds-<your-suffix>-us-east-1
    region: us-east-1
```

Run `pds archive` (cron it daily) to promote local-hot files older than `capture.retention.local_hot_days`.

## Debugging

- `pds config show` — print the resolved config with all defaults filled in.
- `pds config get <key>` — read one value (hooks use this form).
- `pds doctor` — cross-install health check (CLI, paths, presets resolve, `claude` on PATH).
- `pds sync --dry-run` — preview every pending write without touching disk.
- `pds sync --skip permissions,claude_md` — selectively skip phases.
