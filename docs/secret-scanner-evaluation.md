# Secret Scanner Evaluation: sentinel-ai vs detect-secrets

## Problem Statement

PDS uses a PostToolUse hook for secret scrubbing (gitleaks + regex redaction). This evaluation examines two additional tools — **sentinel-ai** and **detect-secrets** — to determine whether either should replace or complement the existing approach for hook-based secret detection in Claude Code workflows.

**Key constraint:** PDS's security philosophy is *scrub, don't block* — secrets should be redacted from output, not used to block commands. Any tool evaluated here must fit that model or be used in a way that does.

---

## Tool Profiles

### sentinel-ai (MaxwellCalkin)

**Repo:** `github.com/MaxwellCalkin/sentinel-ai`  
**Install:** `pip install sentinel-guardrails` (Python) or `npm install @sentinel-ai/sdk` (TypeScript)  
**License:** Apache 2.0

sentinel-ai is a real-time safety scanning layer for LLM applications. Its `secrets_scanner.py` module is one of 11 built-in scanners covering OWASP LLM Top 10 vulnerabilities. It was built specifically with Claude Code hook integration in mind.

**Secret detection scope (`secrets_scanner.py`):**
- Cloud credentials: AWS, Azure, Google, Firebase
- Code platform tokens: GitHub, npm, PyPI
- Payment/SaaS: Stripe, Twilio, SendGrid
- AI provider keys (OpenAI, Anthropic, etc.)
- Private crypto keys (RSA, EC, etc.)
- Generic high-entropy strings + connection strings
- 40+ patterns total

**Detection methodology:** Regex pattern matching + entropy analysis. Smart filtering skips comments, placeholder values, and environment variable references to reduce false positives.

---

### detect-secrets (Yelp)

**Repo:** `github.com/Yelp/detect-secrets`  
**Install:** `pip install detect-secrets` or `brew install detect-secrets`  
**Latest version:** 1.5.0 (May 2024)  
**License:** Apache 2.0

detect-secrets is Yelp's production-grade secret scanner with a baseline model. It compares current codebase state against a committed JSON baseline — existing secrets in the baseline are accepted; new secrets trigger failures. Plugin-based with 27 built-in detectors and support for custom regex plugins.

**Detection methodology:** Heuristic regex on git diffs (not full history). Baseline file (`/.secrets.baseline`) tracks known secrets as hashes. Scans changed files only, avoiding full-repo overhead.

---

## Side-by-Side Comparison

| Dimension | sentinel-ai | detect-secrets |
|-----------|-------------|----------------|
| **Language** | Python + TypeScript | Python only |
| **Installation** | `pip install sentinel-guardrails` | `pip install detect-secrets` |
| **Secret patterns** | 40+ (cloud, SaaS, AI, crypto, generic) | 27 built-in detectors + custom regex |
| **Scan latency** | ~0.05ms average | Not published; regex on git diffs |
| **False positive handling** | Entropy analysis + smart filter (skips comments/placeholders) | Baseline JSON + `# pragma: allowlist secret` + word lists |
| **PostToolUse hook fit** | Native Claude Code hook support (PreToolUse) | Not hook-native; pre-commit focused |
| **Baseline model** | No — stateless per-scan | Yes — JSON baseline for allowlisting |
| **Maintenance** | New project (1 author) | Mature (Yelp, 1,450+ commits) |
| **Dependencies** | `regex` only | Python stdlib + optional extras |
| **CI/CD integration** | Git pre-commit via `sentinel init` | Pre-commit framework |
| **Benchmark** | 530 cases, 100% accuracy, 457 tests | Production-grade at Yelp scale |
| **LLM/Claude Code native** | Yes — designed for Claude Code hooks | No — general-purpose code scanner |

---

## Analysis

### Installation Complexity

Both are simple pip installs. detect-secrets is more established in package managers (Homebrew support). sentinel-ai requires a newer pip. Neither has significant installation friction.

**Winner: Tie.** Both are one-line installs.

### Latency

sentinel-ai publishes a specific benchmark: **~0.05ms per scan**. This is critical for a PostToolUse hook — any noticeable latency will degrade the developer experience on every tool call.

detect-secrets is optimized for git-diff scanning (not per-call scanning) and publishes no per-call latency figures. Its regex approach should be fast, but it's not instrumented for the hook use case.

**Winner: sentinel-ai** — documented sub-millisecond latency, purpose-built for inline scanning.

### False Positive Handling

sentinel-ai's entropy analysis + smart filtering (ignoring comments and `ENV_VAR` patterns) handles the most common false positive sources automatically, without configuration.

detect-secrets requires upfront work: creating and committing a baseline file, annotating known-false-positives with `# pragma: allowlist secret`, and managing word lists. This is powerful for codebase-wide baseline workflows, but adds maintenance overhead for a per-call hook model.

