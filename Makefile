.PHONY: test lint format

test:
	@nvim --headless -u tests/minimal_init.lua -c "luafile tests/uv_spec.lua"

lint:
	@stylua --check lua/ tests/

format:
	@stylua lua/ tests/
