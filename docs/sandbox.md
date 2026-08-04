# Native Sandboxing

OS-level enforcement for Bash commands via Claude Code's native sandbox (Seatbelt on macOS, bubblewrap on Linux). Confines filesystem writes to the working directory and restricts network access to an allowlist.

## What the Sandbox Does

- **Filesystem**: Bash commands can only write to the current working directory (CWD) and temp dirs. Reads are broadly allowed.
- **Network**: Bash commands can only connect to domains in `sandbox.network.allowedDomains`.
- **Process**: Commands run inside an OS-level sandbox profile — not just prompt instructions.

## What the Sandbox Does NOT Do

- Does **not** sandbox Read/Write/Edit/Glob/Grep tools — those use Claude Code's built-in permission system (allow/deny rules).
- Does **not** sandbox WebFetch/WebSearch — those operate outside the Bash sandbox.
- Does **not** provide per-agent profiles — one sandbox config applies to all agents.
- Does **not** replace deny rules, hooks, or permission modes — it's one layer in a defense-in-depth stack.

## Security Model (6 Layers)

| Layer | Mechanism | Scope |
|-------|-----------|-------|
| **1. Sandbox** | OS-level (Seatbelt/bubblewrap) | Bash commands: filesystem writes, network |
| **2. Deny rules** | Static pattern matching in `settings.json` | All tools: credential paths, protected branches, sensitive files |
| **3. Phase gates** | PreToolUse hooks on orchestrator | SDLC phase enforcement, artifact checks |
| **4. Agent prompts** | Constraints in `agents/*.md` (plugin) | Role-specific behavior (read-only, stay in worktree) |
| **5. Permission modes** | `plan`, `acceptEdits`, `default`, `auto` | Tool access per agent type (auto mode: classifier decides) |
| **6. Human gate** | PR review before merge | All changes before production |

Per-agent differentiation relies on layers 2-6. The sandbox (layer 1) is a shared floor that all agents stand on.

## Default Configuration

This is `install.sh`'s actual source of truth: it copies the `sandbox` key straight out of PDS's own `.claude/settings.json` into the target project. Kept in sync with that file, not maintained as a separate example — if they drift, `.claude/settings.json` is canonical.

```json
{
  "sandbox": {
    "enabled": true,
    "autoAllowBashIfSandboxed": true,
    "excludedCommands": ["docker", "git", "gh"],
    "allowUnsandboxedCommands": true,
    "enableWeakerNestedSandbox": false,
    "additionalWritePaths": ["/private/tmp/tmux-*"],
    "network": {
      "allowedDomains": [
        "github.com",
        "api.github.com",
        "raw.githubusercontent.com",
        "*.npmjs.org",
        "registry.npmjs.org",
        "pypi.org",
        "files.pythonhosted.org"
      ],
      "allowAllUnixSockets": false,
      "allowLocalBinding": false
    }
  }
}
```

### Key settings

