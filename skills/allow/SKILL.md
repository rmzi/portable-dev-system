---
description: Add a directory path to the Claude Code sandbox write allowlist
---
# /allow — Sandbox Write Allowlist

Adds paths to the sandbox filesystem write allowlist. Because `~/.claude/settings.json` is inside the sandbox's `denyWithinAllow` list, this skill uses an escalation path — either `dangerouslyDisableSandbox` or the `!` prefix terminal bypass.

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

**5. Run the config command (escalation path)**

The config command writes to `~/.claude/settings.json`, which is inside the sandbox's `denyWithinAllow`. Two escalation options, tried in order:

**Option A — `dangerouslyDisableSandbox`** (preferred, keeps agent in the loop):
```bash
# Use dangerouslyDisableSandbox: true on the Bash tool call
claude config set --global sandbox.filesystem.allowWrite <expanded_path>
```
The user will be prompted to approve the unsandboxed execution. If they approve, proceed to step 6.

**Option B — `!` prefix terminal bypass** (fallback if Option A is denied or unavailable):

If the user denies `dangerouslyDisableSandbox`, output the exact command for the user to run via the terminal:
```
Run this in the terminal (type it directly, or copy-paste with the ! prefix):

  ! claude config set --global sandbox.filesystem.allowWrite <expanded_path>

The ! prefix runs the command in your shell, bypassing the sandbox.
```

Wait for the user to confirm they ran it, then proceed to step 6.

**6. Confirm**
Output: "Added `<expanded_path>` to sandbox write allowlist. Restart the session for the change to take effect."

## Example

```
/pds:allow ~/.cargo

> Added `/Users/alice/.cargo` to sandbox write allowlist.
> Restart the session for the change to take effect.
```

```
/pds:allow ~/.ssh

> Warning: `/Users/alice/.ssh` contains credentials. Allowing write access here
> could expose secrets. Are you sure? (y/N): y
> Added `/Users/alice/.ssh` to sandbox write allowlist.
> Restart the session for the change to take effect.
```

```
# If dangerouslyDisableSandbox is denied:

/pds:allow ~/projects/data

> Sandbox prevents writing to settings. Run this in the terminal:
>
>   ! claude config set --global sandbox.filesystem.allowWrite /Users/alice/projects/data
>
> The ! prefix bypasses the sandbox.
```

## See Also

- `/pds:sandbox` — Full sandbox configuration reference (includes escalation model)
- `/pds:audit-config` — Verify sandbox setup is correct
