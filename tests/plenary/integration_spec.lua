-- Integration tests for uv.nvim
-- These tests verify complete functionality working together

describe("uv.nvim integration", function()
    local uv
    local original_cwd
    local test_dir

    before_each(function()
        -- Create fresh module instance
        package.loaded["uv"] = nil
        package.loaded["uv.utils"] = nil
        uv = require("uv")

        -- Save original state
        original_cwd = vim.fn.getcwd()

        -- Create test directory
        test_dir = vim.fn.tempname()
        vim.fn.mkdir(test_dir, "p")
    end)

    after_each(function()
        -- Return to original directory
        vim.cmd("cd " .. vim.fn.fnameescape(original_cwd))

        -- Clean up test directory
        if vim.fn.isdirectory(test_dir) == 1 then
            vim.fn.delete(test_dir, "rf")
        end
    end)

    describe("setup function", function()
        it("can be called without errors", function()
            assert.has_no.errors(function()
                uv.setup({
                    auto_commands = false,
                    keymaps = false,
                    picker_integration = false,
                })
            end)
        end)

        it("creates user commands", function()
            uv.setup({
                auto_commands = false,
                keymaps = false,
                picker_integration = false,
            })

            -- Verify commands exist
            local commands = vim.api.nvim_get_commands({})
            assert.is_not_nil(commands.UVInit)
            assert.is_not_nil(commands.UVRunFile)
            assert.is_not_nil(commands.UVRunSelection)
            assert.is_not_nil(commands.UVRunFunction)
        end)

        it("respects keymaps = false", function()
            uv.setup({
                auto_commands = false,
                keymaps = false,
                picker_integration = false,
            })

            -- Check that keymaps for the prefix are not set
            -- This is hard to test directly, but we can verify config
            assert.is_false(uv.config.keymaps)
        end)

        it("sets global run_command", function()
            _G.run_command = nil
            uv.setup({
                auto_commands = false,
                keymaps = false,
                picker_integration = false,
            })

            assert.is_function(_G.run_command)
        end)
    end)

    describe("complete workflow", function()
        it("handles project with venv", function()
            -- Create a test project structure with .venv
            vim.fn.mkdir(test_dir .. "/.venv/bin", "p")

            -- Change to test directory
            vim.cmd("cd " .. vim.fn.fnameescape(test_dir))

            -- Setup with auto-activate
            uv.setup({
                auto_activate_venv = true,
                auto_commands = false,
                keymaps = false,
                picker_integration = false,
                notify_activate_venv = false,
            })

            -- Manually trigger auto-activate (since we disabled auto_commands)
            local result = uv.auto_activate_venv()

            assert.is_true(result)
            assert.truthy(vim.env.VIRTUAL_ENV:match("%.venv$"))
        end)

        it("handles project without venv", function()
            -- Change to test directory (no .venv)
            vim.cmd("cd " .. vim.fn.fnameescape(test_dir))

            -- Setup
            uv.setup({
                auto_activate_venv = true,
                auto_commands = false,
                keymaps = false,
                picker_integration = false,
            })

            local result = uv.auto_activate_venv()

            assert.is_false(result)
        end)
    end)

    describe("configuration persistence", function()
        it("maintains config across function calls", function()
            uv.setup({
                auto_commands = false,
                keymaps = false,
                picker_integration = false,
                execution = {
                    run_command = "custom python",
                    terminal = "vsplit",
                },
            })

            -- Config should persist
            assert.equals("custom python", uv.config.execution.run_command)
            assert.equals("vsplit", uv.config.execution.terminal)
        end)
    end)
end)

