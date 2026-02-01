-- Standalone tests for virtual environment functionality
-- Run with: nvim --headless -u tests/minimal_init.lua -c "luafile tests/standalone/test_venv.lua" -c "qa!"

local t = require("tests.standalone.runner")

t.describe("uv.nvim virtual environment", function()
    -- Store original environment
    local original_path
    local original_venv
    local original_cwd
    local test_venv_path

    -- Setup/teardown for each test
    local function setup_test()
        original_path = vim.env.PATH
        original_venv = vim.env.VIRTUAL_ENV
        original_cwd = vim.fn.getcwd()
        test_venv_path = vim.fn.tempname()
        vim.fn.mkdir(test_venv_path .. "/bin", "p")
    end

    local function teardown_test()
        vim.env.PATH = original_path
        vim.env.VIRTUAL_ENV = original_venv
        if vim.fn.isdirectory(test_venv_path) == 1 then
            vim.fn.delete(test_venv_path, "rf")
        end
        vim.cmd("cd " .. vim.fn.fnameescape(original_cwd))
    end

    t.describe("activate_venv", function()
        t.it("sets VIRTUAL_ENV environment variable", function()
            setup_test()
            package.loaded["uv"] = nil
            local uv = require("uv")

            uv.config.notify_activate_venv = false
            uv.activate_venv(test_venv_path)
            t.assert_equals(test_venv_path, vim.env.VIRTUAL_ENV)

            teardown_test()
        end)

        t.it("prepends venv bin to PATH", function()
            setup_test()
            package.loaded["uv"] = nil
            local uv = require("uv")

            uv.config.notify_activate_venv = false
            local expected_prefix = test_venv_path .. "/bin:"
            uv.activate_venv(test_venv_path)
            t.assert_contains(vim.env.PATH, expected_prefix)

            teardown_test()
        end)

        t.it("preserves existing PATH entries", function()
            setup_test()
            package.loaded["uv"] = nil
            local uv = require("uv")

            uv.config.notify_activate_venv = false
            local original_path_copy = vim.env.PATH
            uv.activate_venv(test_venv_path)
            -- The original path should still be present after the venv bin
            t.assert_contains(vim.env.PATH, original_path_copy)

            teardown_test()
        end)

        t.it("works with paths containing spaces", function()
            setup_test()
            package.loaded["uv"] = nil
            local uv = require("uv")

            uv.config.notify_activate_venv = false
            local space_path = vim.fn.tempname() .. " with spaces"
            vim.fn.mkdir(space_path .. "/bin", "p")

            uv.activate_venv(space_path)
            t.assert_equals(space_path, vim.env.VIRTUAL_ENV)

            -- Cleanup
            vim.fn.delete(space_path, "rf")
            teardown_test()
        end)
    end)

    t.describe("auto_activate_venv", function()
        t.it("returns false when no .venv exists", function()
            setup_test()
            package.loaded["uv"] = nil
            local uv = require("uv")

            -- Create a temp directory without .venv
            local temp_dir = vim.fn.tempname()
            vim.fn.mkdir(temp_dir, "p")
            vim.cmd("cd " .. vim.fn.fnameescape(temp_dir))

            uv.config.notify_activate_venv = false
            local result = uv.auto_activate_venv()
            t.assert_false(result)

            -- Cleanup
            vim.fn.delete(temp_dir, "rf")
            teardown_test()
        end)

        t.it("returns true and activates when .venv exists", function()
            setup_test()
            package.loaded["uv"] = nil
            local uv = require("uv")

            -- Create a temp directory with .venv
            local temp_dir = vim.fn.tempname()
            vim.fn.mkdir(temp_dir .. "/.venv/bin", "p")
            vim.cmd("cd " .. vim.fn.fnameescape(temp_dir))

            uv.config.notify_activate_venv = false
            local result = uv.auto_activate_venv()
            t.assert_true(result)
            t.assert_contains(vim.env.VIRTUAL_ENV, "%.venv$")

            -- Cleanup
            vim.fn.delete(temp_dir, "rf")
            teardown_test()
        end)

        t.it("activates the correct venv path", function()
            setup_test()
            package.loaded["uv"] = nil
            local uv = require("uv")

            local temp_dir = vim.fn.tempname()
            vim.fn.mkdir(temp_dir .. "/.venv/bin", "p")
            vim.cmd("cd " .. vim.fn.fnameescape(temp_dir))

            uv.config.notify_activate_venv = false
            uv.auto_activate_venv()
            local expected_venv = temp_dir .. "/.venv"
            t.assert_equals(expected_venv, vim.env.VIRTUAL_ENV)

            -- Cleanup
            vim.fn.delete(temp_dir, "rf")
            teardown_test()
        end)
    end)
end)

t.describe("uv.nvim venv detection utilities", function()
    local utils = require("uv.utils")

    t.describe("is_venv_path", function()
        t.it("recognizes standard .venv path", function()
            t.assert_true(utils.is_venv_path("/home/user/project/.venv"))
        end)

        t.it("recognizes venv without dot", function()
            t.assert_true(utils.is_venv_path("/home/user/project/venv"))
        end)

        t.it("recognizes .venv as part of longer path", function()
            t.assert_true(utils.is_venv_path("/home/user/project/.venv/bin/python"))
        end)

        t.it("rejects regular directories", function()
            t.assert_false(utils.is_venv_path("/home/user/project/src"))
            t.assert_false(utils.is_venv_path("/home/user/project/lib"))
            t.assert_false(utils.is_venv_path("/usr/bin"))
        end)
    end)
end)

-- Print results and exit
local exit_code = t.print_results()
vim.cmd("cq " .. exit_code)
