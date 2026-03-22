.PHONY: install test eval

# Link current checkout as the PDS plugin (dev mode)
# Symlinks this directory to ~/.claude/plugins/pds/
install:
	@bash install.sh --plugin-dir .

# Run install smoke tests (offline, temp dirs)
test:
	@bash install.sh --test

# Run skill evals (statistical, requires claude CLI)
# Usage: make eval SKILL=grill [RUNS=5] [MODEL=haiku]
eval:
	@bash scripts/run-eval.sh $(SKILL) --runs $(or $(RUNS),5) --model $(or $(MODEL),haiku)
