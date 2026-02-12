# Permission Router

Auto-resolve subagent permission requests via Claude Code's built-in LLM-as-judge prompt hook. No external API key needed — uses the existing session auth.

## How It Works

A `PermissionRequest` prompt hook in `.claude/settings.json` evaluates every permission request from subagents:

1. Subagent requests a permission (e.g., run a bash command, read a file)
2. Claude Code fires the `PermissionRequest` hook
3. The prompt hook evaluates the request against allow/deny rules
4. Returns `{"ok": true}` to approve or `{"ok": false, "reason": "..."}` to deny

No user prompting. No separate API call. The hook runs inline within Claude Code's hook system.

## Policy

### Allowed (routine dev operations)
- Reading/writing source code
- Running tests, linters, formatters, builds
- Installing dependencies
- Git operations on feature branches
- File search, web search/fetch

### Denied (security guardrails)
- Credential files: `~/.aws`, `~/.ssh`, `~/.gnupg`, `~/.config/gcloud`, `~/.netrc`, `.pem` files
- Production patterns: `PROD`, `prod.*`, `--profile prod`
- Remote access: `ssh`, `scp`, `sftp`
- Push to protected branches: `main`, `master`, `dev`, `develop`
- Force push
- `.env` files, secrets directories

### Default: ALLOW

When a request doesn't match any deny rule, it's approved. The deny list is the guardrail, not the allow list.

## Configuration

The hook lives in `.claude/settings.json` under `hooks.PermissionRequest`. The timeout is 15 seconds — if the evaluation takes longer, the request falls through to normal permission handling.

To verify the hook is configured:

```bash
jq '.hooks.PermissionRequest' .claude/settings.json
```

## Relationship to Static Permissions

The static `permissions.allow` and `permissions.deny` lists in `settings.json` still apply. The prompt hook handles cases where static rules don't cover the request — it acts as a dynamic second layer for subagent permission routing.
