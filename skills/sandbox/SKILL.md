---
description: OS-level sandbox configuration — filesystem confinement, network restrictions, platform support
---
# /sandbox — Native Sandboxing

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
| **3. PermissionRequest hook** | LLM-as-judge prompt evaluation | Subagent requests not covered by static rules |
| **4. Agent prompts** | Constraints in `agents/*.md` (plugin) | Role-specific behavior (read-only, stay in worktree) |
| **5. Permission modes** | `plan`, `acceptEdits`, `delegate` | Tool access per agent type |
| **6. Human gate** | PR review before merge | All changes before production |

Per-agent differentiation relies on layers 2-6. The sandbox (layer 1) is a shared floor that all agents stand on.

## Default Configuration

```json
{
  "sandbox": {
    "enabled": true,
    "autoAllowBashIfSandboxed": true,
    "excludedCommands": ["docker", "git"],
    "allowUnsandboxedCommands": true,
    "enableWeakerNestedSandbox": false,
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
| `excludedCommands` | `["docker", "git"]` | Git needs network for push/pull; docker needs host filesystem. Both guarded by deny rules. |
| `allowUnsandboxedCommands` | `true` | Allows `dangerouslyDisableSandbox` when sandbox blocks a legitimate command |
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
3. As a last resort, the command can use `dangerouslyDisableSandbox: true` (requires `allowUnsandboxedCommands: true`)

### Excluded commands

`git` and `docker` bypass the sandbox entirely. They go through the normal permission flow (deny rules + PermissionRequest hook). This is by design — git needs arbitrary network access for remotes, and docker needs host filesystem access.

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
  → Excluded from sandbox (git, docker)? → PermissionRequest hook evaluates
  → Sandboxed + autoAllowBashIfSandboxed? → AUTO-APPROVE (OS-confined)
  → None of the above → PermissionRequest hook evaluates
```

| Command | Path |
|---------|------|
| `npm test`, `pip install`, `ls` | Sandbox auto-approve |
| `git commit`, `git push origin feature` | PermissionRequest hook → ALLOW |
| `git push origin main` | Deny rule → BLOCKED |
| `docker build .` | PermissionRequest hook → ALLOW |
| `ssh user@host` | Deny rule → BLOCKED |
| Read/Write/Edit/Glob/Grep | Static allow list |
| MCP tools | `mcp__*` allow list |

Deny rules fire first (deny > allow). The sandbox handles routine Bash. The PermissionRequest hook handles git, docker, and anything that falls through.

## See Also

- `/pds:permission-router` — Hook policy for the PermissionRequest layer
- `/pds:audit-config` — Verify sandbox is properly configured
- `/pds:team` — Agent roles and permission modes
