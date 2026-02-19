# Parallel Agent Coordination Protocol

Multi-agent parallel development using worktree isolation and contract-first decomposition.

## What Goes in Your Project's CLAUDE.md

Add this section. Adapt the zones and shared boundaries to your project structure.

```markdown
## Agent Zones

Decomposition guidance for `/swarm`. Each zone maps to one worker agent in its own worktree.

| Zone | Paths | Merge Order |
|------|-------|-------------|
| backend | `src-tauri/src/**` | 1 (foundation) |
| frontend | `src/components/**`, `src/stores/**`, `src/styles/**` | 2 |
| testing | `tests/**`, `src/**/*.test.*` | 3 (last) |

**Boundary contract:** The IPC layer (`#[tauri::command]` ↔ `invoke()`). Coordinator writes `.swarm/contracts.md` before dispatching agents. Both sides develop against the contract.

**Merge order is foundation-first.** Backend defines the IPC surface → frontend consumes it → testing validates both. See `/merge`.
```

That's it. ~12 lines. The orchestrator reads this during `/swarm` Phase 1 and handles the rest.

## What the Orchestrator Does Automatically

Given the zones above, `/swarm` proceeds normally — the zones just inform decomposition:

1. **Phase 1 (Plan):** Reads Agent Zones from CLAUDE.md. Runs `/grill`. Writes `.swarm/contracts.md` defining the IPC boundary (command names, input/output types, error variants).

2. **Phase 2 (Decompose):** Creates one worktree per zone. Writes `.agent/task.md` in each, referencing the contracts. Each task specifies which zone's paths the agent owns.

3. **Phase 3 (Execute):** Agents work in isolated worktrees. No file conflicts possible — worktree isolation handles it. No locks needed.

4. **Phase 4 (Validate):** Validator merges in zone order (backend → frontend → testing), rebasing each onto the updated coordinator. Runs full test suite after each merge.

5. **Phase 5 (Consolidate):** PR from coordinator branch to main.

## Contract Format

The only new artifact is `.swarm/contracts.md`. The coordinator writes this during Phase 1:

```markdown
## Contracts: [Feature Name]

### command: get_user_profile
- Input: `{ user_id: string }`
- Output: `{ name: string, email: string, avatar_url: string | null }`
- Errors: `UserNotFound`, `DatabaseError`

### command: update_settings
- Input: `{ theme: "light" | "dark", language: string }`
- Output: `{ success: boolean }`
- Errors: `ValidationError`
```

Both agents code against this. Mismatches surface at merge, not deployment.

## Adapting to Other Architectures

The pattern generalizes. Replace the zones:

| Architecture | Zone 1 | Zone 2 | Zone 3 |
|---|---|---|---|
| **Tauri** | `src-tauri/src/` (Rust) | `src/components/` (TS/Vue) | `tests/` |
| **Next.js** | `src/app/api/` (API routes) | `src/components/` (React) | `__tests__/` |
| **Django + React** | `backend/` (Python) | `frontend/src/` (React) | `tests/` |
| **Go + HTMX** | `internal/` (Go handlers) | `templates/` (HTMX) | `*_test.go` |
| **Monorepo** | `packages/api/` | `packages/web/` | `packages/shared/` |

The boundary contract changes with the architecture — IPC for Tauri, REST/GraphQL for web apps, shared types for monorepos — but the pattern is the same: define the contract first, agents develop against it, merge foundation-first.
