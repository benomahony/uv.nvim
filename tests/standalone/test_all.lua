-- Standalone tests for uv.nvim
-- Run with: nvim --headless -u tests/minimal_init.lua -c "luafile tests/standalone/test_all.lua"
-- No external dependencies required

local t = require("tests.standalone.runner")

print("=" .. string.rep("=", 60))
print("uv.nvim Test Suite")
print("=" .. string.rep("=", 60))
print("")

-- ============================================================================
-- CONFIGURATION TESTS
-- ============================================================================

t.describe("uv.nvim configuration", function()
	t.describe("default configuration", function()
		t.it("has auto_activate_venv enabled by default", function()
			package.loaded["uv"] = nil
			local uv = require("uv")
			t.assert_true(uv.config.auto_activate_venv)
		end)

		t.it("has correct default keymap prefix", function()
			package.loaded["uv"] = nil
			local uv = require("uv")
			t.assert_equals("<leader>x", uv.config.keymaps.prefix)
		end)

		t.it("has correct default run_command", function()
			package.loaded["uv"] = nil
			local uv = require("uv")
			t.assert_equals("uv run python", uv.config.execution.run_command)
		end)

		t.it("has correct default terminal option", function()
			package.loaded["uv"] = nil
			local uv = require("uv")
			t.assert_equals("split", uv.config.execution.terminal)
		end)
	end)

	t.describe("setup with custom config", function()
		t.it("merges user config with defaults", function()
			package.loaded["uv"] = nil
			local uv = require("uv")
			uv.setup({
				auto_activate_venv = false,
				auto_commands = false,
				keymaps = false,
				picker_integration = false,
			})
			t.assert_false(uv.config.auto_activate_venv)
			t.assert_true(uv.config.notify_activate_venv) -- Other defaults remain
		end)

		t.it("allows disabling keymaps entirely", function()
			package.loaded["uv"] = nil
			local uv = require("uv")
			uv.setup({
				keymaps = false,
				auto_commands = false,
				picker_integration = false,
			})
			t.assert_false(uv.config.keymaps)
		end)

		t.it("allows custom execution config", function()
			package.loaded["uv"] = nil
			local uv = require("uv")
			uv.setup({
				execution = {
					run_command = "python3",
					terminal = "vsplit",
				},
				auto_commands = false,
				keymaps = false,
				picker_integration = false,
			})
			t.assert_equals("python3", uv.config.execution.run_command)
			t.assert_equals("vsplit", uv.config.execution.terminal)
		end)

		t.it("handles nil config gracefully", function()
			package.loaded["uv"] = nil
			local uv = require("uv")
			t.assert_no_error(function()
				uv.setup(nil)
			end)
		end)
	end)
end)

-- ============================================================================
-- USER COMMANDS TESTS
-- ============================================================================

t.describe("uv.nvim user commands", function()
	t.it("registers UVInit command", function()
		package.loaded["uv"] = nil
		local uv = require("uv")
		uv.setup({ auto_commands = false, keymaps = false, picker_integration = false })
		local commands = vim.api.nvim_get_commands({})
		t.assert_not_nil(commands.UVInit)
	end)

	t.it("registers UVRunFile command", function()
		package.loaded["uv"] = nil
		local uv = require("uv")
		uv.setup({ auto_commands = false, keymaps = false, picker_integration = false })
		local commands = vim.api.nvim_get_commands({})
		t.assert_not_nil(commands.UVRunFile)
	end)

	t.it("registers UVRunSelection command", function()
		package.loaded["uv"] = nil
		local uv = require("uv")
		uv.setup({ auto_commands = false, keymaps = false, picker_integration = false })
		local commands = vim.api.nvim_get_commands({})
		t.assert_not_nil(commands.UVRunSelection)
	end)

	t.it("registers UVRunFunction command", function()
		package.loaded["uv"] = nil
		local uv = require("uv")
		uv.setup({ auto_commands = false, keymaps = false, picker_integration = false })
		local commands = vim.api.nvim_get_commands({})
		t.assert_not_nil(commands.UVRunFunction)
	end)
end)

-- ============================================================================
-- VIRTUAL ENVIRONMENT TESTS
-- ============================================================================

