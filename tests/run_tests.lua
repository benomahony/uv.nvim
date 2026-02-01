#!/usr/bin/env lua
-- Test runner script for uv.nvim
-- Usage: nvim --headless -u tests/minimal_init.lua -c "luafile tests/run_tests.lua"

local function run_tests()
    local ok, plenary = pcall(require, "plenary")
    if not ok then
        print("Error: plenary.nvim is required for running tests")
        print("Install plenary.nvim to run the test suite")
        vim.cmd("qa!")
        return
    end

    local test_harness = require("plenary.test_harness")

    print("=" .. string.rep("=", 60))
    print("Running uv.nvim test suite")
    print("=" .. string.rep("=", 60))
    print("")

    -- Run all tests in the plenary directory
    test_harness.test_directory("tests/plenary/", {
        minimal_init = "tests/minimal_init.lua",
        sequential = true,
    })
end

-- Run tests
run_tests()
