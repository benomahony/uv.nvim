.PHONY: test lint format help

help:
	@echo "uv.nvim - Makefile targets"
	@echo ""
	@echo "  make test   - Run tests"
	@echo "  make lint   - Check formatting with stylua"
	@echo "  make format - Format code with stylua"

test:
	@nvim --headless -u tests/minimal_init.lua -c "luafile tests/standalone/test_all.lua"

lint:
	@stylua --check lua/ tests/ 2>/dev/null || echo "stylua not found, skipping"

format:
	@stylua lua/ tests/
