.DEFAULT_GOAL := help

.PHONY: help install test eval telemetry

help:
	@echo 'Available targets:'
	@echo '  install    Link current checkout as the PDS plugin (dev mode)'
	@echo '  test       Run install smoke tests'
	@echo '  eval       Run skill evals (make eval SKILL=grill [RUNS=5] [MODEL=haiku])'
	@echo '  telemetry  Show PDS usage telemetry report'

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

telemetry:
	@./scripts/telemetry-summary.sh
