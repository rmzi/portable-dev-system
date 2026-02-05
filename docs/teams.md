# Team Setup

## Quick Start for Team Members

```bash
# 1. Install PDS (one-time)
curl -fsSL https://raw.githubusercontent.com/rmzi/portable-dev-system/main/install.sh | bash
source ~/.zshrc

# 2. Clone your repo - skills are already there
git clone <your-repo>
cd <your-repo>
```

---

## Adding PDS to Your Repo

```bash
cd your-team-repo
pds-init
git add .claude CLAUDE.md
git commit -m "feat: add PDS skills for team workflow"
```

Now every team member gets:
- Same code review checklist (`/review`)
- Same commit conventions (`/commit`)
- Same debugging protocol (`/debug`)
- Same architecture decision format (`/design`)

**No more "how do we do X here?"** — it's encoded in the skills.

---

## Customizing Skills

Add your own skills to `.claude/skills/`:

```
.claude/skills/
├── deploy.md      # Your deploy process
├── oncall.md      # Incident response
├── pr.md          # PR conventions
├── api.md         # API design guidelines
└── ...
```

### Skill Template

```markdown
# Skill Name

## When to Use
- Trigger conditions

## Process
1. Step one
2. Step two

## Checklist
- [ ] Item one
- [ ] Item two
```

---

## Onboarding

New team member setup:

1. Install dependencies: `brew install yazi zoxide fzf tmux starship ripgrep fd bat`
2. Run installer: `curl -fsSL .../install.sh | bash`
3. Clone repo (skills included)
4. Start working

Time: ~5 minutes.

---

## Permissions Model

PDS includes a velocity-focused `.claude/settings.json` that balances speed with safety.

### What's Auto-Allowed
- All read operations
- All file writes/edits within the repo
- All bash commands (with exceptions below)
- All MCP tools
- Web fetches and searches

### What's Blocked

**Credential paths** (never touched):
- `~/.aws`, `~/.ssh`, `~/.gnupg`
- `~/.config/gcloud`, `~/.databrickscfg`, `~/.netrc`

**Git guardrails**:
- Push to `main`, `master`, `dev`, `develop`
- Force push (`-f`, `--force`)
- Branch deletion via push

**Prod patterns**:
- Commands with `PROD`, `prod.`, `--profile prod`
- `ssh` and `scp` to remote hosts

**Sensitive files**:
- `.env`, `.env.*`, `secrets/`, `*.pem`, `*credential*`

### Customizing

Add to your repo's `.claude/settings.json`:

```json
{
  "permissions": {
    "deny": [
      "mcp__your_prod_tool__*",
      "Bash(*your-prod-db*)"
    ]
  }
}
```

### Philosophy

Everything in git is recoverable. Local dev data is rebuildable. CI/CD validates branches. So:
- **Dev = velocity** — let Claude move fast
- **Prod = guardrails** — block credential paths and prod patterns

This gives you `--dangerously-skip-permissions` velocity without the risk of touching prod.

---

## Keeping Skills Updated

When you update skills in your repo:
1. Team members pull changes
2. Skills are automatically available

For PDS core updates:
```bash
pds-update      # Update project skills
pds-update -s   # Update shell helpers
```
