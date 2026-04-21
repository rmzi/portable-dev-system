#!/usr/bin/env node
/**
 * pds-advisor — MCP server exposing the Anthropic `advisor_20260301` beta tool.
 *
 * Exposes a single MCP tool: `advisor_consult`.
 *
 * Input:  { prompt: string, max_uses?: number }
 * Output: { advice: string, degraded: boolean, reason?: string }
 *
 * Error paths (all return a structured response with degraded=true — never throw):
 *   - ANTHROPIC_API_KEY unset
 *   - 4xx/5xx from advisor-beta endpoint (retries without beta header as plain opus)
 *   - Network timeout
 *   - 401/403 auth failure
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";

const ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages";
const ANTHROPIC_VERSION = "2023-06-01";
const ADVISOR_BETA_HEADER = "advisor-tool-2026-03-01";
const MODEL = "claude-opus-4-7";
const DEFAULT_MAX_TOKENS = 2048;
const REQUEST_TIMEOUT_MS = 30_000;

interface AdvisorResponse {
  advice: string;
  degraded: boolean;
  reason?: string;
}

interface AnthropicMessageResponse {
  content?: Array<{ type: string; text?: string }>;
  error?: { type?: string; message?: string };
}

/**
 * Call the Anthropic /v1/messages endpoint.
 *
 * When `useAdvisorBeta` is true, include the advisor tool definition and the
 * `anthropic-beta: advisor-tool-2026-03-01` header. When false, make a plain
 * messages call without the tool or the beta header.
 */
async function callAnthropic(
  apiKey: string,
  prompt: string,
  useAdvisorBeta: boolean,
  maxUses: number,
): Promise<{ ok: true; text: string } | { ok: false; status: number; message: string }> {
  const body: Record<string, unknown> = {
    model: MODEL,
    max_tokens: DEFAULT_MAX_TOKENS,
    messages: [{ role: "user", content: prompt }],
  };

  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    "x-api-key": apiKey,
    "anthropic-version": ANTHROPIC_VERSION,
  };

  if (useAdvisorBeta) {
    body.tools = [
      {
        type: "advisor_20260301",
        name: "advisor",
        max_uses: maxUses,
      },
    ];
    headers["anthropic-beta"] = ADVISOR_BETA_HEADER;
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

  try {
    const res = await fetch(ANTHROPIC_API_URL, {
      method: "POST",
      headers,
      body: JSON.stringify(body),
      signal: controller.signal,
    });

    if (!res.ok) {
      const errText = await res.text().catch(() => "");
      return { ok: false, status: res.status, message: errText.slice(0, 500) };
    }

    const data = (await res.json()) as AnthropicMessageResponse;

    if (data.error) {
      return {
        ok: false,
        status: res.status,
        message: data.error.message ?? data.error.type ?? "unknown error",
      };
    }

    const text =
      (data.content ?? [])
        .filter((c) => c.type === "text" && typeof c.text === "string")
        .map((c) => c.text!)
        .join("\n") || "";

    return { ok: true, text };
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    const isAbort = err instanceof Error && err.name === "AbortError";
    return {
      ok: false,
      status: 0,
      message: isAbort ? "timeout" : message,
    };
  } finally {
    clearTimeout(timeout);
  }
}

/**
 * Orchestrate the advisor call with graceful fallback.
 *
 * Flow:
 *   1. If no API key, return degraded immediately.
 *   2. Try advisor beta. Succeed -> return.
 *   3. On 4xx/5xx/network/timeout, retry as plain opus without tool or beta header.
 *   4. If plain opus fails too, return degraded with the failure reason.
 *   5. On 401/403, return degraded with auth-failed reason (do NOT retry — auth is not an env issue the fallback can solve).
 */