| Setting | Value | Why |
|---------|-------|-----|
| `autoAllowBashIfSandboxed` | `true` | Sandboxed Bash runs without permission prompts — velocity |
| `excludedCommands` | `["docker", "git", "gh"]` | Git needs network for push/pull; gh needs Keychain/TLS access the sandbox blocks for Go binaries (see the confirmed gap below — this doesn't fully deliver on either, in practice); docker needs host filesystem. All three guarded by deny rules regardless. |
| `allowUnsandboxedCommands` | `true` | Permits sandbox bypass (e.g. `dangerouslyDisableSandbox`, or a command routed outside the sandbox) rather than hard-blocking it. |
| `allowAllUnixSockets` | `false` | Blocks Docker socket and other local services by default |
| `allowLocalBinding` | `false` | Prevents Bash from binding to local ports |

## Customization

### Adding domains

For projects that need additional network access (e.g., private registries, APIs):

```json
"sandbox": {
  "network": {
    "allowedDomains": [
      "github.com",
      "api.github.com",
      "raw.githubusercontent.com",
      "*.npmjs.org",
      "registry.npmjs.org",
      "pypi.org",
      "files.pythonhosted.org",
      "your-private-registry.example.com",
      "api.your-service.com"
    ]
  }
}
```

### Maximum lockdown

For teams that want tighter control, replace the `mcp__*` wildcard in permissions with explicit MCP tool names:

```json
"permissions": {
  "allow": [
    "mcp__github__create_pull_request",
    "mcp__github__search_code"
  ]
}
```

### `mcp__*` wildcard risk

The default `mcp__*` permission auto-approves all MCP tools. This is convenient but means any MCP server added to the project gets full tool access. For security-sensitive environments, replace with explicit allowlists per MCP server.

### Sandbox as E2E Environment

The sandbox is the validated environment where builds, tests, and tools run end-to-end. If a command fails in the sandbox, expand the sandbox — don't bypass it.

**Rust monorepo example:**

Network (in `sandbox.network.allowedDomains`):
```json
"crates.io", "index.crates.io", "static.crates.io",
"github.com", "api.github.com",
"*.npmjs.org", "registry.npmjs.org"
```

Filesystem (in `sandbox.filesystem.allowWrite`):
```json
"/Users/you/.cargo/bin",
"/Users/you/.cargo/registry",
"/Users/you/.cargo/git"
```

With these in place, `cargo build`, `cargo test`, `cargo install`, `cargo clippy`, and `npm install` all run in-sandbox. The repo root is already in the write allowlist (CWD and `additionalDirectories`), covering `target/`, `node_modules/`, and `.worktrees/`.

**When the sandbox blocks a command:**

1. Is it a network issue? → Add the domain to `sandbox.network.allowedDomains`
2. Is it a filesystem write issue? → Add the path to `sandbox.filesystem.allowWrite` directly in `.claude/settings.json` (`/pds:allow` was pruned during skill consolidation — see #131 / `docs/pending-issues.md` #3; a credential-path safety guardrail for this was never rebuilt, so check the path by hand before adding it)
3. Can't be fixed by config? → Report the block to the pilot and send the command to the terminal pane for manual execution. **Exception**: git/gh network operations are a confirmed case where config expansion doesn't help at all — see "Excluded commands" below.

For most blocks, `dangerouslyDisableSandbox` is not the answer — expand config instead. The one confirmed exception is the git/gh network gap documented below, where it's the only thing that reliably works.

## Platform Support

| Platform | Mechanism | Dependencies |
|----------|-----------|--------------|
| macOS | Seatbelt (built-in) | None — works out of the box |
| Linux | bubblewrap + socat | `sudo apt install bubblewrap socat` |

The SessionStart hook and `install.sh` both check for Linux dependencies and warn if missing.

## Troubleshooting

### Command blocked by sandbox

If a legitimate command fails with "Operation not permitted" or similar:
1. Check if the command needs network access — add the domain to `allowedDomains`
2. Check if the command needs to write outside CWD — consider if this is really necessary
3. If the command cannot be accommodated by expanding the sandbox config, report it to the pilot and send it to the terminal pane for manual execution. Don't reach for `dangerouslyDisableSandbox` as a default escape hatch — the one confirmed exception is git/gh network operations (see "Excluded commands" below), where expanding config doesn't help at all.

### Excluded commands

`git`, `gh`, and `docker` are meant to bypass the sandbox entirely and go through the normal permission flow (deny rules + active permission mode) instead. This is by design — git needs arbitrary network access for remotes, gh needs Keychain/TLS access the sandbox blocks for Go binaries, and docker needs host filesystem access.

**Confirmed gap, by direct testing (identical command, sandboxed vs. `--dangerously-skip-sandbox`), not yet resolved:** `excludedCommands` does not reliably deliver this in every environment. Two concrete failure modes observed with `git`/`gh` already in `excludedCommands`:

1. An SSH git remote (`git@github.com:...`) fails deterministically under the sandbox — the sandbox's network proxy is HTTP(S)-only and cannot tunnel raw SSH, even to an allowed domain. Switching to an HTTPS remote with a credential helper (`gh auth setup-git`) avoids this specific failure. `SessionStart` (`session-start.sh`) now detects this automatically and, since this is deterministic (not intermittent), instructs the session to proactively offer the fix via `AskUserQuestion` — not just warn and leave it to the user to notice.
2. Even over HTTPS, `git fetch` of substantial pack data can fail intermittently under the sandbox (`did not send all necessary objects`) while small pushes and `git ls-remote` succeed — an apparent proxy-level issue with git's binary smart-HTTP transfer. Standalone `gh` network calls (`gh api`, `gh pr list`, `gh auth status`) showed the same TLS/keychain symptoms `excludedCommands` was added in v4.14.0 specifically to fix.

Neither failure produced a permission prompt — both ran silently through what behaved like the sandboxed path, contradicting "bypass the sandbox entirely" above. Whether this is a Claude Code regression, an environment-specific harness difference, or a gap in how `excludedCommands` interacts with network/credential isolation specifically is not yet determined — see the tracking issue linked from `CHANGELOG.md`. **The one workaround confirmed to work reliably for both failure modes**: run the specific git/gh network command with the sandbox explicitly disabled for that invocation, rather than relying on `excludedCommands` alone.

### Missing Linux dependencies

If you see "Sandbox dep missing" on session start:
```bash
sudo apt install bubblewrap socat
```

## Permission Flow

How a Bash command flows through the full permission stack:

```
Bash command arrives
  → Matches a deny rule? → BLOCKED (credential paths, protected branches, etc.)
  → Excluded from sandbox (git, docker)? → Permission mode evaluates
  → Sandboxed + autoAllowBashIfSandboxed? → AUTO-APPROVE (OS-confined)
    → Sandbox blocks the command? → Report to pilot, send to terminal pane
  → None of the above → Permission mode evaluates
```

"Permission mode evaluates" means:
- **default/acceptEdits/plan**: User is prompted to approve or deny
- **auto**: Sonnet classifier evaluates the action against the conversation transcript
- **dontAsk**: Auto-denied unless explicitly in the allow list

| Command | Path |
|---------|------|
| `npm test`, `pip install`, `ls` | Sandbox auto-approve |
| `git commit`, `git push origin feature` | Permission mode (user prompt / auto classifier / dontAsk) |
| `git push --force-with-lease` | Permission mode — user prompted to approve |
| `git push origin main` | Deny rule → BLOCKED |
| `git push --delete` | Deny rule → BLOCKED |
| `docker build .` | Permission mode (user prompt / auto classifier / dontAsk) |
| `ssh user@host` | Deny rule → BLOCKED |
| Read/Write/Edit/Glob/Grep | Static allow list |
| MCP tools | `mcp__*` allow list |

Deny rules fire first (deny > allow). The sandbox handles routine Bash. The active permission mode handles everything else.

**Force push**: Force push (`--force`, `--force-with-lease`) goes through the normal permission flow rather than being unconditionally blocked. In interactive modes, the user is prompted and can approve or deny. In auto mode, the classifier evaluates it. Protected branch pushes remain unconditionally blocked by deny rules regardless of force flags.

## Hook Events

PDS hooks fire on lifecycle events. Relevant events for sandbox and agent auditing:

| Event | Hook Type | When it fires |
|-------|-----------|---------------|
| `PreToolUse` | PreToolUse | Before any tool call — used for deny/allow gates |
| `PostToolUse` | PostToolUse | After a tool call — used for audit logging |
| `SessionStart` | SessionStart | On session init — used to check Linux sandbox deps |
| `WorktreeCreate` | PostToolUse | When a worker worktree is provisioned — logged for lifecycle audit |
| `WorktreeRemove` | PostToolUse | When a worktree is removed after task completion — logged for lifecycle audit |
| `InstructionsLoaded` | SessionStart | When agent instructions are loaded — used to verify plugin config |

`WorktreeCreate` and `WorktreeRemove` events are available since Claude Code 2.1.50 and let hooks track worker lifecycle for audit purposes.

**HTTP hooks** (since 2.1.63): Hooks can now be configured as HTTP endpoints in addition to local shell scripts. Useful for centralized audit logging or team-wide permission policies.

## Auto Mode Interaction

Auto mode replaces user permission prompts with a Sonnet classifier that evaluates each tool call. The classifier reads `autoMode` config from `~/.claude/settings.json` (user-level) or `.claude/settings.local.json` (local). It does **not** read `.claude/settings.json` (project-level, checked in).

**How auto mode interacts with PDS layers:**

| Layer | Effect in Auto Mode |
|-------|--------------------|
| Sandbox | Unchanged — OS-level enforcement is independent of permission mode |
| Deny rules | Unchanged — static deny fires before the classifier |
| Phase gates | Unchanged — PreToolUse hooks run before the classifier |
| Agent prompts | Behavioral enforcement still active; classifier uses conversation context |
| Permission modes | Auto mode overrides agent-declared `plan`/`acceptEdits`/`default` — the classifier decides |
| Human gate | Unchanged — PR review remains the final gate |

**Key point**: Static deny rules and the sandbox provide the hard security floor. Auto mode replaces only the *interactive permission prompts* — it does not bypass deny rules, sandbox restrictions, or phase gates.

### autoMode Config

PDS installs `autoMode` config to `~/.claude/settings.json` via `install.sh`. The config has two sections:

- **`allow`** — Operations the classifier should always permit (worktrees, tests, agent coordination)
- **`environment`** — Trusted infrastructure descriptions (tells the classifier what "normal" looks like)

To add org-specific entries, create `.claude/settings.local.json`:
```json
{
  "autoMode": {
    "environment": [
      "Source control: github.com/your-org",
      "Internal APIs: api.internal.your-company.com"
    ]
  }
}
```
Entries from all scopes are combined (union).

### Denial Thresholds

If the classifier blocks 3 consecutive or 20 total actions in a session, auto mode pauses and falls back to user prompts. These thresholds are not configurable. In non-interactive mode (`claude -p`), the session aborts instead.

## CI/CD and Headless Use

Anthropic recommends `dontAsk` or `acceptEdits` + `--allowedTools` for CI/CD pipelines, **not** auto mode.

**Why not auto mode for CI/CD?**
- The classifier adds latency and cost per tool call
- Non-interactive sessions abort on 3 consecutive denials (not configurable)
- `dontAsk` mode is purpose-built for non-interactive use

**Recommended CI/CD configuration:**
```bash
claude -p "your task" \
  --permission-mode dontAsk \
  --allowedTools "Read,Write,Edit,Glob,Grep,Bash" \
  --bare \
  --max-turns 50
```

- `--bare` skips auto-discovery of hooks, plugins, MCP servers for reproducibility
- `--allowedTools` restricts the tool surface to exactly what's needed
- Static deny rules still apply even in `dontAsk` mode
- The sandbox still confines Bash writes to the working directory

## See Also

- `docs/ethos.md` — core development principles
- `/pds:team` — Agent roles and permission modes
