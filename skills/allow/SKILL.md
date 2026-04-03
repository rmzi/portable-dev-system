---
description: Add a directory path to the Claude Code sandbox write allowlist
---
# /allow — Sandbox Write Allowlist

Thin wrapper for adding paths to `sandbox.write.allowOnly` with safety guardrails.

## Usage

```
/pds:allow ~/.cargo
/pds:allow /path/to/project
```

## Protocol

When invoked with a path argument:

**1. Parse the path argument**
Extract the path from the invocation (everything after `/pds:allow`). Trim whitespace.

**2. Expand `~` to `$HOME`**
Replace a leading `~` with the value of `$HOME`. Never pass `~` literally to the config command.

**3. Validate path exists**
Check if the expanded path exists on disk. If it does not:
- Warn: "Path does not exist: `<path>`. Adding anyway — verify it's correct."
- Proceed regardless (user may be pre-allowing a path not yet created).

**4. Check for sensitive paths**
Compare the expanded path against known credential locations:
- `~/.ssh` / `$HOME/.ssh`
- `~/.aws` / `$HOME/.aws`
- `~/.gnupg` / `$HOME/.gnupg`
- `~/.config/gcloud` / `$HOME/.config/gcloud`
- Any path matching `*credentials*`

If the path matches, warn before proceeding:
> "Warning: `<path>` contains credentials. Allowing write access here could expose secrets. Are you sure? (y/N)"

Wait for confirmation. If the user confirms, proceed. If they decline or don't respond affirmatively, abort with: "Aborted. Path not added."

Do NOT block unconditionally — this is a guardrail, not a hard deny.

**5. Run the config command**
```bash
claude config set --global sandbox.write.allowOnly <expanded_path>
```

**6. Confirm**
Output: "Added `<expanded_path>` to sandbox write allowlist."

## Example

```
/pds:allow ~/.cargo

> Added `/Users/alice/.cargo` to sandbox write allowlist.
```

```
/pds:allow ~/.ssh

> Warning: `/Users/alice/.ssh` contains credentials. Allowing write access here
> could expose secrets. Are you sure? (y/N): y
> Added `/Users/alice/.ssh` to sandbox write allowlist.
```

## See Also

- `/pds:sandbox` — Full sandbox configuration reference
- `/pds:audit-config` — Verify sandbox setup is correct
