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
2. `$PWD/.claude/settings.json` — project-scope seed, only if `permissions.write_target = user_plus_project_seed` **and** you pass `--project`. Without the flag, sync never touches a tracked settings file in whatever repo you happen to be standing in.
3. Global gitignore (`core.excludesFile` or `${XDG_CONFIG_HOME}/git/ignore`) — managed block between `# >>> pds managed >>>` and `# <<< pds managed <<<`.
4. `$PWD/CLAUDE.md` — content between `<!-- pds:start -->` and `<!-- pds:end -->` markers. Opt-in: no markers → no write.
5. Plugins listed in `plugins.install` — shelled out to `claude plugins install` (idempotent).
6. Nothing else is ever touched.

> **`pds sync` does not manage the sandbox.** There is no `sandbox` key in this schema. The sandbox block reaches `~/.claude/settings.json` only via `install.sh`. If you rely on sandbox confinement, `pds sync` alone will not give it to you.

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
  presets: [pds-default, dev-tools, security-baseline]
  allow: []   # your additions on top
```

Preset reasons never reach `settings.json` — they stay in the preset source so future-you understands why a rule exists.

> **Presets resolve from the installed plugin cache, not from a repo checkout.** If you add a preset to `config-presets/` locally, `pds sync` will not see it until the plugin is published and installed. The error names the path it searched.

### Shipped presets

| Preset | What it does | Default in `examples/config.yaml` |
|---|---|---|
| **`pds-default`** | Baseline. Allows read-only developer operations Claude does constantly (`git status`/`log`/`diff`, `ls`, `pwd`, `cat`). Denies `rm -rf /`. Puts the three history-destroying git operations behind `ask`. | ✅ on |
| **`dev-tools`** | Build/test ergonomics: `cargo`, `pytest`, `ruff`, `mypy`, `npm run`, `make`. Package installs go to `ask`, not `allow`. | ✅ on |
| **`security-baseline`** | **The credential perimeter.** Denies reading, tampering with, and shelling into credential stores (cloud SDK configs, SSH/GPG keys, package-registry tokens), credential files (`.env`, `*.pem`, `id_rsa*`, `.git-credentials`), and process environments. | ✅ on |

#### `security-baseline` — read this before dropping it

It is on by default deliberately. Shipping the perimeter off-by-default is how it came to be missing everywhere: the rules lived only in the repo's `.claude/settings.json`, which is applied exclusively by `install.sh`, so anyone who installed via the marketplace ran with an empty deny list.

Nothing in it trades against velocity — none of it is something an agent should be doing unprompted. **Two groups inside it are opinionated and will false-positive on real work:**

- **Outbound remote access** — blocks lateral movement from a compromised or confused agent. Also blocks legitimate infrastructure work. If you administer remote hosts, this rule is wrong for you.
- **Production tripwires** — a deliberately broad substring match on `prod`. It will match filenames and prose, not just credential profiles. A false positive costs one prompt; the thing it guards against costs more.

If either fights your workflow, **drop the preset and copy the entries you want into your own `deny:` list** rather than working around it. Read `config-presets/security-baseline.yaml` first — every entry carries a `reason` explaining what it's for.

**One caveat that is not obvious:** `Bash(...)` deny patterns substring-match the *entire command string*, not the operation. A command that merely *mentions* a guarded path — in a comment, in a heredoc, in documentation you're writing about the perimeter itself — is denied. This is safe-by-default and occasionally maddening.

**Deny rules use `Edit(path)`, never `Write(path)`.** Claude Code honours only `Edit(path)` for file permission checks; `Write(path)` deny rules are silently skipped with a warning printed to stderr. `Edit` covers all file-editing tools. If you add your own file-deny rules, use `Edit(...)` — a `Write(...)` rule will look correct and do nothing.

## Protected branches

```yaml
worktree:
  protected_branches: [main]
```

`/pds:finish` reads this via `pds config get worktree.protected_branches` and prompts for confirmation before pushing to a match. **An empty list means nothing is protected and the prompt never fires** — set your real trunk. This is the client-side "are you sure?"; GitHub branch protection rules are the server-side enforcement.

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

> `pds doctor` reports "config parses: ok" when the YAML is *syntactically* valid. It does not ask Claude Code whether the rules are *semantically accepted*. For that, run `claude config list` and read the warnings — CC prints one per rejected rule.
