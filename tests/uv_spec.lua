local uv = require("uv")

local original_path = vim.env.PATH
local original_venv = vim.env.VIRTUAL_ENV
local original_cwd = vim.fn.getcwd()

local function reset_env()
	vim.env.PATH = original_path
	vim.env.VIRTUAL_ENV = original_venv
	vim.cmd("cd " .. vim.fn.fnameescape(original_cwd))
end

local function fresh_uv()
	package.loaded["uv"] = nil
	return require("uv")
end

describe("uv.nvim", function()
	after_each(function()
		reset_env()
	end)

	describe("configuration", function()
		it("has correct defaults", function()
			local m = fresh_uv()
			assert.is_true(m.config.auto_activate_venv)
			assert.are.equal("<leader>x", m.config.keymaps.prefix)
			assert.are.equal("uv run python", m.config.execution.run_command)
			assert.are.equal("split", m.config.execution.terminal)
		end)

		it("merges custom config", function()
			local m = fresh_uv()
			m.setup({ auto_activate_venv = false, auto_commands = false, keymaps = false, picker_integration = false })
			assert.is_false(m.config.auto_activate_venv)
			assert.is_true(m.config.notify_activate_venv)
		end)

		it("accepts custom execution config", function()
			local m = fresh_uv()
			m.setup({
				execution = { run_command = "python3", terminal = "vsplit" },
				auto_commands = false,
				keymaps = false,
				picker_integration = false,
			})
			assert.are.equal("python3", m.config.execution.run_command)
			assert.are.equal("vsplit", m.config.execution.terminal)
		end)
	end)

	describe("commands", function()
		it("registers user commands", function()
			local m = fresh_uv()
			m.setup({ auto_commands = false, keymaps = false, picker_integration = false })
			local cmds = vim.api.nvim_get_commands({})
			assert.is_not_nil(cmds.UVInit)
			assert.is_not_nil(cmds.UVRunFile)
			assert.is_not_nil(cmds.UVRunSelection)
			assert.is_not_nil(cmds.UVRunFunction)
		end)
	end)

	describe("activate_venv", function()
		it("sets VIRTUAL_ENV", function()
			local m = fresh_uv()
			m.config.notify_activate_venv = false
			local test_path = vim.fn.tempname()
			vim.fn.mkdir(test_path .. "/bin", "p")

			m.activate_venv(test_path)
			assert.are.equal(test_path, vim.env.VIRTUAL_ENV)

			vim.fn.delete(test_path, "rf")
		end)

		it("prepends to PATH", function()
			local m = fresh_uv()
			m.config.notify_activate_venv = false
			local test_path = vim.fn.tempname()
			vim.fn.mkdir(test_path .. "/bin", "p")

			m.activate_venv(test_path)
			assert.are.equal(1, vim.env.PATH:find(test_path .. "/bin", 1, true))

			vim.fn.delete(test_path, "rf")
		end)
	end)

	describe("auto_activate_venv", function()
		it("returns false when no .venv exists", function()
			local m = fresh_uv()
			m.config.notify_activate_venv = false
			local temp_dir = vim.fn.tempname()
			vim.fn.mkdir(temp_dir, "p")
			vim.cmd("cd " .. vim.fn.fnameescape(temp_dir))

			assert.is_false(m.auto_activate_venv())

			vim.fn.delete(temp_dir, "rf")
		end)

		it("returns true when .venv exists", function()
			local m = fresh_uv()
			m.config.notify_activate_venv = false
			local temp_dir = vim.fn.tempname()
			vim.fn.mkdir(temp_dir .. "/.venv/bin", "p")
			vim.cmd("cd " .. vim.fn.fnameescape(temp_dir))

			assert.is_true(m.auto_activate_venv())

			vim.fn.delete(temp_dir, "rf")
		end)
	end)

	describe("setup", function()
		it("exposes run_command globally", function()
			local m = fresh_uv()
			_G.run_command = nil
			m.setup({ auto_commands = false, keymaps = false, picker_integration = false })
			assert.are.equal("function", type(_G.run_command))
		end)
	end)

	describe("snacks picker preview", function()
		local pattern = "^(uv %a+)"

		it("extracts uv commands for help preview", function()
			assert.are.equal("uv add", ("uv add [package]"):match(pattern))
			assert.are.equal("uv sync", ("uv sync --all-extras"):match(pattern))
			assert.are.equal("uv init", ("uv init"):match(pattern))
		end)

		it("returns nil for non-uv items", function()
			assert.is_nil(("Run current file"):match(pattern))
			assert.is_nil(("Run selection"):match(pattern))
		end)
	end)
end)
