---
description: Bumping project version and updating changelog atomically. Use when releasing a new version — patch, minor, or major.
disable-model-invocation: true
---
# /bump — Version Bump Workflow

Bump the project version and update the changelog in one atomic operation.

## Invocation

```
/bump patch    # 0.7.1 → 0.7.2 (bug fixes, minor changes)
/bump minor    # 0.7.1 → 0.8.0 (new features, backwards compatible)
/bump major    # 0.7.1 → 1.0.0 (breaking changes)
/bump          # Interactive - asks which type
```

## Version File Detection

Auto-detect the primary version source (first match wins):

| File | Field |
|------|-------|
| `VERSION` | Entire file content |
| `package.json` | `"version"` |
| `pyproject.toml` | `[project] version` |
| `Cargo.toml` | `[package] version` |
| `.claude-plugin/plugin.json` | `"version"` |

**Additional version files:** After bumping the primary, scan for co-located version fields and update them too (e.g., `plugin.json`, `marketplace.json`). Keep all versions in sync.

**Changelog:** `CHANGELOG.md` in repo root.

## Workflow

1. **Detect version file** using the priority table above
2. **Read current version** from the detected file
3. **Determine new version** based on bump type
4. **Update primary version file**
5. **Update co-located version files** (if any)
6. **Update CHANGELOG.md** with new section:
   - Add `## [X.Y.Z] - YYYY-MM-DDTHH:MM:SS±HH:MM` header (use current local time)
   - Summarize changes since last version
   - Use `### Added`, `### Changed`, `### Fixed`, `### Removed` subsections
7. **Commit** with message: `chore: bump version to X.Y.Z`

## Changelog Format

```markdown
## [0.7.2] - 2026-02-04T14:32:07-05:00

### Fixed
- Description of bug fix

### Added
- Description of new feature

### Changed
- Description of change to existing functionality

### Removed
- Description of removed feature
```

## Rules

1. **Semver** - Follow semantic versioning strictly
   - MAJOR: Breaking changes
   - MINOR: New features (backwards compatible)
   - PATCH: Bug fixes (backwards compatible)

2. **Changelog entries** should:
   - Start with a verb (Add, Fix, Change, Remove)
   - Be user-facing (what changed for them, not internal details)
   - Link to issues/PRs when relevant

3. **Full ISO 8601 timestamps** - Use `YYYY-MM-DDTHH:MM:SS±HH:MM` format (not just the date).
   Get the current time via `date +%Y-%m-%dT%H:%M:%S%z` (inserting a colon in the offset, e.g., `-05:00` not `-0500`).

4. **One commit** - Version bump and changelog go in the same commit

## Example

```
User: /bump patch

Claude:
- Detects VERSION file as primary version source
- Reads VERSION: 0.7.1
- Calculates new version: 0.7.2
- Updates VERSION to 0.7.2
- Scans for co-located version files (e.g., plugin.json) — updates if found
- Adds ## [0.7.2] - 2026-02-04T14:32:07-05:00 section to CHANGELOG.md
- Commits: "chore: bump version to 0.7.2"
```
