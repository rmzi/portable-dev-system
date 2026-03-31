---
description: "DEPRECATED — Permission hook removed in v4.6.0. See /pds:sandbox for current security model."
---
# Permission Router (Deprecated)

> **Deprecated in PDS v4.6.0.** The PermissionRequest hook has been removed. Its deny patterns were 100% duplicated by static deny rules in `permissions.deny`. Auto mode's classifier provides dynamic evaluation with more context. In non-auto modes, deny rules + user prompts provide equivalent coverage.

## What Changed

- The `PermissionRequest` prompt hook in `hooks/hooks.json` has been removed
- Static deny rules (`permissions.deny` in settings.json) cover all patterns the hook evaluated
- Auto mode's transcript classifier replaces the hook's dynamic evaluation with broader context (full conversation history vs. single request)
- In non-auto modes (default, acceptEdits, plan), Claude Code's built-in user prompts handle cases not covered by deny rules
- The security model has been simplified from 7 layers to 6

## Migration

No action required. Security coverage is unchanged:
- Credential paths, protected branches, sensitive files, prod patterns → static deny rules (unchanged)
- Git/docker operations on feature branches → user prompts (non-auto) or classifier (auto mode)
- Sandboxed Bash → auto-approved by sandbox (unchanged)

## See Also

- `/pds:sandbox` — Current security model (6 layers), auto mode interaction, CI/CD guidance
- `/pds:audit-config` — Verify your configuration after upgrade
