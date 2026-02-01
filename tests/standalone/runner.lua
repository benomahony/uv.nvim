-- Standalone test runner for uv.nvim
-- No external dependencies required - just Neovim
-- Usage: nvim --headless -u tests/minimal_init.lua -c "luafile tests/standalone/runner.lua" -c "qa!"

local M = {}

-- Test statistics
M.stats = {
    passed = 0,
    failed = 0,
    total = 0,
}

-- Current test context
M.current_describe = ""
M.errors = {}

-- Color codes for terminal output
local colors = {
    green = "\27[32m",
    red = "\27[31m",
    yellow = "\27[33m",
    reset = "\27[0m",
    bold = "\27[1m",
}

-- Check if running in a terminal that supports colors
local function supports_colors()
    return vim.fn.has("nvim") == 1 and vim.o.termguicolors or vim.fn.has("termguicolors") == 1
end

local function colorize(text, color)
    if supports_colors() then
        return (colors[color] or "") .. text .. colors.reset
    end
    return text
end

-- Simple assertion functions
function M.assert_equals(expected, actual, message)
    M.stats.total = M.stats.total + 1
    if expected == actual then
        M.stats.passed = M.stats.passed + 1
        return true
    else
        M.stats.failed = M.stats.failed + 1
        local err = string.format(
            "%s\n  Expected: %s\n  Actual: %s",
            message or "Values not equal",
            vim.inspect(expected),
            vim.inspect(actual)
        )
        table.insert(M.errors, { context = M.current_describe, error = err })
        return false
    end
end

function M.assert_true(value, message)
    M.stats.total = M.stats.total + 1
    if value == true then
        M.stats.passed = M.stats.passed + 1
        return true
    else
        M.stats.failed = M.stats.failed + 1
        local err = string.format("%s\n  Value was: %s", message or "Expected true", vim.inspect(value))
        table.insert(M.errors, { context = M.current_describe, error = err })
        return false
    end
end

function M.assert_false(value, message)
    M.stats.total = M.stats.total + 1
    if value == false then
        M.stats.passed = M.stats.passed + 1
        return true
    else
        M.stats.failed = M.stats.failed + 1
        local err = string.format("%s\n  Value was: %s", message or "Expected false", vim.inspect(value))
        table.insert(M.errors, { context = M.current_describe, error = err })
        return false
    end
end

function M.assert_nil(value, message)
    M.stats.total = M.stats.total + 1
    if value == nil then
        M.stats.passed = M.stats.passed + 1
        return true
    else
        M.stats.failed = M.stats.failed + 1
        local err = string.format("%s\n  Value was: %s", message or "Expected nil", vim.inspect(value))
        table.insert(M.errors, { context = M.current_describe, error = err })
        return false
    end
end

function M.assert_not_nil(value, message)
    M.stats.total = M.stats.total + 1
    if value ~= nil then
        M.stats.passed = M.stats.passed + 1
        return true
    else
        M.stats.failed = M.stats.failed + 1
        table.insert(M.errors, { context = M.current_describe, error = message or "Expected non-nil value" })
        return false
    end
end

function M.assert_type(expected_type, value, message)
    M.stats.total = M.stats.total + 1
    if type(value) == expected_type then
        M.stats.passed = M.stats.passed + 1
        return true
    else
        M.stats.failed = M.stats.failed + 1
        local err = string.format(
            "%s\n  Expected type: %s\n  Actual type: %s",
            message or "Type mismatch",
            expected_type,
            type(value)
        )
        table.insert(M.errors, { context = M.current_describe, error = err })
        return false
    end
end

function M.assert_contains(haystack, needle, message)
    M.stats.total = M.stats.total + 1
    if type(haystack) == "string" and haystack:match(needle) then
        M.stats.passed = M.stats.passed + 1
        return true
    else
        M.stats.failed = M.stats.failed + 1
        local err = string.format(
            "%s\n  String: %s\n  Pattern: %s",
            message or "Pattern not found",
            vim.inspect(haystack),
            needle
        )
        table.insert(M.errors, { context = M.current_describe, error = err })
        return false
    end
end

function M.assert_no_error(fn, message)
    M.stats.total = M.stats.total + 1
    local ok, err = pcall(fn)
    if ok then
        M.stats.passed = M.stats.passed + 1
        return true
    else
        M.stats.failed = M.stats.failed + 1
        local error_msg = string.format("%s\n  Error: %s", message or "Function threw error", tostring(err))
        table.insert(M.errors, { context = M.current_describe, error = error_msg })
        return false
    end
end

-- Test organization
function M.describe(name, fn)
    local old_describe = M.current_describe
    M.current_describe = (old_describe ~= "" and old_describe .. " > " or "") .. name
    print(colorize("▸ " .. name, "bold"))
    fn()
    M.current_describe = old_describe
end

function M.it(name, fn)
    local full_name = M.current_describe .. " > " .. name
    local old_describe = M.current_describe
    M.current_describe = full_name

    local ok, err = pcall(fn)
    if not ok then
        M.stats.total = M.stats.total + 1
        M.stats.failed = M.stats.failed + 1
        table.insert(M.errors, { context = full_name, error = tostring(err) })
        print(colorize("  ✗ " .. name, "red"))
    else
        print(colorize("  ✓ " .. name, "green"))
    end

    M.current_describe = old_describe
end

-- Print final results
function M.print_results()
    print("")
    print(string.rep("=", 60))

    if M.stats.failed == 0 then
        print(colorize(string.format("All %d tests passed!", M.stats.passed), "green"))
    else
        print(colorize(string.format("%d passed, %d failed", M.stats.passed, M.stats.failed), "red"))
        print("")
        print(colorize("Failures:", "red"))
        for _, err in ipairs(M.errors) do
            print(colorize("  " .. err.context, "yellow"))
            print("    " .. err.error:gsub("\n", "\n    "))
        end
    end

    print(string.rep("=", 60))

    -- Return exit code
    return M.stats.failed == 0 and 0 or 1
end

return M
