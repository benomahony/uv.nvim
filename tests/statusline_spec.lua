-- Tests for statusline helper functions
-- Run with: nvim --headless -u NONE -c "lua dofile('tests/statusline_spec.lua')" -c "qa!"

-- Ensure we're running in Neovim
assert(vim and vim.fn, "This test must be run in Neovim")

-- Minimal test framework
local tests_passed = 0
local tests_failed = 0

local function describe(name, fn)
    print("\n=== " .. name .. " ===")
    fn()
end

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

local function assert_equal(expected, actual, msg)
    if expected ~= actual then
        error((msg or "Assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function assert_true(value, msg)
    if not value then
        error((msg or "Assertion failed") .. ": expected true, got " .. tostring(value))
    end
end

local function assert_false(value, msg)
    if value then
        error((msg or "Assertion failed") .. ": expected false, got " .. tostring(value))
    end
end

local function assert_nil(value, msg)
    if value ~= nil then
        error((msg or "Assertion failed") .. ": expected nil, got " .. tostring(value))
    end
end

-- Store original VIRTUAL_ENV
local original_venv = vim.env.VIRTUAL_ENV

-- Load the module
package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"
local uv = require("uv")

-- Test directory for creating real files
local test_dir = vim.fn.tempname()
vim.fn.mkdir(test_dir, "p")

-- Helper to create a test venv with pyvenv.cfg
local function create_test_venv(venv_name, prompt)
    local venv_dir = test_dir .. "/" .. venv_name
    vim.fn.mkdir(venv_dir, "p")

    local pyvenv_cfg = venv_dir .. "/pyvenv.cfg"
    local file = io.open(pyvenv_cfg, "w")
    file:write("home = /usr/bin\n")
    file:write("include-system-site-packages = false\n")
    if prompt then
        file:write("prompt = " .. prompt .. "\n")
    end
    file:close()

    return venv_dir
end

-- Run tests
describe("is_venv_active()", function()
    it("should return false when no venv is active", function()
        vim.env.VIRTUAL_ENV = nil
        assert_false(uv.is_venv_active(), "is_venv_active should be false when VIRTUAL_ENV is nil")
    end)

    it("should return true when a venv is active", function()
        vim.env.VIRTUAL_ENV = test_dir .. "/some-project/.venv"
        assert_true(uv.is_venv_active(), "is_venv_active should be true when VIRTUAL_ENV is set")
    end)
end)

describe("get_venv()", function()
    it("should return nil when no venv is active", function()
        vim.env.VIRTUAL_ENV = nil
        assert_nil(uv.get_venv(), "get_venv should return nil when VIRTUAL_ENV is nil")
    end)

    it("should return prompt from pyvenv.cfg", function()
        local venv_path = create_test_venv("test-venv", "my-awesome-project")
        vim.env.VIRTUAL_ENV = venv_path
        assert_equal("my-awesome-project", uv.get_venv(), "get_venv should return prompt from pyvenv.cfg")
    end)

    it("should return venv folder name when no prompt in pyvenv.cfg", function()
        local venv_path = create_test_venv("custom-env", nil)
        vim.env.VIRTUAL_ENV = venv_path
        assert_equal("custom-env", uv.get_venv(), "get_venv should return venv folder name when no prompt")
    end)

    it("should return venv folder name when no pyvenv.cfg exists", function()
        local venv_dir = test_dir .. "/no-cfg"
        vim.fn.mkdir(venv_dir, "p")
        vim.env.VIRTUAL_ENV = venv_dir
        assert_equal("no-cfg", uv.get_venv(), "get_venv should return venv folder name as fallback")
    end)
end)

describe("get_venv_path()", function()
    it("should return nil when no venv is active", function()
        vim.env.VIRTUAL_ENV = nil
        assert_nil(uv.get_venv_path(), "get_venv_path should return nil when VIRTUAL_ENV is nil")
    end)

    it("should return the full venv path when active", function()
        local expected_path = test_dir .. "/test-project/.venv"
        vim.fn.mkdir(expected_path, "p")
        vim.env.VIRTUAL_ENV = expected_path
        assert_equal(expected_path, uv.get_venv_path(), "get_venv_path should return full path")
    end)
end)

-- Cleanup
vim.env.VIRTUAL_ENV = original_venv
vim.fn.delete(test_dir, "rf")

-- Print summary
print("\n" .. string.rep("=", 40))
print(string.format("Tests: %d passed, %d failed", tests_passed, tests_failed))
print(string.rep("=", 40))

-- Exit with appropriate code
if tests_failed > 0 then
    os.exit(1)
end
