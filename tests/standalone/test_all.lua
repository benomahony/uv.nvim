-- Run all standalone tests for uv.nvim
-- Usage: nvim --headless -u tests/minimal_init.lua -c "luafile tests/standalone/test_all.lua"

local t = require("tests.standalone.runner")
local utils = require("uv.utils")

print("=" .. string.rep("=", 60))
print("uv.nvim Comprehensive Test Suite")
print("=" .. string.rep("=", 60))
print("")

-- ============================================================================
-- UTILS TESTS
-- ============================================================================

t.describe("uv.utils", function()
    t.describe("extract_imports", function()
        t.it("extracts simple import statements", function()
            local lines = { "import os", "import sys", "x = 1" }
            local imports = utils.extract_imports(lines)
            t.assert_equals(2, #imports, "Should find 2 imports")
            t.assert_equals("import os", imports[1])
            t.assert_equals("import sys", imports[2])
        end)

        t.it("extracts from...import statements", function()
            local lines = { "from pathlib import Path", "from typing import List, Optional" }
            local imports = utils.extract_imports(lines)
            t.assert_equals(2, #imports)
        end)

        t.it("handles indented imports", function()
            local lines = { "  import os", "    from sys import path" }
            local imports = utils.extract_imports(lines)
            t.assert_equals(2, #imports)
        end)

        t.it("returns empty for no imports", function()
            local lines = { "x = 1", "y = 2" }
            local imports = utils.extract_imports(lines)
            t.assert_equals(0, #imports)
        end)

        t.it("handles empty input", function()
            local imports = utils.extract_imports({})
            t.assert_equals(0, #imports)
        end)
    end)

    t.describe("extract_globals", function()
        t.it("extracts simple global assignments", function()
            local lines = { "CONSTANT = 42", "debug_mode = True" }
            local globals = utils.extract_globals(lines)
            t.assert_equals(2, #globals)
        end)

        t.it("ignores indented assignments", function()
            local lines = { "x = 1", "    y = 2", "        z = 3" }
            local globals = utils.extract_globals(lines)
            t.assert_equals(1, #globals)
            t.assert_equals("x = 1", globals[1])
        end)

        t.it("ignores class variables", function()
            local lines = { "class MyClass:", "    class_var = 'value'", "global_var = 1" }
            local globals = utils.extract_globals(lines)
            t.assert_equals(1, #globals)
            t.assert_equals("global_var = 1", globals[1])
        end)
    end)

    t.describe("extract_functions", function()
        t.it("extracts function names", function()
            local lines = { "def foo():", "    pass", "def bar(x):", "    return x" }
            local functions = utils.extract_functions(lines)
            t.assert_equals(2, #functions)
            t.assert_equals("foo", functions[1])
            t.assert_equals("bar", functions[2])
        end)

        t.it("handles functions with underscores", function()
            local lines = { "def my_function():", "def _private_func():", "def __dunder__():" }
            local functions = utils.extract_functions(lines)
            t.assert_equals(3, #functions)
        end)

        t.it("ignores indented function definitions", function()
            local lines = { "def outer():", "    def inner():", "        pass" }
            local functions = utils.extract_functions(lines)
            t.assert_equals(1, #functions)
            t.assert_equals("outer", functions[1])
        end)
    end)

    t.describe("is_all_indented", function()
        t.it("returns true for fully indented code", function()
            local code = "    x = 1\n    y = 2"
            t.assert_true(utils.is_all_indented(code))
        end)

        t.it("returns false for non-indented code", function()
            local code = "x = 1\ny = 2"
            t.assert_false(utils.is_all_indented(code))
        end)

        t.it("returns false for mixed indentation", function()
            local code = "    x = 1\ny = 2"
            t.assert_false(utils.is_all_indented(code))
        end)

        t.it("returns true for empty string", function()
            t.assert_true(utils.is_all_indented(""))
        end)
    end)

    t.describe("analyze_code", function()
        t.it("detects function definitions", function()
            local analysis = utils.analyze_code("def foo():\n    pass")
            t.assert_true(analysis.is_function_def)
            t.assert_false(analysis.is_class_def)
        end)

        t.it("detects class definitions", function()
            local analysis = utils.analyze_code("class MyClass:\n    pass")
            t.assert_true(analysis.is_class_def)
            t.assert_false(analysis.is_function_def)
        end)

        t.it("detects print statements", function()
            local analysis = utils.analyze_code('print("hello")')
            t.assert_true(analysis.has_print)
        end)

        t.it("detects assignments", function()
            local analysis = utils.analyze_code("x = 1")
            t.assert_true(analysis.has_assignment)
            t.assert_false(analysis.is_expression)
        end)

        t.it("detects simple expressions", function()
            local analysis = utils.analyze_code("2 + 2 * 3")
            t.assert_true(analysis.is_expression)
            t.assert_false(analysis.has_assignment)
        end)

        t.it("detects for loops", function()
            local analysis = utils.analyze_code("for i in range(10):\n    print(i)")
            t.assert_true(analysis.has_for_loop)
        end)

        t.it("detects if statements", function()
            local analysis = utils.analyze_code("if x > 0:\n    print(x)")
            t.assert_true(analysis.has_if_statement)
        end)
    end)

    t.describe("extract_function_name", function()
        t.it("extracts function name from definition", function()
            local name = utils.extract_function_name("def my_function():\n    pass")
            t.assert_equals("my_function", name)
        end)

        t.it("handles functions with arguments", function()
            local name = utils.extract_function_name("def func(x, y, z=1):")
            t.assert_equals("func", name)
        end)

        t.it("returns nil for non-function code", function()
            local name = utils.extract_function_name("x = 1")
            t.assert_nil(name)
        end)
    end)

    t.describe("is_function_called", function()
        t.it("returns true when function is called", function()
            local code = "def foo():\n    pass\nfoo()"
            t.assert_true(utils.is_function_called(code, "foo"))
        end)

        t.it("returns false when function is only defined", function()
            local code = "def foo():\n    pass"
            t.assert_false(utils.is_function_called(code, "foo"))
        end)
    end)

    t.describe("wrap_indented_code", function()
        t.it("wraps indented code in a function", function()
            local wrapped = utils.wrap_indented_code("    x = 1")
            t.assert_contains(wrapped, "def run_selection")
            t.assert_contains(wrapped, "run_selection%(%)") -- escaped pattern
        end)
    end)

    t.describe("generate_expression_print", function()
        t.it("generates print statement for expression", function()
            local result = utils.generate_expression_print("2 + 2")
            t.assert_contains(result, "print")
            t.assert_contains(result, "Expression result")
        end)
    end)

    t.describe("generate_function_call_wrapper", function()
        t.it("generates __main__ wrapper", function()
            local wrapper = utils.generate_function_call_wrapper("my_func")
            t.assert_contains(wrapper, "__main__")
            t.assert_contains(wrapper, "my_func%(%)") -- escaped
        end)
    end)

    t.describe("validate_config", function()
        t.it("accepts valid config", function()
            local config = {
                auto_activate_venv = true,
                execution = { terminal = "split", notification_timeout = 5000 },
            }
            local valid, err = utils.validate_config(config)
            t.assert_true(valid)
            t.assert_nil(err)
        end)

        t.it("rejects non-table config", function()
            local valid, err = utils.validate_config("not a table")
            t.assert_false(valid)
            t.assert_contains(err, "must be a table")
        end)

        t.it("rejects invalid terminal option", function()
            local config = { execution = { terminal = "invalid" } }
            local valid, err = utils.validate_config(config)
            t.assert_false(valid)
            t.assert_contains(err, "Invalid terminal")
        end)

        t.it("accepts keymaps as false", function()
            local config = { keymaps = false }
            local valid, _ = utils.validate_config(config)
            t.assert_true(valid)
        end)
    end)

    t.describe("merge_configs", function()
        t.it("merges simple configs", function()
            local default = { a = 1, b = 2 }
            local override = { b = 3 }
            local result = utils.merge_configs(default, override)
            t.assert_equals(1, result.a)
            t.assert_equals(3, result.b)
        end)

        t.it("deep merges nested configs", function()
            local default = { outer = { a = 1, b = 2 } }
            local override = { outer = { b = 3 } }
            local result = utils.merge_configs(default, override)
            t.assert_equals(1, result.outer.a)
            t.assert_equals(3, result.outer.b)
        end)

        t.it("handles nil override", function()
            local default = { a = 1 }
            local result = utils.merge_configs(default, nil)
            t.assert_equals(1, result.a)
        end)
    end)

    t.describe("extract_selection", function()
        t.it("extracts single line selection", function()
            local lines = { "line 1", "line 2", "line 3" }
            local selection = utils.extract_selection(lines, 2, 1, 2, 6)
            t.assert_equals("line 2", selection)
        end)

        t.it("extracts multi-line selection", function()
            local lines = { "line 1", "line 2", "line 3" }
            local selection = utils.extract_selection(lines, 1, 1, 3, 6)
            t.assert_equals("line 1\nline 2\nline 3", selection)
        end)

        t.it("returns empty for empty input", function()
            local selection = utils.extract_selection({}, 1, 1, 1, 1)
            t.assert_equals("", selection)
        end)
    end)

    t.describe("is_venv_path", function()
        t.it("recognizes .venv path", function()
            t.assert_true(utils.is_venv_path("/project/.venv"))
        end)

        t.it("recognizes venv path", function()
            t.assert_true(utils.is_venv_path("/project/venv"))
        end)

        t.it("rejects non-venv paths", function()
            t.assert_false(utils.is_venv_path("/project/src"))
        end)

        t.it("handles nil input", function()
            t.assert_false(utils.is_venv_path(nil))
        end)

        t.it("handles empty string", function()
            t.assert_false(utils.is_venv_path(""))
        end)
    end)

    t.describe("build_run_command", function()
        t.it("builds simple command", function()
            local cmd = utils.build_run_command("uv run python", "/path/to/file.py")
            t.assert_equals("uv run python '/path/to/file.py'", cmd)
        end)

        t.it("handles spaces in path", function()
            local cmd = utils.build_run_command("python", "/path with spaces/file.py")
            t.assert_contains(cmd, "/path with spaces/file.py")
        end)
    end)
end)

-- ============================================================================
-- CONFIGURATION TESTS
-- ============================================================================

t.describe("uv.nvim configuration", function()
    t.describe("default configuration", function()
        t.it("has auto_activate_venv enabled by default", function()
            package.loaded["uv"] = nil
            local uv = require("uv")
            t.assert_true(uv.config.auto_activate_venv)
        end)

        t.it("has correct default keymap prefix", function()
            package.loaded["uv"] = nil
            local uv = require("uv")
            t.assert_equals("<leader>x", uv.config.keymaps.prefix)
        end)

        t.it("has correct default run_command", function()
            package.loaded["uv"] = nil
            local uv = require("uv")
            t.assert_equals("uv run python", uv.config.execution.run_command)
        end)

        t.it("has correct default terminal option", function()
            package.loaded["uv"] = nil
            local uv = require("uv")
            t.assert_equals("split", uv.config.execution.terminal)
        end)

        t.it("has correct default notification_timeout", function()
            package.loaded["uv"] = nil
            local uv = require("uv")
            t.assert_equals(10000, uv.config.execution.notification_timeout)
        end)
    end)

    t.describe("setup with custom config", function()
        t.it("merges user config with defaults", function()
            package.loaded["uv"] = nil
            local uv = require("uv")
            uv.setup({
                auto_activate_venv = false,
                auto_commands = false,
                keymaps = false,
                picker_integration = false,
            })
            t.assert_false(uv.config.auto_activate_venv)
            t.assert_true(uv.config.notify_activate_venv) -- Other defaults remain
        end)

        t.it("allows disabling keymaps entirely", function()
            package.loaded["uv"] = nil
            local uv = require("uv")
            uv.setup({
                keymaps = false,
                auto_commands = false,
                picker_integration = false,
            })
            t.assert_false(uv.config.keymaps)
        end)

        t.it("allows custom execution config", function()
            package.loaded["uv"] = nil
            local uv = require("uv")
            uv.setup({
                execution = {
                    run_command = "python3",
                    terminal = "vsplit",
                },
                auto_commands = false,
                keymaps = false,
                picker_integration = false,
            })
            t.assert_equals("python3", uv.config.execution.run_command)
            t.assert_equals("vsplit", uv.config.execution.terminal)
        end)

        t.it("handles nil config gracefully", function()
            package.loaded["uv"] = nil
            local uv = require("uv")
            t.assert_no_error(function()
                uv.setup(nil)
            end)
        end)
    end)
end)

-- ============================================================================
-- USER COMMANDS TESTS
-- ============================================================================

t.describe("uv.nvim user commands", function()
    t.it("registers UVInit command", function()
        package.loaded["uv"] = nil
        local uv = require("uv")
        uv.setup({ auto_commands = false, keymaps = false, picker_integration = false })
        local commands = vim.api.nvim_get_commands({})
        t.assert_not_nil(commands.UVInit)
    end)

    t.it("registers UVRunFile command", function()
        package.loaded["uv"] = nil
        local uv = require("uv")
        uv.setup({ auto_commands = false, keymaps = false, picker_integration = false })
        local commands = vim.api.nvim_get_commands({})
        t.assert_not_nil(commands.UVRunFile)
    end)

    t.it("registers UVRunSelection command", function()
        package.loaded["uv"] = nil
        local uv = require("uv")
        uv.setup({ auto_commands = false, keymaps = false, picker_integration = false })
        local commands = vim.api.nvim_get_commands({})
        t.assert_not_nil(commands.UVRunSelection)
    end)

    t.it("registers UVRunFunction command", function()
        package.loaded["uv"] = nil
        local uv = require("uv")
        uv.setup({ auto_commands = false, keymaps = false, picker_integration = false })
        local commands = vim.api.nvim_get_commands({})
        t.assert_not_nil(commands.UVRunFunction)
    end)

    t.it("registers UVAddPackage command", function()
        package.loaded["uv"] = nil
        local uv = require("uv")
        uv.setup({ auto_commands = false, keymaps = false, picker_integration = false })
        local commands = vim.api.nvim_get_commands({})
        t.assert_not_nil(commands.UVAddPackage)
    end)

    t.it("registers UVRemovePackage command", function()
        package.loaded["uv"] = nil
        local uv = require("uv")
        uv.setup({ auto_commands = false, keymaps = false, picker_integration = false })
        local commands = vim.api.nvim_get_commands({})
        t.assert_not_nil(commands.UVRemovePackage)
    end)
end)

-- ============================================================================
-- VIRTUAL ENVIRONMENT TESTS
-- ============================================================================

t.describe("uv.nvim virtual environment", function()
    local original_path = vim.env.PATH
    local original_venv = vim.env.VIRTUAL_ENV
    local original_cwd = vim.fn.getcwd()

    t.describe("activate_venv", function()
        t.it("sets VIRTUAL_ENV environment variable", function()
            local test_venv_path = vim.fn.tempname()
            vim.fn.mkdir(test_venv_path .. "/bin", "p")

            package.loaded["uv"] = nil
            local uv = require("uv")
            uv.config.notify_activate_venv = false
            uv.activate_venv(test_venv_path)

            t.assert_equals(test_venv_path, vim.env.VIRTUAL_ENV)

            -- Cleanup
            vim.env.PATH = original_path
            vim.env.VIRTUAL_ENV = original_venv
            vim.fn.delete(test_venv_path, "rf")
        end)

        t.it("prepends venv bin to PATH", function()
            local test_venv_path = vim.fn.tempname()
            vim.fn.mkdir(test_venv_path .. "/bin", "p")

            package.loaded["uv"] = nil
            local uv = require("uv")
            uv.config.notify_activate_venv = false
            uv.activate_venv(test_venv_path)

            local expected_prefix = test_venv_path .. "/bin:"
            t.assert_contains(vim.env.PATH, expected_prefix)

            -- Cleanup
            vim.env.PATH = original_path
            vim.env.VIRTUAL_ENV = original_venv
            vim.fn.delete(test_venv_path, "rf")
        end)
    end)

    t.describe("auto_activate_venv", function()
        t.it("returns false when no .venv exists", function()
            local temp_dir = vim.fn.tempname()
            vim.fn.mkdir(temp_dir, "p")
            vim.cmd("cd " .. vim.fn.fnameescape(temp_dir))

            package.loaded["uv"] = nil
            local uv = require("uv")
            uv.config.notify_activate_venv = false
            local result = uv.auto_activate_venv()

            t.assert_false(result)

            -- Cleanup
            vim.cmd("cd " .. vim.fn.fnameescape(original_cwd))
            vim.fn.delete(temp_dir, "rf")
        end)

        t.it("returns true when .venv exists", function()
            local temp_dir = vim.fn.tempname()
            vim.fn.mkdir(temp_dir .. "/.venv/bin", "p")
            vim.cmd("cd " .. vim.fn.fnameescape(temp_dir))

            package.loaded["uv"] = nil
            local uv = require("uv")
            uv.config.notify_activate_venv = false
            local result = uv.auto_activate_venv()

            t.assert_true(result)

            -- Cleanup
            vim.env.PATH = original_path
            vim.env.VIRTUAL_ENV = original_venv
            vim.cmd("cd " .. vim.fn.fnameescape(original_cwd))
            vim.fn.delete(temp_dir, "rf")
        end)
    end)
end)

-- ============================================================================
-- INTEGRATION TESTS
-- ============================================================================

t.describe("uv.nvim integration", function()
    t.it("setup can be called without errors", function()
        package.loaded["uv"] = nil
        local uv = require("uv")
        t.assert_no_error(function()
            uv.setup({
                auto_commands = false,
                keymaps = false,
                picker_integration = false,
            })
        end)
    end)

    t.it("exposes run_command globally after setup", function()
        package.loaded["uv"] = nil
        local uv = require("uv")
        _G.run_command = nil
        uv.setup({
            auto_commands = false,
            keymaps = false,
            picker_integration = false,
        })
        t.assert_type("function", _G.run_command)
    end)

    t.it("maintains config across function calls", function()
        package.loaded["uv"] = nil
        local uv = require("uv")
        uv.setup({
            auto_commands = false,
            keymaps = false,
            picker_integration = false,
            execution = {
                run_command = "custom python",
                terminal = "vsplit",
            },
        })

        t.assert_equals("custom python", uv.config.execution.run_command)
        t.assert_equals("vsplit", uv.config.execution.terminal)
    end)
end)

-- ============================================================================
-- BUFFER OPERATIONS TESTS
-- ============================================================================

t.describe("uv.nvim buffer operations", function()
    t.it("extracts imports from buffer content", function()
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

        t.assert_equals(3, #imports)

        -- Cleanup
        vim.api.nvim_buf_delete(buf, { force = true })
    end)

    t.it("extracts functions from buffer content", function()
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "def foo():",
            "    pass",
            "",
            "def bar(x):",
            "    return x * 2",
        })

        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        local functions = utils.extract_functions(lines)

        t.assert_equals(2, #functions)
        t.assert_equals("foo", functions[1])
        t.assert_equals("bar", functions[2])

        -- Cleanup
        vim.api.nvim_buf_delete(buf, { force = true })
    end)
end)

-- ============================================================================
-- FILE OPERATIONS TESTS
-- ============================================================================

t.describe("uv.nvim file operations", function()
    t.it("creates cache directory if needed", function()
        local cache_dir = vim.fn.expand("$HOME") .. "/.cache/nvim/uv_run"
        vim.fn.mkdir(cache_dir, "p")
        t.assert_equals(1, vim.fn.isdirectory(cache_dir))
    end)

    t.it("can write and read temp files", function()
        local temp_dir = vim.fn.tempname()
        vim.fn.mkdir(temp_dir, "p")
        local temp_file = temp_dir .. "/test.py"

        local file = io.open(temp_file, "w")
        t.assert_not_nil(file)

        file:write("print('hello')\n")
        file:close()

        local read_file = io.open(temp_file, "r")
        t.assert_not_nil(read_file)

        local content = read_file:read("*all")
        read_file:close()

        t.assert_equals("print('hello')\n", content)

        -- Cleanup
        vim.fn.delete(temp_dir, "rf")
    end)
end)

-- Print results and exit
local exit_code = t.print_results()
vim.cmd("cq " .. exit_code)
