# ADR 0010: Remove the `mcp/advisor` MCP Server — Self-Consult Instead of an External Advisor Beta Call

## Status
Accepted

## Context

`mcp/advisor/` was a bundled Node MCP server that wrapped Anthropic's `advisor_20260301` beta tool and exposed it as a single MCP tool, `mcp__pds-advisor__advisor_consult`. It existed to give the shepherd (and workers, as a fallback when the shepherd is absent) a way to reach "synthesis beyond its loaded corpus."

This was discovered broken while landing v5.0.0 (#177) and verifying the plugin would actually work for a marketplace install:

1. **The build step never ran.** `plugin.json` declared `mcpServers.pds-advisor` pointing at `${CLAUDE_PLUGIN_ROOT}/mcp/advisor/dist/server.js`. `dist/` and `node_modules/` were both gitignored — nothing was ever committed. The server's own README said outright: "Make sure to run `npm install && npm run build` inside `mcp/advisor/` at least once before the plugin can spawn the server." `install.sh` never did this. A marketplace install (`source: github`, pulling the repo tree as-is) had no path to produce `dist/server.js` at all — the declared MCP server could not start.
2. **This was a known-unverified gap, not a new discovery.** Issue #159 (the v5.0.0 tracking issue) itself flagged, under "Zone 0": "confirm `install.sh`/`pds sync` actually builds `mcp/advisor/dist/` so the declared `pds-advisor` server resolves." It shipped in v5.0.0 without that confirmation ever happening — the gap was real the whole time.
3. **It contradicts PDS's own premise.** PDS is a *portable* development system distributed as a Claude Code plugin — install the plugin, it works. `mcp/advisor` required a Node/npm toolchain to be present and manually built (not guaranteed — verified missing on at least one real dev machine during this investigation) and a separate `ANTHROPIC_API_KEY` beyond whatever credential already authenticates the Claude Code session. That's a second toolchain dependency and a second credential/billing surface for one optional fallback path.
4. **Its value was thin relative to its cost.** The shepherd is already an opus-tier agent with a loaded reference corpus (`docs/whitepaper.md`, `docs/philosophy.md`, `docs/ethos.md`, etc.). Reaching out to a second, out-of-band Opus call via the raw Anthropic API for "synthesis beyond its loaded corpus" duplicated capability the agent already had, for a benefit that was never demonstrated in practice (the server could never actually spawn during real usage, per point 1).

## Decision

Remove `mcp/advisor/` entirely, along with every reference to it:

- Delete `mcp/advisor/` (source, README, package.json/lock).
- Remove `mcpServers.pds-advisor` from `.claude-plugin/plugin.json`.
- Remove `mcp__pds-advisor__advisor_consult` from `agents/shepherd.md` and `agents/worker.md` tool allowlists.
- Replace every "invoke `advisor_consult`" fallback instruction (in `agents/shared-rules.md`, `agents/worker.md`, `skills/swarm/SKILL.md`, `skills/team/SKILL.md`, `docs/philosophy.md`, `docs/whitepaper.md`) with **self-consult**: when the shepherd is absent (lite tier) or unavailable (idle, timed out), the agent reads `docs/whitepaper.md`, `docs/philosophy.md`, and `docs/ethos.md` directly and reasons from citations itself, rather than calling out to an external tool.
- Remove `pds-advisor` from the `mcp.core` list in `examples/config.yaml`.

No replacement MCP server, bundler, or build step is introduced. The fallback is "read the docs you already have Read access to," which requires no new dependency, no build step, and no second credential.

## Consequences

### Positive
- Closes a real, currently-shipped-broken gap: the plugin no longer declares an MCP server it cannot spawn out of the box.
- Restores the portability the project is named for — installing the PDS plugin no longer implies a Node/npm toolchain or a second `ANTHROPIC_API_KEY`.
- Removes a case of the exact anti-pattern PDS's own "mirror, don't invent" instinct (source issue #149) warns against: standing up new machinery (an external API wrapper) when the existing capability (the agent's own model + loaded corpus) already covers the case.

### Negative
- Loses whatever marginal value the advisor beta's "synthesis beyond the loaded corpus" offered over the shepherd's own reasoning — never measured, since the server could not spawn in practice. If a real need for external synthesis emerges later, it should be re-evaluated as a new, portable design (no bundled Node build step, no mandatory second credential) rather than reintroducing this one.
- Workers and the orchestrator now fall back to reading source docs directly rather than a single-purpose consult tool; slightly more tokens spent reading `docs/whitepaper.md` etc. in full rather than getting a synthesized answer. Judged an acceptable trade for removing the broken dependency.