**Winner: sentinel-ai** for hook use; **detect-secrets** for baseline/codebase audit workflows.

### PostToolUse Hook Integration Feasibility

sentinel-ai is explicitly designed for Claude Code's hook system. The README documents adding it to `.claude/settings.json` as a PreToolUse hook. Adapting it to PostToolUse is straightforward — the scan function takes text input and returns findings.

detect-secrets is designed around the pre-commit framework and a baseline file. It requires a git-committed baseline and is oriented toward diff-scanning on commit. Using it as a per-call PostToolUse hook requires stripping away the baseline machinery and running it in a stateless mode — possible but against the grain of the tool.

**Winner: sentinel-ai** — native hook model, stateless per-scan API.

### Maintenance Burden

detect-secrets: 1,450+ commits, production use at Yelp, stable v1.5.0, actively maintained. Risk is low.

sentinel-ai: Single author (MaxwellCalkin), newer project, published on PyPI and MCP marketplace. Lower bus factor. Benchmark claims (100% accuracy on 530 cases) are not independently verified.

**Winner: detect-secrets** — significantly more mature.

---

## Recommendation

**Use sentinel-ai's `secrets_scanner.py` for PostToolUse hook integration.**

For PDS's specific use case — real-time scanning of Claude Code tool output before it reaches the conversation — sentinel-ai is the right fit:

1. It was built for Claude Code hooks
2. Sub-millisecond latency is documented and essential
3. Stateless API model matches PostToolUse semantics
4. 40+ secret patterns cover the relevant credential types
5. Entropy analysis reduces false positives without config overhead

detect-secrets is the better choice for **codebase-wide auditing** (CI/CD pre-commit, baseline tracking, one-time scans of existing repos). It complements, rather than competes with, sentinel-ai in the hook context.

**Important caveat:** sentinel-ai is a newer, single-author project. Before integrating, verify:
- The PyPI package is current and matches the GitHub repo
- The `secrets_scanner.py` module is importable as a standalone function (not requiring the full sentinel-ai server)
- Latency holds on the actual hook call path (Python startup + import amortized or pre-loaded)

---

## Draft Hook Pseudocode (sentinel-ai)

```python
#!/usr/bin/env python3
"""
PostToolUse hook: scan tool output for secrets via sentinel-ai.
Redacts (does not block) detected secrets — consistent with PDS scrub-not-block philosophy.
"""

import json
import sys
import re

try:
    from sentinel_guardrails.scanners.secrets_scanner import SecretsScanner
    scanner = SecretsScanner()
    SENTINEL_AVAILABLE = True
except ImportError:
    SENTINEL_AVAILABLE = False


REDACT_PLACEHOLDER = "[REDACTED]"


def redact_secrets(text: str) -> str:
    """Scan text for secrets; replace matches with placeholder."""
    if not SENTINEL_AVAILABLE or not text:
        return text

    result = scanner.scan(text)
    if not result.has_findings:
        return text

    redacted = text
    for finding in result.findings:
        # Replace the matched secret value in the output
        if finding.matched_value:
            redacted = redacted.replace(finding.matched_value, REDACT_PLACEHOLDER)

    return redacted


def main():
    event = json.load(sys.stdin)
    tool_output = event.get("tool_response", {}).get("content", "")

    if isinstance(tool_output, str):
        cleaned = redact_secrets(tool_output)
        event["tool_response"]["content"] = cleaned
    elif isinstance(tool_output, list):
        for block in tool_output:
            if isinstance(block, dict) and block.get("type") == "text":
                block["text"] = redact_secrets(block.get("text", ""))

    print(json.dumps(event))


if __name__ == "__main__":
    main()
```

---

## Next Steps

1. **Verify sentinel-ai PyPI package** — confirm `sentinel_guardrails.scanners.secrets_scanner` is importable standalone
2. **Benchmark hook latency** — measure wall-clock time for the hook on realistic Bash tool output
3. **Test false positive rate** — run against PDS's own source tree; tune if needed
4. **Wire into PostToolUse** — add to `.claude/settings.json` alongside existing gitleaks hook
5. **Fallback strategy** — if sentinel-ai is unavailable (import error), fall through to gitleaks

---

## Sources

- [Sentinel AI — awesome-claude-code issue #943](https://github.com/hesreallyhim/awesome-claude-code/issues/943)
- [Sentinel AI README (raw)](https://raw.githubusercontent.com/MaxwellCalkin/sentinel-ai/main/README.md)
- [detect-secrets — Yelp GitHub](https://github.com/Yelp/detect-secrets)
- [detect-secrets — PyPI](https://pypi.org/project/detect-secrets/)
- [detect-secrets design docs](https://github.com/Yelp/detect-secrets/blob/master/docs/design.md)
- [detect-secrets 2026 overview — appsecsanta.com](https://appsecsanta.com/detect-secrets)
