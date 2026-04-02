# Plan: Secret Protection (#113) — Scrub Don't Block

## Context

Claude Code can leak credentials through multiple vectors. PDS's existing static deny rules only cover file paths. The AI should NEVER see secret values. The approach: scrub output via deterministic regex at the hook level, don't block commands. Blocking is an anti-pattern.

## Architecture

```
Bash commands:                          MCP tools:
  Command entered                         MCP tool returns
       │                                       │
  PreToolUse hook                         PostToolUse hook
       │                                       │
  Rewrites command to pipe               Scrubs via
  output through sed scrubber            updatedMCPToolOutput
       │                                       │
  Scrubbed output reaches Claude         Scrubbed output reaches Claude
```

**Key source code findings:**
- PreToolUse `updatedInput` can rewrite Bash commands before execution (confirmed in src/utils/hooks.ts)
- PostToolUse `updatedMCPToolOutput` can replace MCP tool output (confirmed)
- PostToolUse for Bash has NO output replacement — only `additionalContext` and `suppressOutput`
- Therefore: Bash scrubbing MUST happen via PreToolUse command rewriting, not PostToolUse

## Deliverables

### Worker 1: Hooks (scrubbing + telemetry)

**1. `hooks/scripts/secret-scrub.sh` — PreToolUse hook for Bash**
- Receives Bash command as JSON input
- Identifies commands that could produce secret output (env, printenv, cat .env, echo $SECRET, curl, etc.)
- Rewrites command to pipe through sed with secret patterns:
  - `sk-[a-zA-Z0-9]{20,}` (Anthropic/OpenAI keys)
  - `ghp_[a-zA-Z0-9]{36}` (GitHub PATs)
  - `AKIA[A-Z0-9]{16}` (AWS access keys)
  - `xoxb-[a-zA-Z0-9-]+` (Slack tokens)
  - `eyJ[a-zA-Z0-9_-]+\.eyJ[a-zA-Z0-9_-]+` (JWT tokens)
  - `[a-zA-Z0-9/+=]{40,}` with entropy check (generic base64 secrets)
  - KEY=value patterns in .env-style output
- Returns JSON: `{"hookSpecificOutput": {"hookEventName": "PreToolUse", "updatedInput": {"command": "original | sed scrubber"}}}`
- Non-risky commands pass through unchanged
- Log scrub events to encrypted telemetry

**2. `hooks/scripts/mcp-secret-scrub.sh` — PostToolUse hook for MCP tools**
- Receives MCP tool output as JSON input
- Applies same regex patterns to scrub secret values
- Returns JSON: `{"hookSpecificOutput": {"hookEventName": "PostToolUse", "updatedMCPToolOutput": <scrubbed>}}`

**3. Encrypted scrub telemetry**
- On first scrub event: generate age key if not exists (`~/.config/pds/scrub.key`)
- Log to `~/.config/pds/scrub-telemetry.age` (encrypted with age)
- Each entry: timestamp, command name, full command, scrubbed output, patterns matched
- Decrypt command: `age -d -i ~/.config/pds/scrub.key ~/.config/pds/scrub-telemetry.age`

**4. Hook registration**
- `hooks/hooks.json` — Add PreToolUse entry with Bash matcher for secret-scrub.sh
- `hooks/hooks.json` — Add PostToolUse entry with MCP matcher for mcp-secret-scrub.sh
- `.claude/settings.json` — Register hooks

**5. Static deny rules (minimal, truly dangerous only)**
- `Bash(* /proc/*/environ*)` — process environ reads (no legitimate use case in PDS)
- `Bash(*/proc/self/environ*)` — same

### Worker 2: gitleaks integration + research issue

**1. `install.sh` — gitleaks auto-install**
- Check for gitleaks binary
- If missing: install via brew (macOS) or go install (Linux)
- Set up pre-commit hook: `.pre-commit-config.yaml` with gitleaks
- Ship `.gitleaks.toml` config with PDS-specific patterns

**2. Create research issue**
- "research: evaluate sentinel-ai and detect-secrets for PDS secret scanning"
- Scope: hands-on evaluation of both tools, integration recommendations

## Files

| File | Action | Worker |
|------|--------|--------|
| `hooks/scripts/secret-scrub.sh` | Create | 1 |
| `hooks/scripts/mcp-secret-scrub.sh` | Create | 1 |
| `hooks/hooks.json` | Modify (add 2 hook entries) | 1 |
| `.claude/settings.json` | Modify (add deny rules + hook registration) | 1 |
| `install.sh` | Modify (add gitleaks install + age install) | 2 |
| `.gitleaks.toml` | Create (gitleaks config) | 2 |

## Verification

1. `make test` passes
2. Run `env` in a PDS session — output should have secret-like values redacted
3. Run `echo test_not_a_secret` — should pass through unchanged
4. Run `echo sk-testkey1234567890abcdef` — should show `[REDACTED]`
5. Encrypted telemetry file created after scrub events
6. `gitleaks detect` works after install
7. MCP tool output scrubbing works (test with a mock MCP response if possible)

## Swarm: Lite

Two workers in parallel:
- Worker 1: hooks (secret-scrub.sh, mcp-secret-scrub.sh, telemetry, registration)
- Worker 2: gitleaks integration (install.sh, .gitleaks.toml, research issue)

No dependencies between them.
