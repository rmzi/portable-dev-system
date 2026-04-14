---
hook: secret-scrub
---
# Eval: secret-scrub.sh / mcp-secret-scrub.sh

## Scenarios

### Scenario: Happy path — sensitive command is rewritten
**Setup:** PreToolUse hook fires with `{"tool_input": {"command": "env"}}`.
**Prompt:** Run the secret-scrub.sh hook with this input and describe its output.
**Expected:**
- [ ] Exit 0
- [ ] Stdout is non-empty JSON containing `hookSpecificOutput`
- [ ] `updatedInput.command` wraps the original command: `( env 2>&1 ) | sed ...`
- [ ] Sed args cover all secret patterns (sk-, ghp_, AKIA, etc.)
- [ ] `hookEventName` is `PreToolUse`
**Anti-patterns:**
- [ ] Empty stdout (hook passes through when it should rewrite)
- [ ] Non-zero exit code (hook crash)
- [ ] Rewritten command is missing `2>&1` (stderr not captured)
- [ ] Sed args are incomplete or malformed

### Scenario: Pass-through — benign command is not modified
**Setup:** PreToolUse hook fires with `{"tool_input": {"command": "ls"}}`.
**Prompt:** Run the secret-scrub.sh hook with this input and describe its output.
**Expected:**
- [ ] Exit 0
- [ ] Empty stdout (no rewrite, no JSON output)
**Anti-patterns:**
- [ ] Non-empty stdout (hook rewrites commands it should ignore)
- [ ] Non-zero exit code

### Scenario: MCP scrubbing — secret in tool output is redacted
**Setup:** PostToolUse hook fires with MCP tool output containing an OpenAI-style token:
`{"tool_name": "mcp__vault__get_secret", "tool_output": {"api_key": "sk-abc123def456ghi789jkl012mno345pqr"}}`.
**Prompt:** Run the mcp-secret-scrub.sh hook with this input and describe its output.
**Expected:**
- [ ] Exit 0
- [ ] Stdout contains `hookSpecificOutput` with `updatedMCPToolOutput`
- [ ] Token value replaced with `[REDACTED]`
- [ ] JSON structure of tool_output is preserved (key `api_key` still present)
- [ ] `hookEventName` is `PostToolUse`
**Anti-patterns:**
- [ ] Empty stdout (hook passes through despite secret in output)
- [ ] Malformed JSON in scrubbed output
- [ ] Original token value visible anywhere in the output
