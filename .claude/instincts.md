# Instincts

Persistent engineering patterns observed during work. Lighter than skills — observations with context that accumulate confidence through validation.

## Format

```markdown
### [title]
- **Observed**: [YYYY-MM-DD]
- **Times seen**: [N]
- **Confidence**: low | medium | high
- **Context**: [where/when this was observed]
- **Pattern**: [what happens]
- **Action**: [what to do about it]
- **Status**: active | promoted | retired
```

## Lifecycle

1. **Capture**: Any agent or human records a pattern here via `/instinct`
2. **Validate**: Scout reviews post-swarm, bumps count, adjusts confidence
3. **Promote**: At `high` confidence (3+ validations), scout proposes a new skill draft. Human approves.
4. **Retire**: If proven wrong or irrelevant, scout marks `retired`

## Instincts

### Context loss on agent spawn is the dominant waste category
- **Observed**: 2026-04-02
- **Times seen**: 1
- **Confidence**: low
- **Context**: Heavy swarm for whitepaper merge — orchestrator spawned workers that re-discovered plan/research/decisions from scratch
- **Pattern**: Workers spend first 2-3 turns reading files and rebuilding context the orchestrator already had. TPS "transport waste" — moving information between agents instead of creating value.
- **Action**: Write `.claude/swarm/context.md` before dispatching workers. Implemented in v4.8.0.
- **Status**: active

### Orchestrator idle time during worker execution is significant
- **Observed**: 2026-04-02
- **Times seen**: 1
- **Confidence**: low
- **Context**: Heavy swarm — orchestrator idle ~15 minutes while workers executed
- **Pattern**: Orchestrator creates plan, dispatches workers, then waits until validation. TPS "waiting waste" — a capable agent (opus) creating no value during the longest phase.
- **Action**: Use idle time for monitoring, pre-writing review criteria, preparing consolidation, or headless background tasks via `/pds:dispatch`.
- **Status**: active

### Squash before push to avoid force-push complications
- **Observed**: 2026-04-02
- **Times seen**: 1
- **Confidence**: low
- **Context**: Two sequential swarm commits on main needed squashing, requiring force-push-with-lease which triggered permission denials
- **Pattern**: Multiple swarm runs create sequential commits. Squashing after push requires force-push (risky). Squashing before push is clean.
- **Action**: When running multiple swarms targeting main, accumulate changes and commit once at the end.
- **Status**: active

### Source analysis of the host platform pays compound returns
- **Observed**: 2026-04-02
- **Times seen**: 1
- **Confidence**: low
- **Context**: Claude Code source analysis (692 lines) informed whitepaper v3.0, identified three-system disconnect, revealed 5 compaction modes, grounded efficiency measurement
- **Pattern**: Deep platform understanding enables architecture decisions based on actual behavior, not documented API surface. Findings compound — fork-subagent analysis → dual-dispatch → context protocol → efficiency framework.
- **Action**: Maintain `docs/claude-code-source-analysis.md` as a strategic asset. Update as Claude Code evolves.
- **Status**: active

### User-level telemetry is essential for methodology improvement
- **Observed**: 2026-04-02
- **Times seen**: 1
- **Confidence**: low
- **Context**: Project-level telemetry destroyed when worktrees cleaned up, losing worker agent measurement data
- **Pattern**: Without persistent telemetry, PDS cannot measure efficiency across sessions. Instinct system, scout reports, and efficiency charts depend on data that may not survive the session.
- **Action**: Dual-write to project-level AND `~/.claude/telemetry/sessions.jsonl`. Implemented in v4.8.0.
- **Status**: active

### plugin.json version must stay in sync with VERSION
- **Observed**: 2026-04-02
- **Times seen**: 1
- **Confidence**: low
- **Context**: After bumping VERSION to 4.8.0, marketplace still showed 4.6.2 because plugin.json was stale
- **Pattern**: The marketplace reads version from `.claude-plugin/plugin.json`, not from `VERSION`. Both files must be updated atomically during version bumps. `/pds:bump` and `/pds:bcp` update VERSION but not plugin.json.
- **Action**: Fix `/pds:bump` skill to update both `VERSION` and `.claude-plugin/plugin.json` in the same step.
- **Status**: active

### Stale plugin caches and broken symlinks accumulate silently
- **Observed**: 2026-04-02
- **Times seen**: 1
- **Confidence**: low
- **Context**: Found old marketplace cache versions (4.5.0, 4.6.1), a stale temp git clone, and a broken branch-tone symlink in ~/.claude/plugins/
- **Pattern**: Plugin installs, marketplace updates, and dev symlinks leave artifacts behind. No cleanup runs automatically. Over time, the plugin directory accumulates stale versions, temp clones, and broken symlinks.
- **Action**: Add cleanup to `/pds:dispatch` headless use cases — periodic plugin cache pruning. Or add to preflight validation.
- **Status**: active