t.describe("uv.nvim virtual environment", function()
	local original_path = vim.env.PATH
	local original_venv = vim.env.VIRTUAL_ENV
	local original_cwd = vim.fn.getcwd()

	t.describe("activate_venv", function()
		t.it("sets VIRTUAL_ENV environment variable", function()
			local test_venv_path = vim.fn.tempname()
			vim.fn.mkdir(test_venv_path .. "/bin", "p")

			package.loaded["uv"] = nil
			local uv = require("uv")
			uv.config.notify_activate_venv = false
			uv.activate_venv(test_venv_path)

			t.assert_equals(test_venv_path, vim.env.VIRTUAL_ENV)

			-- Cleanup
			vim.env.PATH = original_path
			vim.env.VIRTUAL_ENV = original_venv
			vim.fn.delete(test_venv_path, "rf")
		end)

		t.it("prepends venv bin to PATH", function()
			local test_venv_path = vim.fn.tempname()
			vim.fn.mkdir(test_venv_path .. "/bin", "p")

			package.loaded["uv"] = nil
			local uv = require("uv")
			uv.config.notify_activate_venv = false
			uv.activate_venv(test_venv_path)

			local expected_prefix = test_venv_path .. "/bin:"
			t.assert_contains(vim.env.PATH, expected_prefix)

			-- Cleanup
			vim.env.PATH = original_path
			vim.env.VIRTUAL_ENV = original_venv
			vim.fn.delete(test_venv_path, "rf")
		end)
	end)

	t.describe("auto_activate_venv", function()
		t.it("returns false when no .venv exists", function()
			local temp_dir = vim.fn.tempname()
			vim.fn.mkdir(temp_dir, "p")
			vim.cmd("cd " .. vim.fn.fnameescape(temp_dir))

			package.loaded["uv"] = nil
			local uv = require("uv")
			uv.config.notify_activate_venv = false
			local result = uv.auto_activate_venv()

			t.assert_false(result)

			-- Cleanup
			vim.cmd("cd " .. vim.fn.fnameescape(original_cwd))
			vim.fn.delete(temp_dir, "rf")
		end)

		t.it("returns true when .venv exists", function()
			local temp_dir = vim.fn.tempname()
			vim.fn.mkdir(temp_dir .. "/.venv/bin", "p")
			vim.cmd("cd " .. vim.fn.fnameescape(temp_dir))

			package.loaded["uv"] = nil
			local uv = require("uv")
			uv.config.notify_activate_venv = false
			local result = uv.auto_activate_venv()

			t.assert_true(result)

			-- Cleanup
			vim.env.PATH = original_path
			vim.env.VIRTUAL_ENV = original_venv
			vim.cmd("cd " .. vim.fn.fnameescape(original_cwd))
			vim.fn.delete(temp_dir, "rf")
		end)
	end)

	t.describe("is_venv_active", function()
		t.it("returns false when no venv is active", function()
			vim.env.VIRTUAL_ENV = nil
			package.loaded["uv"] = nil
			local uv = require("uv")
			t.assert_false(uv.is_venv_active())
			vim.env.VIRTUAL_ENV = original_venv
		end)

		t.it("returns true when venv is active", function()
			vim.env.VIRTUAL_ENV = "/some/path/.venv"
			package.loaded["uv"] = nil
			local uv = require("uv")
			t.assert_true(uv.is_venv_active())
			vim.env.VIRTUAL_ENV = original_venv
		end)
	end)
end)

-- ============================================================================
-- INTEGRATION TESTS
-- ============================================================================

t.describe("uv.nvim integration", function()
	t.it("setup can be called without errors", function()
		package.loaded["uv"] = nil
		local uv = require("uv")
		t.assert_no_error(function()
			uv.setup({
				auto_commands = false,
				keymaps = false,
				picker_integration = false,
			})
		end)
	end)

	t.it("exposes run_command globally after setup", function()
		package.loaded["uv"] = nil
		local uv = require("uv")
		_G.run_command = nil
		uv.setup({
			auto_commands = false,
			keymaps = false,
			picker_integration = false,
		})
		t.assert_type("function", _G.run_command)
	end)

	t.it("exports expected functions", function()
		package.loaded["uv"] = nil
		local uv = require("uv")
		t.assert_type("function", uv.setup)
		t.assert_type("function", uv.activate_venv)
		t.assert_type("function", uv.auto_activate_venv)
		t.assert_type("function", uv.run_file)
		t.assert_type("function", uv.run_command)
		t.assert_type("function", uv.is_venv_active)
		t.assert_type("function", uv.get_venv)
		t.assert_type("function", uv.get_venv_path)
	end)
end)

-- Print results and exit
local exit_code = t.print_results()
vim.cmd("cq " .. exit_code)
