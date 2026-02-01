-- Tests for uv.nvim core functionality
-- Run with: nvim --headless -u tests/minimal_init.lua -c "luafile tests/uv_spec.lua"

local uv = require("uv")

-- Store original state
local original_path = vim.env.PATH
local original_venv = vim.env.VIRTUAL_ENV
local original_cwd = vim.fn.getcwd()

local function reset_env()
	vim.env.PATH = original_path
	vim.env.VIRTUAL_ENV = original_venv
	vim.cmd("cd " .. vim.fn.fnameescape(original_cwd))
end

print("\n=== uv.nvim tests ===\n")

-- Configuration tests
print("Configuration:")

assert(uv.config.auto_activate_venv == true)
assert(uv.config.keymaps.prefix == "<leader>x")
assert(uv.config.execution.run_command == "uv run python")
assert(uv.config.execution.terminal == "split")
print("PASS: default config")

package.loaded["uv"] = nil
uv = require("uv")
uv.setup({ auto_activate_venv = false, auto_commands = false, keymaps = false, picker_integration = false })
assert(uv.config.auto_activate_venv == false)
assert(uv.config.notify_activate_venv == true)
print("PASS: merges custom config")

package.loaded["uv"] = nil
uv = require("uv")
uv.setup({
	execution = { run_command = "python3", terminal = "vsplit" },
	auto_commands = false,
	keymaps = false,
	picker_integration = false,
})
assert(uv.config.execution.run_command == "python3")
assert(uv.config.execution.terminal == "vsplit")
print("PASS: custom execution config")

-- Command tests
print("\nCommands:")

package.loaded["uv"] = nil
uv = require("uv")
uv.setup({ auto_commands = false, keymaps = false, picker_integration = false })
local cmds = vim.api.nvim_get_commands({})
assert(cmds.UVInit ~= nil, "UVInit should exist")
assert(cmds.UVRunFile ~= nil, "UVRunFile should exist")
assert(cmds.UVRunSelection ~= nil, "UVRunSelection should exist")
assert(cmds.UVRunFunction ~= nil, "UVRunFunction should exist")
print("PASS: registers user commands")

-- Virtual environment tests
print("\nVirtual Environment:")

package.loaded["uv"] = nil
uv = require("uv")
uv.config.notify_activate_venv = false
local test_path = vim.fn.tempname()
vim.fn.mkdir(test_path .. "/bin", "p")
uv.activate_venv(test_path)
assert(vim.env.VIRTUAL_ENV == test_path)
reset_env()
vim.fn.delete(test_path, "rf")
print("PASS: activate_venv sets VIRTUAL_ENV")

package.loaded["uv"] = nil
uv = require("uv")
uv.config.notify_activate_venv = false
test_path = vim.fn.tempname()
vim.fn.mkdir(test_path .. "/bin", "p")
uv.activate_venv(test_path)
assert(vim.env.PATH:find(test_path .. "/bin", 1, true) == 1, "PATH should start with venv bin")
reset_env()
vim.fn.delete(test_path, "rf")
print("PASS: activate_venv prepends to PATH")

package.loaded["uv"] = nil
uv = require("uv")
uv.config.notify_activate_venv = false
local temp_dir = vim.fn.tempname()
vim.fn.mkdir(temp_dir, "p")
vim.cmd("cd " .. vim.fn.fnameescape(temp_dir))
assert(uv.auto_activate_venv() == false)
reset_env()
vim.fn.delete(temp_dir, "rf")
print("PASS: auto_activate_venv returns false when no .venv")

package.loaded["uv"] = nil
uv = require("uv")
uv.config.notify_activate_venv = false
temp_dir = vim.fn.tempname()
vim.fn.mkdir(temp_dir .. "/.venv/bin", "p")
vim.cmd("cd " .. vim.fn.fnameescape(temp_dir))
assert(uv.auto_activate_venv() == true)
reset_env()
vim.fn.delete(temp_dir, "rf")
print("PASS: auto_activate_venv returns true when .venv exists")

package.loaded["uv"] = nil
uv = require("uv")
vim.env.VIRTUAL_ENV = nil
assert(uv.is_venv_active() == false)
vim.env.VIRTUAL_ENV = "/some/path"
assert(uv.is_venv_active() == true)
reset_env()
print("PASS: is_venv_active reflects VIRTUAL_ENV state")

-- API tests
print("\nAPI:")

package.loaded["uv"] = nil
uv = require("uv")
assert(type(uv.setup) == "function")
assert(type(uv.activate_venv) == "function")
assert(type(uv.auto_activate_venv) == "function")
assert(type(uv.run_file) == "function")
assert(type(uv.run_command) == "function")
assert(type(uv.is_venv_active) == "function")
assert(type(uv.get_venv) == "function")
assert(type(uv.get_venv_path) == "function")
print("PASS: exports expected functions")

package.loaded["uv"] = nil
uv = require("uv")
_G.run_command = nil
uv.setup({ auto_commands = false, keymaps = false, picker_integration = false })
assert(type(_G.run_command) == "function")
print("PASS: setup exposes run_command globally")

reset_env()

print("\n=== All tests passed! ===\n")
