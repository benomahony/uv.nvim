local uv = require("uv")

local function reset_state()
	vim.g.uv_auto_activate_venv = nil
	vim.b.uv_auto_activate_venv = nil
	uv.config.auto_activate_venv = true
end

describe("auto_activate_venv setting", function()
	after_each(function()
		reset_state()
	end)

	it("respects global vim variable", function()
		reset_state()
		uv.setup({ auto_activate_venv = true })
		assert.is_true(uv.is_auto_activate_enabled())

		vim.g.uv_auto_activate_venv = false
		assert.is_false(uv.is_auto_activate_enabled())
	end)

	it("buffer-local takes precedence over global", function()
		reset_state()
		vim.g.uv_auto_activate_venv = true
		vim.b.uv_auto_activate_venv = false
		assert.is_false(uv.is_auto_activate_enabled())
	end)

	it("toggle_auto_activate_venv works", function()
		reset_state()
		uv.setup({ auto_activate_venv = true })
		assert.is_true(uv.is_auto_activate_enabled())

		uv.toggle_auto_activate_venv()
		assert.is_false(uv.is_auto_activate_enabled())

		uv.toggle_auto_activate_venv()
		assert.is_true(uv.is_auto_activate_enabled())
	end)

	it("buffer-local toggle works", function()
		reset_state()
		vim.g.uv_auto_activate_venv = true

		uv.toggle_auto_activate_venv(true)
		assert.is_false(uv.is_auto_activate_enabled())
		assert.is_false(vim.b.uv_auto_activate_venv)
		assert.is_true(vim.g.uv_auto_activate_venv)
	end)
end)
