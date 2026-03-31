# Claude Code Extension Catalog

Reference for Claude Code's hook lifecycle events, settings hierarchy, and plugin capabilities. Cross-references docs/claude-code-source-analysis.md for deeper context.

## Hook Events (28)

| Event | Category | When It Fires | Input Fields | PDS Status |
|-------|----------|--------------|-------------|------------|
| SessionStart | Session | Session begins | session_id, cwd | Active — injects PDS context |
| SessionEnd | Session | Session ends | session_id, duration | Not used |
| Setup | Session | First-time setup | — | Not used |
| PreToolUse | Tool | Before tool executes | tool_name, tool_input | Active — orchestrator phase gates |
| PostToolUse | Tool | After tool succeeds | tool_name, tool_input, tool_output | Active — telemetry logger (Skill|Agent), file telemetry (Write|Edit) |
| PostToolUseFailure | Tool | After tool fails | tool_name, tool_input, error | Not used |
| SubagentStart | Agent | Agent/subagent spawned | agent_type, agent_id, parent_id | Active — roster check |
| SubagentStop | Agent | Agent/subagent exits | agent_type, agent_id, exit_reason | Not used |
| TeammateIdle | Agent | Teammate has no work | agent_id, agent_type | Active — uncommitted changes check |
| TaskCreated | Task | Task created | task_id, task_subject | Not used |
| TaskCompleted | Task | Task marked complete | task_id, task_subject, cwd | Active — test runner gate |
| PreCompact | Context | Before context compaction | — | Active — swarm state snapshot |
| PostCompact | Context | After context compaction | — | Active — state re-injection |
| InstructionsLoaded | Context | CLAUDE.md/rules files loaded | file_paths | Active — telemetry (JSONL) |
| PermissionRequest | Permission | Tool needs permission | tool_name, arguments | Active — LLM-based allow/deny |
| PermissionDenied | Permission | Permission was denied | tool_name, reason | Not used |
| FileChanged | File | Watched file modified | file_path | Not used |
| CwdChanged | File | Working directory changed | old_cwd, new_cwd | Not used |
| WorktreeCreate | File | Git worktree created | name, path | Active — telemetry (JSONL) |
| WorktreeRemove | File | Git worktree removed | name, path | Not used |
| Stop | Lifecycle | Model wants to stop | arguments | Active — completion verifier |
| StopFailure | Lifecycle | Stop hook rejected | reason | Not used |
| Notification | Lifecycle | System notification | message | Not used |
| ConfigChange | Lifecycle | Settings changed | changed_keys | Not used |
| UserPromptSubmit | Interaction | User sends a message | prompt | Active — skill hints |
| Elicitation | Interaction | Model asks user question | question | Not used |
| ElicitationResult | Interaction | User answers elicitation | answer | Not used |
| Custom | Internal | Internal callbacks | varies | Not used |

Note: 'Input Fields' are approximations based on source analysis. Exact schemas may vary.

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
| Skills | skills/ directory with SKILL.md files | Yes — 20 skills |
| Agents | agents/ directory with .md files | Yes — 8 agents |
| Hooks | hooks.json in plugin root | Yes — 12+ hook entries |
| MCP servers | MCP config in plugin manifest | No |
| Settings overlay | Plugin-scoped settings | Partially — env vars |

### Plugin Loading Order
1. Plugins discovered from ~/.claude/plugins/ and marketplace
2. Skill frontmatter parsed (name, description, whenToUse)
3. Agent definitions loaded
4. hooks.json merged into global hook registry
5. Plugin settings merged (env vars)

See docs/claude-code-source-analysis.md for implementation details.
