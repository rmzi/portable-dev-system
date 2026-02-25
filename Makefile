.PHONY: install test

# Link current checkout as the PDS plugin (dev mode)
# Symlinks this directory to ~/.claude/plugins/pds/
install:
	@bash install.sh --plugin-dir .

# Run install smoke tests (offline, temp dirs)
test:
	@bash install.sh --test
