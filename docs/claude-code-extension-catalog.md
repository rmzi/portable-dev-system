# Claude Code Extension Catalog

Reference for Claude Code's hook lifecycle events, settings hierarchy, and plugin capabilities. Cross-references docs/claude-code-source-analysis.md for deeper context.

## Hook Events

Claude Code provides **28 hook events**. PDS uses **12** of them. The table below shows all events — active PDS hooks are marked with their purpose.

### Active in PDS (12)

| Event | Category | When It Fires | PDS Hook |
|-------|----------|--------------|----------|
| SessionStart | Session | Session begins | Context injection (`session-start.sh`) |
| PreToolUse | Tool | Before tool executes | Orchestrator phase gates |
| PostToolUse | Tool | After tool succeeds | Telemetry logger (Skill\|Agent), file telemetry (Write\|Edit) |
| SubagentStart | Agent | Agent/subagent spawned | Roster check (`roster-check.sh`) |
| TeammateIdle | Agent | Teammate has no work | Uncommitted changes check (`teammate-idle-gate.sh`) |
| TaskCompleted | Task | Task marked complete | Test runner gate (`task-completed-gate.sh`) |
| PreCompact | Context | Before context compaction | Swarm state snapshot (`pre-compact-snapshot.sh`) |
| PostCompact | Context | After context compaction | State re-injection (`post-compact-inject.sh`) |
| InstructionsLoaded | Context | CLAUDE.md/rules files loaded | Telemetry (`instructions-telemetry.sh`) |
| WorktreeCreate | File | Git worktree created | Telemetry (`worktree-telemetry.sh`) |
| Stop | Lifecycle | Model wants to stop | Completion verifier (prompt hook) |
| UserPromptSubmit | Interaction | User sends a message | Skill hints (`skill-hint.sh`) |

### Unused (16)

| Event | Category | When It Fires |
|-------|----------|--------------|
| SessionEnd | Session | Session ends |
| Setup | Session | First-time setup |
| PostToolUseFailure | Tool | After tool fails |
| SubagentStop | Agent | Agent/subagent exits |
| TaskCreated | Task | Task created |
| PermissionRequest | Permission | Tool needs permission |
| PermissionDenied | Permission | Permission was denied |
| FileChanged | File | Watched file modified |
| CwdChanged | File | Working directory changed |
| WorktreeRemove | File | Git worktree removed |
| StopFailure | Lifecycle | Stop hook rejected |
| Notification | Lifecycle | System notification |
| ConfigChange | Lifecycle | Settings changed |
| Elicitation | Interaction | Model asks user question |
| ElicitationResult | Interaction | User answers elicitation |
| Custom | Internal | Internal callbacks |

Note: Input field schemas are approximations based on source analysis. Exact schemas may vary.

### Hook Types
| Type | Mechanism | Example |
|------|-----------|---------|
| command | Shell script, JSON stdout | session-start.sh, telemetry-log.sh |
| prompt | LLM evaluation, JSON response | Stop hook, PermissionRequest hook |
| http | HTTP POST, JSON response | External policy servers |
| agent | Spawns evaluator agent | Complex multi-step evaluation |

### Hook Response Schema
| Field | Type | Effect |
|-------|------|--------|
| continue | boolean | false blocks the action |
| decision | string | 'approve' or 'block' for permissions |
| additionalContext | string | Injected as system reminder |
| updatedInput | object | Modifies tool parameters |
| hookSpecificOutput | object | Event-specific structured output |
| stopReason | string | Message shown when blocking |

## Settings Hierarchy

Claude Code uses a 4-layer settings system:

| Layer | Path | Priority | Purpose |
|-------|------|----------|---------|
| 1. Policy (managed) | /Library/Application Support/ClaudeCode/managed-settings.json | Highest (deny) | Enterprise admin |
| 2. User | ~/.claude/settings.json | High | User preferences, PDS security |
| 3. Project | .claude/settings.json | Medium | Repo-level, git-tracked |
| 4. Local | .claude/settings.local.json | Lowest | Per-machine overrides, gitignored |

### Merge Rules
- **Deny rules**: Additive across all layers (union)
- **Allow rules**: Intersective (tightest wins)
- **Scalar values**: Higher-priority layer overrides lower
- **Arrays**: Varies by field (some merge, some override)
- **env vars**: PDS defaults first, user overrides on top

## Plugin Capabilities

| Component | Mechanism | PDS Uses? |
|-----------|-----------|-----------|
| Skills | skills/ directory with SKILL.md files | Yes — 23 skills |
| Agents | agents/ directory with .md files | Yes — 9 agents |
| Hooks | hooks.json in plugin root | Yes — 11 events in hooks.json (+1 PreToolUse in orchestrator agent) |
| MCP servers | MCP config in plugin manifest | No |
| Settings overlay | Plugin-scoped settings | Partially — env vars |

### Plugin Loading Order
1. Plugins discovered from ~/.claude/plugins/ and marketplace
2. Skill frontmatter parsed (name, description, whenToUse)
3. Agent definitions loaded
4. hooks.json merged into global hook registry
5. Plugin settings merged (env vars)

See docs/claude-code-source-analysis.md for implementation details.
