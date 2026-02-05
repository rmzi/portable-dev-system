---
description: Bump version and update changelog
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

## Workflow

1. **Read current version** from `VERSION` file
2. **Determine new version** based on bump type
3. **Update VERSION** file
4. **Update CHANGELOG.md** with new section:
   - Add `## [X.Y.Z] - YYYY-MM-DD` header
   - Summarize changes since last version
   - Use `### Added`, `### Changed`, `### Fixed`, `### Removed` subsections
5. **Commit** with message: `chore: bump version to X.Y.Z`

## Changelog Format

```markdown
## [0.7.2] - 2026-02-04

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

3. **One commit** - Version bump and changelog go in the same commit

## Example

```
User: /bump patch

Claude:
- Reads VERSION: 0.7.1
- Calculates new version: 0.7.2
- Updates VERSION to 0.7.2
- Adds ## [0.7.2] section to CHANGELOG.md
- Commits: "chore: bump version to 0.7.2"
```
