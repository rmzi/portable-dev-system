.PHONY: install test

# Install current branch's PDS to ~/.claude/ (user-level, all projects)
# Skips network download — uses local files directly
install:
	@mkdir -p ~/.claude/skills
	@cp .claude/skills/*.md ~/.claude/skills/
	@cp .claude/settings.json ~/.claude/settings.json
	@[ -f .claude/instincts.md ] && cp .claude/instincts.md ~/.claude/instincts.md || true
	@cp VERSION ~/.claude/.pds-version
	@echo "✓ Installed PDS $$(cat VERSION) from $$(git branch --show-current) → ~/.claude/"
	@echo "  Skills and settings are live for all projects."
	@echo "  Agents are project-only — not installed at user level."

# Run install smoke tests (offline, temp dirs)
test:
	@bash install.sh --test
