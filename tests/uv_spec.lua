-- Tests for uv.nvim core functionality
-- Run with: nvim --headless -u tests/minimal_init.lua -c "luafile tests/uv_spec.lua" -c "qa!"

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

local function assert_eq(expected, actual, msg)
	if expected ~= actual then
		error((msg or "Assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
end

local function assert_true(val, msg)
	if not val then
		error((msg or "Expected true") .. ", got " .. tostring(val))
	end
end

local function assert_false(val, msg)
	if val then
		error((msg or "Expected false") .. ", got " .. tostring(val))
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

-- Load module fresh for each test
local function fresh_uv()
	package.loaded["uv"] = nil
	return require("uv")
end

print("\n=== uv.nvim tests ===\n")

-- Configuration tests
print("Configuration:")

it("has correct default config", function()
	local uv = fresh_uv()
	assert_true(uv.config.auto_activate_venv)
	assert_eq("<leader>x", uv.config.keymaps.prefix)
	assert_eq("uv run python", uv.config.execution.run_command)
	assert_eq("split", uv.config.execution.terminal)
end)

it("merges custom config", function()
	local uv = fresh_uv()
	uv.setup({
		auto_activate_venv = false,
		auto_commands = false,
		keymaps = false,
		picker_integration = false,
	})
	assert_false(uv.config.auto_activate_venv)
	assert_true(uv.config.notify_activate_venv) -- default preserved
end)

it("accepts custom execution config", function()
	local uv = fresh_uv()
	uv.setup({
		execution = { run_command = "python3", terminal = "vsplit" },
		auto_commands = false,
		keymaps = false,
		picker_integration = false,
	})
	assert_eq("python3", uv.config.execution.run_command)
	assert_eq("vsplit", uv.config.execution.terminal)
end)

-- Command registration tests
print("\nCommands:")

it("registers user commands", function()
	local uv = fresh_uv()
	uv.setup({ auto_commands = false, keymaps = false, picker_integration = false })
	local cmds = vim.api.nvim_get_commands({})
	assert_true(cmds.UVInit ~= nil, "UVInit should exist")
	assert_true(cmds.UVRunFile ~= nil, "UVRunFile should exist")
	assert_true(cmds.UVRunSelection ~= nil, "UVRunSelection should exist")
	assert_true(cmds.UVRunFunction ~= nil, "UVRunFunction should exist")
end)

-- Virtual environment tests
print("\nVirtual Environment:")

it("activate_venv sets VIRTUAL_ENV", function()
	local uv = fresh_uv()
	uv.config.notify_activate_venv = false
	local test_path = vim.fn.tempname()
	vim.fn.mkdir(test_path .. "/bin", "p")

	uv.activate_venv(test_path)
	assert_eq(test_path, vim.env.VIRTUAL_ENV)

	reset_env()
	vim.fn.delete(test_path, "rf")
end)

it("activate_venv prepends to PATH", function()
	local uv = fresh_uv()
	uv.config.notify_activate_venv = false
	local test_path = vim.fn.tempname()
	vim.fn.mkdir(test_path .. "/bin", "p")

	uv.activate_venv(test_path)
	assert_true(vim.env.PATH:find(test_path .. "/bin", 1, true) == 1, "PATH should start with venv bin")

	reset_env()
	vim.fn.delete(test_path, "rf")
end)

it("auto_activate_venv returns false when no .venv", function()
	local uv = fresh_uv()
	uv.config.notify_activate_venv = false
	local temp_dir = vim.fn.tempname()
	vim.fn.mkdir(temp_dir, "p")
	vim.cmd("cd " .. vim.fn.fnameescape(temp_dir))

	assert_false(uv.auto_activate_venv())

	reset_env()
	vim.fn.delete(temp_dir, "rf")
end)

it("auto_activate_venv returns true when .venv exists", function()
	local uv = fresh_uv()
	uv.config.notify_activate_venv = false
	local temp_dir = vim.fn.tempname()
	vim.fn.mkdir(temp_dir .. "/.venv/bin", "p")
	vim.cmd("cd " .. vim.fn.fnameescape(temp_dir))

	assert_true(uv.auto_activate_venv())

	reset_env()
	vim.fn.delete(temp_dir, "rf")
end)

it("is_venv_active reflects VIRTUAL_ENV state", function()
	local uv = fresh_uv()
	vim.env.VIRTUAL_ENV = nil
	assert_false(uv.is_venv_active())

	vim.env.VIRTUAL_ENV = "/some/path"
	assert_true(uv.is_venv_active())

	reset_env()
end)

-- API tests
print("\nAPI:")

it("exports expected functions", function()
	local uv = fresh_uv()
	assert_eq("function", type(uv.setup))
	assert_eq("function", type(uv.activate_venv))
	assert_eq("function", type(uv.auto_activate_venv))
	assert_eq("function", type(uv.run_file))
	assert_eq("function", type(uv.run_command))
	assert_eq("function", type(uv.is_venv_active))
	assert_eq("function", type(uv.get_venv))
	assert_eq("function", type(uv.get_venv_path))
end)

it("setup exposes run_command globally", function()
	local uv = fresh_uv()
	_G.run_command = nil
	uv.setup({ auto_commands = false, keymaps = false, picker_integration = false })
	assert_eq("function", type(_G.run_command))
end)

-- Cleanup
reset_env()

-- Summary
print("\n" .. string.rep("=", 40))
print(string.format("Tests: %d passed, %d failed", tests_passed, tests_failed))
print(string.rep("=", 40))

if tests_failed > 0 then
	os.exit(1)
end
