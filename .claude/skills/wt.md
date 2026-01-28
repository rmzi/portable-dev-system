# /wt — Worktree Management

Manage git worktrees for isolated parallel development.

## Invocation

```
/wt                  # Show current worktrees with status
/wt new <branch>     # Create worktree for existing branch
/wt create <branch>  # Create worktree with new branch
/wt remove           # Remove a worktree
/wt status           # Show all worktrees with git status
```

## When Invoked

### /wt or /wt status

List all worktrees with their branch and status:

```bash
git worktree list
```

For each worktree, show:
- Directory name
- Branch name
- Clean/dirty status
- Commits ahead/behind

### /wt new <branch>

Create a worktree for an existing branch:

```bash
# Naming convention: parent-dir-branch-name
# e.g., myproject -> myproject-feature-auth

BRANCH="$1"
DIR="../$(basename $(pwd))-${BRANCH//\//-}"
git worktree add "$DIR" "$BRANCH"
echo "Created worktree at: $DIR"
echo "To switch: cd $DIR"
```

### /wt create <branch>

Create a worktree with a new branch:

```bash
BRANCH="$1"
DIR="../$(basename $(pwd))-${BRANCH//\//-}"
git worktree add "$DIR" -b "$BRANCH"
echo "Created worktree at: $DIR"
echo "Branch: $BRANCH"
echo "To switch: cd $DIR"
```

### /wt remove

Show worktrees and ask which to remove:

```bash
git worktree list
# Ask user which to remove
git worktree remove <selected>
```

## Naming Convention

Worktree directories follow this pattern:
```
{project-name}-{branch-with-slashes-as-dashes}
```

Examples:
| Branch | Worktree Directory |
|--------|-------------------|
| `main` | `myproject/` (original) |
| `feature/auth` | `myproject-feature-auth/` |
| `hotfix/login-bug` | `myproject-hotfix-login-bug/` |
| `release/v2.0` | `myproject-release-v2.0/` |

## Shell Aliases Available

The user has these shell functions configured:

| Command | Action |
|---------|--------|
| `wt` | Fuzzy pick worktree, cd to it |
| `wty` | Fuzzy pick worktree, open in yazi |
| `wta <branch>` | Create worktree from existing branch |
| `wta -b <branch>` | Create worktree with new branch |
| `wtl` | List worktrees |
| `wtr` | Fuzzy pick worktree to remove |

## Best Practices

1. **One task per worktree** — Don't reuse worktrees for unrelated work
2. **Clean up after merge** — Remove worktrees once PRs are merged
3. **Name branches well** — The worktree directory inherits from branch name
4. **Keep main clean** — Main worktree should stay on main/master for reference

## Workflow Example

```bash
# Start new feature
wta -b feature/user-profiles
# Now in ../myproject-feature-user-profiles

# Open Claude Code
claude

# ... work on feature ...

# Meanwhile, urgent bug comes in - new terminal:
cd ~/dev/myproject
wta -b hotfix/critical-fix
# Now in ../myproject-hotfix-critical-fix

# Fix bug, PR, merge
# Clean up
wtr  # Select hotfix worktree to remove
```
