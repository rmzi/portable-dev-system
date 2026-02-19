# Parallel Agent Coordination Protocol

Drop this into your project's `CLAUDE.md` to enable multi-agent parallel development with file ownership, lock-based coordination, and structured decomposition.

Designed for projects with clear architectural layers (e.g., Tauri: Rust backend + TypeScript frontend + tests). Adapt the zones to your project structure.

---

## CLAUDE.md Section (copy below into your project)

```markdown
<!-- PARALLEL-AGENTS:START -->
## Parallel Agent Coordination

### File Ownership Zones

Each agent owns a zone. Agents may only create or modify files within their zone unless they acquire a lock on a shared file.

| Zone | Agent | Owned Paths | Responsibility |
|------|-------|-------------|----------------|
| Backend | `agent-backend` | `src-tauri/src/**` | Rust commands, app state, database, IPC handlers |
| Frontend | `agent-frontend` | `src/components/**`, `src/stores/**`, `src/styles/**` | UI components, state management, styling |
| Testing | `agent-testing` | `tests/**`, `src/**/*.test.*` | E2E tests, integration tests, unit tests |

### Shared Zones (lock required)

These files sit at architectural boundaries. Any agent may edit them, but must acquire a lock first.

| Path | Why Shared | Typical Editor |
|------|-----------|----------------|
| `src-tauri/src/commands/mod.rs` | IPC command registry | agent-backend |
| `src/lib/bindings.ts` | Frontend IPC type bindings | agent-frontend |
| `src-tauri/Cargo.toml` | Rust dependencies | agent-backend |
| `package.json` | JS dependencies | agent-frontend |
| `src-tauri/tauri.conf.json` | App configuration | agent-backend |

### Lock-File Convention

Before editing a shared file, an agent must acquire a lock. Locks live in `.agent/locks/`.

**Acquire:**
```bash
mkdir -p .agent/locks
cat > .agent/locks/$(echo "path/to/file" | tr '/' '-').lock << EOF
agent: agent-backend
file: src-tauri/Cargo.toml
acquired: $(date -u +%Y-%m-%dT%H:%M:%SZ)
reason: adding serde_json dependency
EOF
```

**Release:** Delete the lock file after committing:
```bash
rm .agent/locks/src-tauri-Cargo.toml.lock
```

**Rules:**
1. Check for existing locks before editing shared files
2. If a lock exists, **wait** — do not edit the file
3. Locks expire after 30 minutes (stale lock = agent crashed, safe to break)
4. Only the lock holder or the coordinator may remove a lock
5. Commit the lock file so other worktrees see it after fetch

### IPC Contract Convention

The boundary between backend and frontend is the IPC layer. Define contracts **before** agents start working so both sides can develop in parallel.

Contract file: `.swarm/contracts.md`

```markdown
## IPC Contracts for [Feature Name]

### command: get_user_profile
- **Input:** `{ user_id: string }`
- **Output:** `{ name: string, email: string, avatar_url: string | null }`
- **Errors:** `UserNotFound`, `DatabaseError`
- **Backend:** `src-tauri/src/commands/user.rs`
- **Frontend:** `src/components/UserProfile.vue` (or .tsx)

### command: update_settings
- **Input:** `{ theme: "light" | "dark", language: string }`
- **Output:** `{ success: boolean }`
- **Errors:** `ValidationError`
- **Backend:** `src-tauri/src/commands/settings.rs`
- **Frontend:** `src/components/SettingsPanel.vue`
```

Both agents develop against the contract. Mismatches surface at integration, not deployment.

### Task Decomposition Template

The coordinator fills this out before spawning agents:

```markdown
## Feature: [Name]
**Coordinator branch:** feature/[name]
**Date:** YYYY-MM-DD

### Contracts
[Define IPC contracts above FIRST]

### Sub-Tasks

#### Task 1: Backend — [description]
- **Agent:** agent-backend
- **Branch:** feature/[name]/backend
- **Worktree:** .worktrees/feature-[name]-backend
- **Owned files:** src-tauri/src/commands/[module].rs, src-tauri/src/state/[module].rs
- **Inputs:** IPC contracts from .swarm/contracts.md
- **Outputs:** Working Tauri commands matching contract signatures
- **Acceptance criteria:**
  - [ ] Commands compile and match contract types
  - [ ] Error variants defined and returned
  - [ ] State mutations are atomic

