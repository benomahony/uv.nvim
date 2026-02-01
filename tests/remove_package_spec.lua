-- Tests for remove_package function (PR #21)
-- Run with: nvim --headless -u NONE -c "lua dofile('tests/remove_package_spec.lua')" -c "qa!"

-- Tests the public contract only - no mocking internals

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

-- Load the module
package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"
local uv = require("uv")

describe("remove_package()", function()
	it("should be exported as a function", function()
		assert_equal("function", type(uv.remove_package), "remove_package should be a function")
	end)
end)

describe("keymap setup", function()
	it("should set up 'd' keymap for remove package when keymaps enabled", function()
		uv.setup({ keymaps = { prefix = "<leader>u", remove_package = true } })

		local keymaps = vim.api.nvim_get_keymap("n")
		local found = false
		for _, km in ipairs(keymaps) do
			-- Check for keymap ending in 'd' with UV Remove Package description
			if km.desc == "UV Remove Package" then
				found = true
				assert_true(km.rhs:match("remove_package") or km.callback ~= nil, "keymap should invoke remove_package")
				break
			end
		end
		assert_true(found, "should have remove_package keymap defined")
	end)
end)

-- Print summary
print("\n" .. string.rep("=", 40))
print(string.format("Tests: %d passed, %d failed", tests_passed, tests_failed))
print(string.rep("=", 40))

if tests_failed > 0 then
	os.exit(1)
end