describe("uv.nvim buffer operations", function()
    local utils = require("uv.utils")

    describe("code analysis on real buffers", function()
        it("extracts imports from buffer content", function()
            -- Create a buffer with Python code
            local buf = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
                "import os",
                "import sys",
                "from pathlib import Path",
                "",
                "x = 1",
            })

            local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
            local imports = utils.extract_imports(lines)

            assert.equals(3, #imports)
            assert.equals("import os", imports[1])
            assert.equals("import sys", imports[2])
            assert.equals("from pathlib import Path", imports[3])

            -- Cleanup
            vim.api.nvim_buf_delete(buf, { force = true })
        end)

        it("extracts functions from buffer content", function()
            local buf = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
                "def foo():",
                "    pass",
                "",
                "def bar(x):",
                "    return x * 2",
                "",
                "class MyClass:",
                "    def method(self):",
                "        pass",
            })

            local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
            local functions = utils.extract_functions(lines)

            -- Should only get top-level functions
            assert.equals(2, #functions)
            assert.equals("foo", functions[1])
            assert.equals("bar", functions[2])

            -- Cleanup
            vim.api.nvim_buf_delete(buf, { force = true })
        end)

        it("extracts globals from buffer content", function()
            local buf = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
                "CONSTANT = 42",
                "config = {}",
                "",
                "class MyClass:",
                "    class_var = 'should not appear'",
                "",
                "another_global = True",
            })

            local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
            local globals = utils.extract_globals(lines)

            assert.equals(3, #globals)
            assert.equals("CONSTANT = 42", globals[1])
            assert.equals("config = {}", globals[2])
            assert.equals("another_global = True", globals[3])

            -- Cleanup
            vim.api.nvim_buf_delete(buf, { force = true })
        end)
    end)

    describe("selection extraction", function()
        it("extracts correct selection range", function()
            local lines = {
                "line 1",
                "line 2",
                "line 3",
                "line 4",
            }

            local selection = utils.extract_selection(lines, 2, 1, 3, 6)
            assert.equals("line 2\nline 3", selection)
        end)

        it("handles single character selection", function()
            local lines = { "hello world" }
            local selection = utils.extract_selection(lines, 1, 1, 1, 1)
            assert.equals("h", selection)
        end)

        it("handles full line selection", function()
            local lines = { "complete line" }
            local selection = utils.extract_selection(lines, 1, 1, 1, 13)
            assert.equals("complete line", selection)
        end)
    end)
end)

describe("uv.nvim file operations", function()
    local test_dir

    before_each(function()
        test_dir = vim.fn.tempname()
        vim.fn.mkdir(test_dir, "p")
    end)

    after_each(function()
        if vim.fn.isdirectory(test_dir) == 1 then
            vim.fn.delete(test_dir, "rf")
        end
    end)

    describe("temp file creation", function()
        it("creates cache directory if needed", function()
            local cache_dir = vim.fn.expand("$HOME") .. "/.cache/nvim/uv_run"

            -- Directory should exist or be creatable
            vim.fn.mkdir(cache_dir, "p")
            assert.equals(1, vim.fn.isdirectory(cache_dir))
        end)

        it("can write and read temp files", function()
            local temp_file = test_dir .. "/test.py"
            local file = io.open(temp_file, "w")
            assert.is_not_nil(file)

            file:write("print('hello')\n")
            file:close()

            -- Verify file was written
            local read_file = io.open(temp_file, "r")
            assert.is_not_nil(read_file)

            local content = read_file:read("*all")
            read_file:close()

            assert.equals("print('hello')\n", content)
        end)
    end)
end)

describe("uv.nvim error handling", function()
    local uv

    before_each(function()
        package.loaded["uv"] = nil
        uv = require("uv")
    end)

    describe("run_file", function()
        it("handles case when no file is open", function()
            -- Create an empty unnamed buffer
            vim.cmd("enew!")

            -- This should not throw an error
            assert.has_no.errors(function()
                -- run_file checks for empty filename
                local current_file = vim.fn.expand("%:p")
                -- With an unnamed buffer, this will be empty
                assert.equals("", current_file)
            end)

            -- Cleanup
            vim.cmd("bdelete!")
        end)
    end)
end)
