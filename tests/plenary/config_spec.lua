-- Tests for uv.nvim configuration and setup
local uv = require("uv")

describe("uv.nvim configuration", function()
	-- Store original config to restore after tests
	local original_config

	before_each(function()
		-- Save original config
		original_config = vim.deepcopy(uv.config)
	end)

	after_each(function()
		-- Restore original config
		uv.config = original_config
	end)

	describe("default configuration", function()
		it("has auto_activate_venv enabled by default", function()
			assert.is_true(uv.config.auto_activate_venv)
		end)

		it("has notify_activate_venv enabled by default", function()
			assert.is_true(uv.config.notify_activate_venv)
		end)

		it("has auto_commands enabled by default", function()
			assert.is_true(uv.config.auto_commands)
		end)

		it("has picker_integration enabled by default", function()
			assert.is_true(uv.config.picker_integration)
		end)

		it("has keymaps configured by default", function()
			assert.is_table(uv.config.keymaps)
		end)

		it("has correct default keymap prefix", function()
			assert.equals("<leader>x", uv.config.keymaps.prefix)
		end)

		it("has all keymaps enabled by default", function()
			local keymaps = uv.config.keymaps
			assert.is_true(keymaps.commands)
			assert.is_true(keymaps.run_file)
			assert.is_true(keymaps.run_selection)
			assert.is_true(keymaps.run_function)
			assert.is_true(keymaps.venv)
			assert.is_true(keymaps.init)
			assert.is_true(keymaps.add)
			assert.is_true(keymaps.remove)
			assert.is_true(keymaps.sync)
			assert.is_true(keymaps.sync_all)
		end)

		it("has execution config by default", function()
			assert.is_table(uv.config.execution)
		end)

		it("has correct default run_command", function()
			assert.equals("uv run python", uv.config.execution.run_command)
		end)

		it("has correct default terminal option", function()
			assert.equals("split", uv.config.execution.terminal)
		end)

		it("has notify_output enabled by default", function()
			assert.is_true(uv.config.execution.notify_output)
		end)

		it("has correct default notification_timeout", function()
			assert.equals(10000, uv.config.execution.notification_timeout)
		end)
	end)

	describe("setup with custom config", function()
		it("merges user config with defaults", function()
			-- Create a fresh module instance for this test
			package.loaded["uv"] = nil
			local fresh_uv = require("uv")

			fresh_uv.setup({
				auto_activate_venv = false,
			})

			assert.is_false(fresh_uv.config.auto_activate_venv)
			-- Other defaults should remain
			assert.is_true(fresh_uv.config.notify_activate_venv)
		end)

		it("allows disabling keymaps entirely", function()
			package.loaded["uv"] = nil
			local fresh_uv = require("uv")

			fresh_uv.setup({
				keymaps = false,
			})

			assert.is_false(fresh_uv.config.keymaps)
		end)

		it("allows partial keymap override", function()
			package.loaded["uv"] = nil
			local fresh_uv = require("uv")

			fresh_uv.setup({
				keymaps = {
					prefix = "<leader>u",
					run_file = false,
				},
			})

			assert.equals("<leader>u", fresh_uv.config.keymaps.prefix)
			assert.is_false(fresh_uv.config.keymaps.run_file)
			-- Others should remain true
			assert.is_true(fresh_uv.config.keymaps.run_selection)
		end)

		it("allows custom execution config", function()
			package.loaded["uv"] = nil
			local fresh_uv = require("uv")

			fresh_uv.setup({
				execution = {
					run_command = "python3",
					terminal = "vsplit",
					notify_output = false,
				},
			})

			assert.equals("python3", fresh_uv.config.execution.run_command)
			assert.equals("vsplit", fresh_uv.config.execution.terminal)
			assert.is_false(fresh_uv.config.execution.notify_output)
		end)

		it("handles empty config gracefully", function()
			package.loaded["uv"] = nil
			local fresh_uv = require("uv")

			-- Should not error
			fresh_uv.setup({})

			-- Defaults should remain
			assert.is_true(fresh_uv.config.auto_activate_venv)
		end)

		it("handles nil config gracefully", function()
			package.loaded["uv"] = nil
			local fresh_uv = require("uv")

			-- Should not error
			fresh_uv.setup(nil)

			-- Defaults should remain
			assert.is_true(fresh_uv.config.auto_activate_venv)
		end)
	end)

	describe("terminal configuration", function()
		it("accepts split terminal option", function()
			package.loaded["uv"] = nil
			local fresh_uv = require("uv")

			fresh_uv.setup({
				execution = {
					terminal = "split",
				},
			})

			assert.equals("split", fresh_uv.config.execution.terminal)
		end)

		it("accepts vsplit terminal option", function()
			package.loaded["uv"] = nil
			local fresh_uv = require("uv")

			fresh_uv.setup({
				execution = {
					terminal = "vsplit",
				},
			})

			assert.equals("vsplit", fresh_uv.config.execution.terminal)
		end)

		it("accepts tab terminal option", function()
			package.loaded["uv"] = nil
			local fresh_uv = require("uv")

			fresh_uv.setup({
				execution = {
					terminal = "tab",
				},
			})

			assert.equals("tab", fresh_uv.config.execution.terminal)
		end)
	end)
end)

describe("uv.nvim user commands", function()
	before_each(function()
		-- Ensure clean state
		package.loaded["uv"] = nil
	end)

	it("registers UVInit command", function()
		local fresh_uv = require("uv")
		fresh_uv.setup({
			auto_commands = false,
			keymaps = false,
			picker_integration = false,
		})

		local commands = vim.api.nvim_get_commands({})
		assert.is_not_nil(commands.UVInit)
	end)

	it("registers UVRunFile command", function()
		local fresh_uv = require("uv")
		fresh_uv.setup({
			auto_commands = false,
			keymaps = false,
			picker_integration = false,
		})

		local commands = vim.api.nvim_get_commands({})
		assert.is_not_nil(commands.UVRunFile)
	end)

	it("registers UVRunSelection command", function()
		local fresh_uv = require("uv")
		fresh_uv.setup({
			auto_commands = false,
			keymaps = false,
			picker_integration = false,
		})

		local commands = vim.api.nvim_get_commands({})
		assert.is_not_nil(commands.UVRunSelection)
	end)

	it("registers UVRunFunction command", function()
		local fresh_uv = require("uv")
		fresh_uv.setup({
			auto_commands = false,
			keymaps = false,
			picker_integration = false,
		})

		local commands = vim.api.nvim_get_commands({})
		assert.is_not_nil(commands.UVRunFunction)
	end)

	it("registers UVAddPackage command", function()
		local fresh_uv = require("uv")
		fresh_uv.setup({
			auto_commands = false,
			keymaps = false,
			picker_integration = false,
		})

		local commands = vim.api.nvim_get_commands({})
		assert.is_not_nil(commands.UVAddPackage)
	end)

	it("registers UVRemovePackage command", function()
		local fresh_uv = require("uv")
		fresh_uv.setup({
			auto_commands = false,
			keymaps = false,
			picker_integration = false,
		})

		local commands = vim.api.nvim_get_commands({})
		assert.is_not_nil(commands.UVRemovePackage)
	end)
end)

describe("uv.nvim global exposure", function()
	it("exposes run_command globally after setup", function()
		package.loaded["uv"] = nil
		local fresh_uv = require("uv")

		-- Clear any existing global
		_G.run_command = nil

		fresh_uv.setup({
			auto_commands = false,
			keymaps = false,
			picker_integration = false,
		})

		assert.is_function(_G.run_command)
	end)
end)