#### Task 2: Frontend — [description]
- **Agent:** agent-frontend
- **Branch:** feature/[name]/frontend
- **Worktree:** .worktrees/feature-[name]-frontend
- **Owned files:** src/components/[Component].vue, src/stores/[store].ts
- **Inputs:** IPC contracts from .swarm/contracts.md
- **Outputs:** Components that invoke commands per contract
- **Acceptance criteria:**
  - [ ] Components render with mock data
  - [ ] invoke() calls match contract signatures
  - [ ] Loading and error states handled

#### Task 3: Testing — [description]
- **Agent:** agent-testing
- **Branch:** feature/[name]/testing
- **Worktree:** .worktrees/feature-[name]-testing
- **Owned files:** tests/e2e/[feature].spec.ts, tests/integration/[feature].test.rs
- **Inputs:** Contracts + acceptance criteria from tasks 1 and 2
- **Outputs:** Test suite covering all contract endpoints
- **Acceptance criteria:**
  - [ ] Each IPC command has a round-trip test
  - [ ] Error cases tested per contract
  - [ ] E2E flow covers the happy path
```

### Merge Coordination

Merge order is **foundation first** — backend changes are the base that frontend and tests build on.

```
Merge order: [backend, frontend, testing]

Round 1: agent-backend rebases onto coordinator, merges (ff-only)
         agent-frontend and agent-testing rebase onto updated coordinator
Round 2: agent-frontend rebases onto coordinator, merges (ff-only)
         agent-testing rebases onto updated coordinator
Round 3: agent-testing rebases onto coordinator, merges (ff-only)
         Final: run full test suite on coordinator
```

**Rules:**
1. Backend merges first — it defines the IPC surface that others depend on
2. Frontend merges second — it consumes the backend contracts
3. Testing merges last — it validates both layers together
4. After each merge, remaining agents rebase and re-run their tests
5. If a rebase produces conflicts, the rebasing agent resolves them (they understand their changes best)
6. The coordinator runs the full test suite after all merges complete
7. See `/merge` for the detailed rebase-then-fast-forward protocol

### Monitoring

```bash
# Check agent status
for dir in .worktrees/*/; do
  echo "=== $dir ==="
  cat "$dir/.agent/status.md" 2>/dev/null || echo "no status"
done

# Check active locks
ls -la .agent/locks/ 2>/dev/null || echo "no locks"

# Check contract compliance (after merge)
# Backend: do all commands match contract signatures?
# Frontend: do all invoke() calls match contract signatures?
```
<!-- PARALLEL-AGENTS:END -->
```

---

## Example: Decomposing a Feature

Here's a concrete decomposition for a "User Profile" feature in a Tauri app:

### Setup

```bash
REPO_ROOT="$(git rev-parse --path-format=absolute --git-common-dir | sed 's|/.git$||')"

# Create coordinator branch
git worktree add "$REPO_ROOT/.worktrees/feature-profile" -b feature/user-profile

# Create agent worktrees
git worktree add "$REPO_ROOT/.worktrees/feature-profile-backend" -b feature/user-profile/backend feature/user-profile
git worktree add "$REPO_ROOT/.worktrees/feature-profile-frontend" -b feature/user-profile/frontend feature/user-profile
git worktree add "$REPO_ROOT/.worktrees/feature-profile-testing" -b feature/user-profile/testing feature/user-profile
```

### Contracts (written FIRST by coordinator)

```markdown
## IPC Contracts for User Profile

### command: get_user_profile
- Input: `{ user_id: string }`
- Output: `{ id: string, name: string, email: string, avatar_url: string | null, created_at: string }`
- Errors: `UserNotFound`, `DatabaseError`

### command: update_user_profile
- Input: `{ user_id: string, name?: string, email?: string, avatar_url?: string }`
- Output: `{ success: boolean, updated_at: string }`
- Errors: `UserNotFound`, `ValidationError`, `DatabaseError`

### event: profile-updated
- Payload: `{ user_id: string, fields: string[] }`
- Direction: backend → frontend
```

### Agent Dispatch

Each agent reads `.agent/task.md` in their worktree and works autonomously against the contracts. The coordinator monitors `.agent/status.md` in each worktree.

### Merge

After all agents report `done`:
1. `agent-backend` rebases onto `feature/user-profile`, coordinator fast-forward merges
2. `agent-frontend` rebases onto updated `feature/user-profile`, coordinator merges
3. `agent-testing` rebases onto updated `feature/user-profile`, coordinator merges
4. Full test suite on `feature/user-profile`
5. PR from `feature/user-profile` → `main`
