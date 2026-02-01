-- Tests for uv.nvim core functionality
-- Run with: nvim --headless -u tests/minimal_init.lua -c "luafile tests/uv_spec.lua"

assert(vim and vim.fn, "This test must be run in Neovim")

local tests_passed = 0
local tests_failed = 0

local function it(name, fn)
	local ok, err = pcall(fn)
	if ok then
		tests_passed = tests_passed + 1
		print("  ✓ " .. name)
	else
		tests_failed = tests_failed + 1
		print("  ✗ " .. name)
		print("    Error: " .. tostring(err))
	end
end

-- Store original state
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

print("\n=== uv.nvim tests ===\n")

print("Configuration:")

it("has correct default config", function()
	local uv = fresh_uv()
	assert(uv.config.auto_activate_venv == true)
	assert(uv.config.keymaps.prefix == "<leader>x")
	assert(uv.config.execution.run_command == "uv run python")
	assert(uv.config.execution.terminal == "split")
end)

it("merges custom config", function()
	local uv = fresh_uv()
	uv.setup({
		auto_activate_venv = false,
		auto_commands = false,
		keymaps = false,
		picker_integration = false,
	})
	assert(uv.config.auto_activate_venv == false)
	assert(uv.config.notify_activate_venv == true) -- default preserved
end)

it("accepts custom execution config", function()
	local uv = fresh_uv()
	uv.setup({
		execution = { run_command = "python3", terminal = "vsplit" },
		auto_commands = false,
		keymaps = false,
		picker_integration = false,
	})
	assert(uv.config.execution.run_command == "python3")
	assert(uv.config.execution.terminal == "vsplit")
end)

print("\nCommands:")

it("registers user commands", function()
	local uv = fresh_uv()
	uv.setup({ auto_commands = false, keymaps = false, picker_integration = false })
	local cmds = vim.api.nvim_get_commands({})
	assert(cmds.UVInit ~= nil, "UVInit should exist")
	assert(cmds.UVRunFile ~= nil, "UVRunFile should exist")
	assert(cmds.UVRunSelection ~= nil, "UVRunSelection should exist")
	assert(cmds.UVRunFunction ~= nil, "UVRunFunction should exist")
end)

print("\nVirtual Environment:")

it("activate_venv sets VIRTUAL_ENV", function()
	local uv = fresh_uv()
	uv.config.notify_activate_venv = false
	local test_path = vim.fn.tempname()
	vim.fn.mkdir(test_path .. "/bin", "p")

	uv.activate_venv(test_path)
	assert(vim.env.VIRTUAL_ENV == test_path)

	reset_env()
	vim.fn.delete(test_path, "rf")
end)

it("activate_venv prepends to PATH", function()
	local uv = fresh_uv()
	uv.config.notify_activate_venv = false
	local test_path = vim.fn.tempname()
	vim.fn.mkdir(test_path .. "/bin", "p")

	uv.activate_venv(test_path)
	assert(vim.env.PATH:find(test_path .. "/bin", 1, true) == 1, "PATH should start with venv bin")

	reset_env()
	vim.fn.delete(test_path, "rf")
end)

it("auto_activate_venv returns false when no .venv", function()
	local uv = fresh_uv()
	uv.config.notify_activate_venv = false
	local temp_dir = vim.fn.tempname()
	vim.fn.mkdir(temp_dir, "p")
	vim.cmd("cd " .. vim.fn.fnameescape(temp_dir))

	assert(uv.auto_activate_venv() == false)

	reset_env()
	vim.fn.delete(temp_dir, "rf")
end)

it("auto_activate_venv returns true when .venv exists", function()
	local uv = fresh_uv()
	uv.config.notify_activate_venv = false
	local temp_dir = vim.fn.tempname()
	vim.fn.mkdir(temp_dir .. "/.venv/bin", "p")
	vim.cmd("cd " .. vim.fn.fnameescape(temp_dir))

	assert(uv.auto_activate_venv() == true)

	reset_env()
	vim.fn.delete(temp_dir, "rf")
end)

it("is_venv_active reflects VIRTUAL_ENV state", function()
	local uv = fresh_uv()
	vim.env.VIRTUAL_ENV = nil
	assert(uv.is_venv_active() == false)

	vim.env.VIRTUAL_ENV = "/some/path"
	assert(uv.is_venv_active() == true)

	reset_env()
end)

print("\nAPI:")

it("exports expected functions", function()
	local uv = fresh_uv()
	assert(type(uv.setup) == "function")
	assert(type(uv.activate_venv) == "function")
	assert(type(uv.auto_activate_venv) == "function")
	assert(type(uv.run_file) == "function")
	assert(type(uv.run_command) == "function")
	assert(type(uv.is_venv_active) == "function")
	assert(type(uv.get_venv) == "function")
	assert(type(uv.get_venv_path) == "function")
end)

it("setup exposes run_command globally", function()
	local uv = fresh_uv()
	_G.run_command = nil
	uv.setup({ auto_commands = false, keymaps = false, picker_integration = false })
	assert(type(_G.run_command) == "function")
end)

reset_env()

print("\n" .. string.rep("=", 40))
print(string.format("Tests: %d passed, %d failed", tests_passed, tests_failed))
print(string.rep("=", 40))

if tests_failed > 0 then
	os.exit(1)
end