export async function advise(
  prompt: string,
  maxUses: number = 1,
): Promise<AdvisorResponse> {
  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    return {
      advice: "",
      degraded: true,
      reason: "advisor unavailable — set ANTHROPIC_API_KEY",
    };
  }

  // Attempt 1: advisor beta
  const betaResult = await callAnthropic(apiKey, prompt, true, maxUses);
  if (betaResult.ok) {
    return { advice: betaResult.text, degraded: false };
  }

  // Auth failures are not recoverable via fallback — surface directly.
  if (betaResult.status === 401 || betaResult.status === 403) {
    return {
      advice: "",
      degraded: true,
      reason: `auth failed (${betaResult.status})`,
    };
  }

  // Log to stderr so the shepherd can observe the degradation.
  process.stderr.write(
    `[pds-advisor] beta path failed (status=${betaResult.status}, reason=${betaResult.message}); falling back to plain opus\n`,
  );

  // Attempt 2: plain opus (no advisor tool, no beta header)
  const plainResult = await callAnthropic(apiKey, prompt, false, 0);
  if (plainResult.ok) {
    return {
      advice: plainResult.text,
      degraded: true,
      reason: `beta unavailable (${betaResult.status}: ${betaResult.message}); fell back to plain opus`,
    };
  }

  // Both paths failed.
  return {
    advice: "",
    degraded: true,
    reason: `advisor unreachable — beta status=${betaResult.status}, plain status=${plainResult.status}`,
  };
}

// ---------------------------------------------------------------------------
// MCP server wiring
// ---------------------------------------------------------------------------

const TOOL_NAME = "advisor_consult";
const TOOL_DESCRIPTION =
  "Consult the PDS advisor (wraps Anthropic advisor_20260301 beta tool with graceful fallback to plain opus).";

const TOOL_INPUT_SCHEMA = {
  type: "object",
  properties: {
    prompt: {
      type: "string",
      description:
        "The question or scenario to consult the advisor on. Include enough context for the advisor to give useful advice.",
    },
    max_uses: {
      type: "integer",
      description:
        "Maximum advisor tool invocations within this call. Defaults to 1.",
      default: 1,
      minimum: 1,
      maximum: 10,
    },
  },
  required: ["prompt"],
  additionalProperties: false,
} as const;

export function createServer(): Server {
  const server = new Server(
    {
      name: "pds-advisor",
      version: "0.1.0",
    },
    {
      capabilities: {
        tools: {},
      },
    },
  );

  server.setRequestHandler(ListToolsRequestSchema, async () => ({
    tools: [
      {
        name: TOOL_NAME,
        description: TOOL_DESCRIPTION,
        inputSchema: TOOL_INPUT_SCHEMA,
      },
    ],
  }));

  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    if (request.params.name !== TOOL_NAME) {
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify({
              advice: "",
              degraded: true,
              reason: `unknown tool: ${request.params.name}`,
            }),
          },
        ],
        isError: true,
      };
    }

    const args = (request.params.arguments ?? {}) as {
      prompt?: unknown;
      max_uses?: unknown;
    };

    const prompt = typeof args.prompt === "string" ? args.prompt : "";
    const maxUses =
      typeof args.max_uses === "number" && Number.isFinite(args.max_uses)
        ? Math.max(1, Math.min(10, Math.floor(args.max_uses)))
        : 1;

    if (!prompt) {
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify({
              advice: "",
              degraded: true,
              reason: "prompt is required",
            }),
          },
        ],
        isError: true,
      };
    }

    try {
      const result = await advise(prompt, maxUses);
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify(result),
          },
        ],
      };
    } catch (err) {
      // The advise() function should not throw, but defend against it anyway
      // — the MCP handler contract forbids exceptions bubbling out.
      const message = err instanceof Error ? err.message : String(err);
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify({
              advice: "",
              degraded: true,
              reason: `advisor internal error: ${message}`,
            }),
          },
        ],
        isError: true,
      };
    }
  });

  return server;
}

async function main(): Promise<void> {
  const server = createServer();
  const transport = new StdioServerTransport();
  await server.connect(transport);
  process.stderr.write("[pds-advisor] MCP server ready on stdio\n");
}

// Auto-run only when invoked as the main module.
const isMainModule =
  import.meta.url === `file://${process.argv[1]}` ||
  process.argv[1]?.endsWith("/server.js") ||
  process.argv[1]?.endsWith("\\server.js");

if (isMainModule) {
  main().catch((err) => {
    const message = err instanceof Error ? err.message : String(err);
    process.stderr.write(`[pds-advisor] fatal: ${message}\n`);
    process.exit(1);
  });
}
