---
description: Verify PDS configuration is correct, complete, and secure
---
# /audit-config — Configuration Audit

Systematic verification of a PDS installation. Checks security, completeness, and consistency. Produces a letter grade (A-F) with actionable findings.

## When to Use

- After initial `install.sh` setup
- When inheriting a PDS project from another team
- Periodic security review
- Before onboarding new team members
- After upgrading PDS versions

## Audit Protocol

Run each check. Record pass/fail. Compute grade at the end.

### 1. Settings Security (40 points)

Read `.claude/settings.json` and verify:

- [ ] **Credential paths denied** (10 pts) — All of: `~/.aws`, `~/.ssh`, `~/.gnupg`, `~/.kube`, `~/.azure`, `~/.config/gcloud`, `~/.config/gh`, `~/.npmrc`, `~/.pypirc`, `~/.docker/config.json`, `~/.gem/credentials`, `~/.cargo/credentials` (both `~` and `$HOME` variants)
- [ ] **Protected branches denied** (10 pts) — Push to `main`, `master`, `dev`, `develop` blocked. Force push blocked. Delete push blocked. Refspec bypass blocked (`+main`, `:main`, `HEAD:main`)
- [ ] **Sensitive files denied** (10 pts) — Read/Write denied for `.env*`, `secrets/**`, `*.pem`, `*credential*`, `.git-credentials`, `id_rsa*`, `id_ed25519*`, `*secret*key*`, `*token*.json`
- [ ] **Remote access denied** (5 pts) — `ssh`, `scp`, `sftp` blocked
- [ ] **Prod patterns denied** (5 pts) — `PROD`, `prod.*`, `--profile prod`, `--profile=prod` blocked

### 2. Hooks Configuration (15 points)

- [ ] **SessionStart hook exists** (5 pts) — Version check against remote VERSION
- [ ] **PostToolUse hook exists** (5 pts) — Test reminder on Edit/Write
- [ ] **PermissionRequest hook exists** (5 pts) — LLM-based policy evaluation

### 3. Structure Completeness (20 points)

- [ ] **CLAUDE.md exists with PDS markers** (5 pts) — `<!-- PDS:START -->` and `<!-- PDS:END -->` present
- [ ] **Skills directory populated** (5 pts) — `.claude/skills/` has `.md` files with YAML frontmatter
- [ ] **Agents directory populated** (5 pts) — `.claude/agents/` has `.md` files with YAML frontmatter (project-level only)
- [ ] **Version file exists** (2 pts) — `.claude/.pds-version` present and non-empty
- [ ] **.gitignore has .worktrees/** (3 pts) — Worktree directory excluded from version control

### 4. Sensitive File Scan (15 points)

Search the repo for files that should NOT be committed:

- [ ] **No .env files tracked** (5 pts) — `git ls-files '*.env' '.env.*'` returns empty
- [ ] **No credential files tracked** (5 pts) — No `*.pem`, `*credential*`, `id_rsa*`, `id_ed25519*`, `*secret*key*` in git
- [ ] **No token files tracked** (5 pts) — No `*token*.json`, `.git-credentials` in git

### 5. Consistency (10 points)

- [ ] **CLAUDE.md skill table matches .claude/skills/** (5 pts) — Every skill in the table has a file, every file has a table entry
- [ ] **Valid JSON** (5 pts) — `python3 -c "import json; json.load(open('.claude/settings.json'))"` passes

## Grading

| Score | Grade | Meaning |
|-------|-------|---------|
| 90-100 | A | Production-ready, fully hardened |
| 80-89 | B | Good, minor gaps |
| 70-79 | C | Functional but missing security coverage |
| 60-69 | D | Significant gaps — fix before team use |
| <60 | F | Incomplete or insecure — do not use in production |

## Output Format

```
PDS Configuration Audit — [date]
Grade: [A-F] ([score]/100)

✓ Credential paths denied (10/10)
✗ Missing $HOME variants for ~/.kube (8/10)
...

Findings:
1. [CRITICAL] Missing deny rule for ~/.docker/config.json via $HOME
2. [WARNING] No PostToolUse hook configured
3. [INFO] .pds-version is 2.1.0, latest is 2.6.0

Recommendation: [one-line summary]
```

## See Also

- `/permission-router` — Hook policy details
- `/review` — Code review (different scope — reviews code, not config)
