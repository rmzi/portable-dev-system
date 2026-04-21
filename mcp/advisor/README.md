# pds-advisor MCP server

Wraps the Anthropic `advisor_20260301` beta tool and exposes it as a single MCP tool named `advisor_consult`. Gracefully falls back to plain Opus when the advisor beta is unreachable or when `ANTHROPIC_API_KEY` is unset.

## Tool: `advisor_consult`

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| `prompt` | string | yes | — | The question or scenario to consult on. |
| `max_uses` | integer | no | `1` | Max advisor tool invocations in this call. Clamped to `[1, 10]`. |

Returns a JSON-encoded payload:

```json
{
  "advice": "...",
  "degraded": false,
  "reason": "..."  // present only when degraded=true
}
```

## Fallback behavior

| Condition | Behavior |
|---|---|
| `ANTHROPIC_API_KEY` unset | `{ advice: "", degraded: true, reason: "advisor unavailable — set ANTHROPIC_API_KEY" }` |
| Beta 4xx/5xx | Retry as plain Opus (no tool, no beta header); return degraded with the failure reason |
| Network timeout | Retry as plain Opus; return degraded |
| 401/403 auth | `{ advice: "", degraded: true, reason: "auth failed (401\|403)" }` (no retry) |
| Both paths fail | `{ advice: "", degraded: true, reason: "advisor unreachable — ..." }` |

The MCP handler never throws — every error path returns a structured response. Degradations are also logged to stderr so the shepherd agent can observe them.

## Environment

- `ANTHROPIC_API_KEY` (required for live calls; without it, the tool returns a degraded response but the server still starts)

## Build

```bash
cd mcp/advisor
npm install
npm run build
```

Output lands in `dist/server.js`.

## Run

```bash
# Start the stdio server manually:
node dist/server.js
```

Under PDS, the server is launched automatically by Claude Code via `.claude-plugin/plugin.json`:

```json
{
  "mcpServers": {
    "pds-advisor": {
      "command": "node",
      "args": ["${CLAUDE_PLUGIN_ROOT}/mcp/advisor/dist/server.js"]
    }
  }
}
```

Make sure to run `npm install && npm run build` inside `mcp/advisor/` at least once before the plugin can spawn the server.

## Smoke test

The exported `advise(prompt, maxUses)` function runs independently of the MCP transport, so it is suitable for Node smoke tests:

```bash
node -e "import('./dist/server.js').then(async (m) => { const r = await m.advise('Should I squash before rebase? Under 50 words.'); console.log(JSON.stringify(r, null, 2)); })"
```

Without `ANTHROPIC_API_KEY` set, the output will be:

```json
{
  "advice": "",
  "degraded": true,
  "reason": "advisor unavailable — set ANTHROPIC_API_KEY"
}
```

With a valid key, expect a non-empty `advice` field and `degraded: false` (or `degraded: true` with a `fell back to plain opus` reason if the beta path is unavailable).

## Role

This server is the MCP backbone for the PDS **shepherd** agent. See `agents/shepherd.md` for how the shepherd uses it, and `agents/worker.md` for the worker-side fallback that invokes the tool directly when the shepherd is unavailable (lite tier or no shepherd in scope).
