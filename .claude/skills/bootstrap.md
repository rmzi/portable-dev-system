---
description: Initialize new project structure with consistent conventions
---
# /bootstrap — New Project Setup

Consistent project initialization across codebases.

## Invocation

```
/bootstrap [type]    # Initialize project structure
```

Types: `node`, `python`, `go`, `rust`, `generic`

## Universal Project Structure

Every project should have:

```
project/
├── README.md           # What, why, how to run
├── .gitignore          # Language-appropriate ignores
├── .editorconfig       # Consistent formatting
├── Makefile            # Standard task runner (or Justfile)
└── docs/
    └── adr/            # Architecture decisions
```

## Standard Makefile Targets

```makefile
.PHONY: help setup test lint build run clean

help:           ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

setup:          ## Install dependencies
	# Language-specific setup

test:           ## Run tests
	# Language-specific test command

lint:           ## Run linters
	# Language-specific lint command

build:          ## Build the project
	# Language-specific build

run:            ## Run the project
	# Language-specific run

clean:          ## Clean build artifacts
	# Language-specific clean
```

## README Template

```markdown
# Project Name

One-line description.

## Quick Start

\`\`\`bash
make setup
make run
\`\`\`

## Development

\`\`\`bash
make test    # Run tests
make lint    # Run linters
\`\`\`

## Architecture

Brief description of how the code is organized.
Link to docs/adr/ for decisions.
```

## .editorconfig

```ini
root = true

[*]
indent_style = space
indent_size = 2
end_of_line = lf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true

[*.{py,go,rs}]
indent_size = 4

[Makefile]
indent_style = tab
```

## Git Setup

```bash
# Initial commit structure
git init
git add .
git commit -m "chore: initial project setup"

# Create develop branch if using git-flow
git checkout -b develop

# Set up worktree-friendly structure
# Keep main clean, work in feature branches
```

## Environment Management

```bash
# Create .env.example (committed)
# Document all required env vars

# Create .env (gitignored)
# Actual values for local development

# .gitignore entry:
# .env
# .env.local
# !.env.example
```

## First Commit Checklist

- [ ] README with setup instructions
- [ ] .gitignore appropriate for language
- [ ] .editorconfig for consistent formatting
- [ ] Makefile or equivalent task runner
- [ ] Test infrastructure (even if empty)
- [ ] Lint configuration
- [ ] CI configuration (GitHub Actions, etc.)
