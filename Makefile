.PHONY: test test-standalone test-plenary test-file lint format help

# Default target
help:
	@echo "uv.nvim - Makefile targets"
	@echo ""
	@echo "  make test            - Run standalone tests (no dependencies)"
	@echo "  make test-standalone - Run standalone tests (no dependencies)"
	@echo "  make test-plenary    - Run tests using plenary.nvim (requires plenary)"
	@echo "  make test-file F=    - Run a specific test file"
	@echo "  make lint            - Run lua linter (if available)"
	@echo "  make format          - Format code with stylua"
	@echo ""

# Run standalone tests (no external dependencies - recommended)
test: test-standalone

test-standalone:
	@echo "Running standalone tests..."
	@nvim --headless -u tests/minimal_init.lua \
		-c "luafile tests/standalone/test_all.lua"

# Run tests using plenary.nvim (requires plenary.nvim to be installed)
test-plenary:
	@echo "Running plenary tests..."
	@nvim --headless -u tests/minimal_init.lua \
		-c "lua require('plenary.test_harness').test_directory('tests/plenary/', {minimal_init = 'tests/minimal_init.lua', sequential = true})"

# Run a specific test file
test-file:
	@if [ -z "$(F)" ]; then \
		echo "Usage: make test-file F=tests/standalone/test_utils.lua"; \
		exit 1; \
	fi
	@echo "Running test file: $(F)"
	@nvim --headless -u tests/minimal_init.lua \
		-c "luafile $(F)"

# Run lua linter if stylua is available
lint:
	@if command -v stylua > /dev/null 2>&1; then \
		echo "Running stylua check..."; \
		stylua --check lua/ tests/; \
	else \
		echo "stylua not found, skipping lint"; \
	fi

# Format code with stylua
format:
	@if command -v stylua > /dev/null 2>&1; then \
		echo "Formatting with stylua..."; \
		stylua lua/ tests/; \
	else \
		echo "stylua not found"; \
		exit 1; \
	fi
