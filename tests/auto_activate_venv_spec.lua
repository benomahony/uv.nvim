-- Tests for granular auto_activate_venv setting
-- Run with: nvim --headless -u tests/minimal_init.lua -c "luafile tests/auto_activate_venv_spec.lua" -c "qa!"

local uv = require("uv")

local function assert_eq(expected, actual, message)
    if expected ~= actual then
        error(string.format("%s: expected %s, got %s", message or "Assertion failed", vim.inspect(expected), vim.inspect(actual)))
    end
    print(string.format("PASS: %s", message or "assertion"))
end

local function reset_state()
    vim.g.uv_auto_activate_venv = nil
    vim.b.uv_auto_activate_venv = nil
    uv.config.auto_activate_venv = true
end

print("\n=== Testing auto_activate_venv setting ===\n")

-- Test 1: is_auto_activate_enabled() respects global vim variable
print("Test 1: Global vim variable")
reset_state()
uv.setup({ auto_activate_venv = true })
assert_eq(true, uv.is_auto_activate_enabled(), "Default from config")

vim.g.uv_auto_activate_venv = false
assert_eq(false, uv.is_auto_activate_enabled(), "Global set to false")
reset_state()

-- Test 2: Buffer-local takes precedence over global
print("\nTest 2: Buffer-local precedence")
reset_state()
vim.g.uv_auto_activate_venv = true
vim.b.uv_auto_activate_venv = false
assert_eq(false, uv.is_auto_activate_enabled(), "Buffer false overrides global true")
reset_state()

-- Test 3: toggle_auto_activate_venv() works
print("\nTest 3: Toggle function")
reset_state()
uv.setup({ auto_activate_venv = true })
assert_eq(true, uv.is_auto_activate_enabled(), "Initial true")

uv.toggle_auto_activate_venv()
assert_eq(false, uv.is_auto_activate_enabled(), "After toggle: false")

uv.toggle_auto_activate_venv()
assert_eq(true, uv.is_auto_activate_enabled(), "After second toggle: true")
reset_state()

-- Test 4: Buffer-local toggle
print("\nTest 4: Buffer-local toggle")
reset_state()
vim.g.uv_auto_activate_venv = true

uv.toggle_auto_activate_venv(true)
assert_eq(false, uv.is_auto_activate_enabled(), "Buffer toggle to false")
assert_eq(false, vim.b.uv_auto_activate_venv, "Buffer var is false")
assert_eq(true, vim.g.uv_auto_activate_venv, "Global unchanged")
reset_state()

print("\n=== All tests passed! ===\n")
