-- Tests for granular auto_activate_venv setting
-- Run with: nvim --headless -u tests/minimal_init.lua -c "luafile tests/auto_activate_venv_spec.lua" -c "qa!"

local uv = require("uv")

-- Test utilities
local function assert_eq(expected, actual, message)
	if expected ~= actual then
		error(string.format("%s: expected %s, got %s", message or "Assertion failed", vim.inspect(expected), vim.inspect(actual)))
	end
	print(string.format("PASS: %s", message or "assertion"))
end

local function assert_true(value, message)
	if not value then
		error(string.format("%s: expected true, got %s", message or "Assertion failed", vim.inspect(value)))
	end
	print(string.format("PASS: %s", message or "assertion"))
end

local function assert_false(value, message)
	if value then
		error(string.format("%s: expected false, got %s", message or "Assertion failed", vim.inspect(value)))
	end
	print(string.format("PASS: %s", message or "assertion"))
end

local function reset_state()
	-- Reset vim variables
	vim.g.uv_auto_activate_venv = nil
	vim.b.uv_auto_activate_venv = nil
	-- Reset config to default
	uv.config.auto_activate_venv = true
end

print("\n=== Testing auto_activate_venv setting ===\n")

-- Test 1: is_auto_activate_enabled() respects global vim variable
print("Test 1: is_auto_activate_enabled() respects global vim variable")
reset_state()
uv.setup({ auto_activate_venv = true })
assert_eq(true, uv.is_auto_activate_enabled(), "Default should be true from config")

vim.g.uv_auto_activate_venv = false
assert_eq(false, uv.is_auto_activate_enabled(), "Global vim var set to false")

vim.g.uv_auto_activate_venv = true
assert_eq(true, uv.is_auto_activate_enabled(), "Global vim var set to true")
reset_state()

-- Test 2: Buffer-local variable takes precedence over global
print("\nTest 2: Buffer-local variable takes precedence over global")
reset_state()
uv.setup({ auto_activate_venv = true })
vim.g.uv_auto_activate_venv = true
vim.b.uv_auto_activate_venv = false
assert_eq(false, uv.is_auto_activate_enabled(), "Buffer-local false overrides global true")

vim.g.uv_auto_activate_venv = false
vim.b.uv_auto_activate_venv = true
assert_eq(true, uv.is_auto_activate_enabled(), "Buffer-local true overrides global false")
reset_state()

-- Test 3: Config value is used when vim vars are nil
print("\nTest 3: Config value is used when vim vars are nil")
reset_state()
uv.setup({ auto_activate_venv = true })
assert_eq(true, uv.is_auto_activate_enabled(), "Config true, vars nil -> true")

uv.setup({ auto_activate_venv = false })
assert_eq(false, uv.is_auto_activate_enabled(), "Config false, vars nil -> false")
reset_state()

-- Test 4: toggle_auto_activate_venv() toggles global by default
print("\nTest 4: toggle_auto_activate_venv() toggles global by default")
reset_state()
uv.setup({ auto_activate_venv = true })
local initial = uv.is_auto_activate_enabled()
assert_eq(true, initial, "Initial state should be true")

uv.toggle_auto_activate_venv()
assert_eq(false, uv.is_auto_activate_enabled(), "After first toggle should be false")

uv.toggle_auto_activate_venv()
assert_eq(true, uv.is_auto_activate_enabled(), "After second toggle should be true")
reset_state()

-- Test 5: toggle_auto_activate_venv(true) toggles buffer-local
print("\nTest 5: toggle_auto_activate_venv(true) toggles buffer-local")
reset_state()
uv.setup({ auto_activate_venv = true })
vim.g.uv_auto_activate_venv = true

uv.toggle_auto_activate_venv(true) -- buffer-local toggle
assert_eq(false, uv.is_auto_activate_enabled(), "Buffer-local toggle from true to false")

uv.toggle_auto_activate_venv(true) -- buffer-local toggle again
assert_eq(true, uv.is_auto_activate_enabled(), "Buffer-local toggle from false to true")
reset_state()

-- Test 6: set_auto_activate_venv() sets specific value
print("\nTest 6: set_auto_activate_venv() sets specific value")
reset_state()
uv.setup({ auto_activate_venv = true })

uv.set_auto_activate_venv(false)
assert_eq(false, vim.g.uv_auto_activate_venv, "Global var should be false")
assert_eq(false, uv.is_auto_activate_enabled(), "is_auto_activate_enabled should return false")

uv.set_auto_activate_venv(true, true) -- buffer-local
assert_eq(true, vim.b.uv_auto_activate_venv, "Buffer-local var should be true")
assert_eq(true, uv.is_auto_activate_enabled(), "Buffer-local should override global")
reset_state()

-- Test 7: Verify setup initializes vim.g from config when nil
print("\nTest 7: Verify setup initializes vim.g from config")
reset_state()
vim.g.uv_auto_activate_venv = nil
uv.setup({ auto_activate_venv = false })
-- vim.g should now reflect the config value (or be implicitly used)
assert_eq(false, uv.is_auto_activate_enabled(), "Setup should respect config value")
reset_state()

print("\n=== All tests passed! ===\n")
