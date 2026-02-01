-- Tests for uv.utils module - Pure function tests
local utils = require("uv.utils")

describe("uv.utils", function()
    describe("extract_imports", function()
        it("extracts simple import statements", function()
            local lines = {
                "import os",
                "import sys",
                "x = 1",
            }
            local imports = utils.extract_imports(lines)
            assert.equals(2, #imports)
            assert.equals("import os", imports[1])
            assert.equals("import sys", imports[2])
        end)

        it("extracts from...import statements", function()
            local lines = {
                "from pathlib import Path",
                "from typing import List, Optional",
                "x = 1",
            }
            local imports = utils.extract_imports(lines)
            assert.equals(2, #imports)
            assert.equals("from pathlib import Path", imports[1])
            assert.equals("from typing import List, Optional", imports[2])
        end)

        it("handles indented imports", function()
            local lines = {
                "  import os",
                "    from sys import path",
            }
            local imports = utils.extract_imports(lines)
            assert.equals(2, #imports)
        end)

        it("returns empty table for no imports", function()
            local lines = {
                "x = 1",
                "y = 2",
            }
            local imports = utils.extract_imports(lines)
            assert.equals(0, #imports)
        end)

        it("handles empty input", function()
            local imports = utils.extract_imports({})
            assert.equals(0, #imports)
        end)

        it("ignores comments that look like imports", function()
            local lines = {
                "# import os",
                "import sys",
            }
            local imports = utils.extract_imports(lines)
            -- Note: Current implementation doesn't filter comments
            -- This test documents actual behavior
            assert.equals(1, #imports)
            assert.equals("import sys", imports[1])
        end)
    end)

    describe("extract_globals", function()
        it("extracts simple global assignments", function()
            local lines = {
                "CONSTANT = 42",
                "debug_mode = True",
            }
            local globals = utils.extract_globals(lines)
            assert.equals(2, #globals)
            assert.equals("CONSTANT = 42", globals[1])
            assert.equals("debug_mode = True", globals[2])
        end)

        it("ignores indented assignments", function()
            local lines = {
                "x = 1",
                "    y = 2",
                "        z = 3",
            }
            local globals = utils.extract_globals(lines)
            assert.equals(1, #globals)
            assert.equals("x = 1", globals[1])
        end)

        it("ignores function definitions", function()
            local lines = {
                "def foo():",
                "    pass",
                "x = 1",
            }
            local globals = utils.extract_globals(lines)
            assert.equals(1, #globals)
            assert.equals("x = 1", globals[1])
        end)

        it("ignores class variables", function()
            local lines = {
                "class MyClass:",
                "    class_var = 'value'",
                "    def method(self):",
                "        pass",
                "global_var = 1",
            }
            local globals = utils.extract_globals(lines)
            assert.equals(1, #globals)
            assert.equals("global_var = 1", globals[1])
        end)

        it("handles class followed by global", function()
            local lines = {
                "class A:",
                "    x = 1",
                "y = 2",
            }
            local globals = utils.extract_globals(lines)
            assert.equals(1, #globals)
            assert.equals("y = 2", globals[1])
        end)

        it("handles empty input", function()
            local globals = utils.extract_globals({})
            assert.equals(0, #globals)
        end)
    end)

    describe("extract_functions", function()
        it("extracts function names", function()
            local lines = {
                "def foo():",
                "    pass",
                "def bar(x):",
                "    return x",
            }
            local functions = utils.extract_functions(lines)
            assert.equals(2, #functions)
            assert.equals("foo", functions[1])
            assert.equals("bar", functions[2])
        end)

        it("handles functions with underscores", function()
            local lines = {
                "def my_function():",
                "def _private_func():",
                "def __dunder__():",
            }
            local functions = utils.extract_functions(lines)
            assert.equals(3, #functions)
            assert.equals("my_function", functions[1])
            assert.equals("_private_func", functions[2])
            assert.equals("__dunder__", functions[3])
        end)

        it("ignores indented function definitions (methods)", function()
            local lines = {
                "def outer():",
                "    def inner():",
                "        pass",
            }
            local functions = utils.extract_functions(lines)
            assert.equals(1, #functions)
            assert.equals("outer", functions[1])
        end)

        it("returns empty for no functions", function()
            local lines = {
                "x = 1",
                "class A: pass",
            }
            local functions = utils.extract_functions(lines)
            assert.equals(0, #functions)
        end)
    end)

    describe("is_all_indented", function()
        it("returns true for fully indented code", function()
            local code = "    x = 1\n    y = 2\n    print(x + y)"
            assert.is_true(utils.is_all_indented(code))
        end)

        it("returns false for non-indented code", function()
            local code = "x = 1\ny = 2"
            assert.is_false(utils.is_all_indented(code))
        end)

        it("returns false for mixed indentation", function()
            local code = "    x = 1\ny = 2"
            assert.is_false(utils.is_all_indented(code))
        end)

        it("returns true for empty string", function()
            assert.is_true(utils.is_all_indented(""))
        end)

        it("handles tabs as indentation", function()
            local code = "\tx = 1\n\ty = 2"
            assert.is_true(utils.is_all_indented(code))
        end)
    end)

    describe("analyze_code", function()
        it("detects function definitions", function()
            local code = "def foo():\n    pass"
            local analysis = utils.analyze_code(code)
            assert.is_true(analysis.is_function_def)
            assert.is_false(analysis.is_class_def)
            assert.is_false(analysis.is_expression)
        end)

        it("detects class definitions", function()
            local code = "class MyClass:\n    pass"
            local analysis = utils.analyze_code(code)
            assert.is_true(analysis.is_class_def)
            assert.is_false(analysis.is_function_def)
        end)

        it("detects print statements", function()
            local code = 'print("hello")'
            local analysis = utils.analyze_code(code)
            assert.is_true(analysis.has_print)
        end)

        it("detects assignments", function()
            local code = "x = 1"
            local analysis = utils.analyze_code(code)
            assert.is_true(analysis.has_assignment)
            assert.is_false(analysis.is_expression)
        end)

        it("detects for loops", function()
            local code = "for i in range(10):\n    print(i)"
            local analysis = utils.analyze_code(code)
            assert.is_true(analysis.has_for_loop)
        end)

        it("detects if statements", function()
            local code = "if x > 0:\n    print(x)"
            local analysis = utils.analyze_code(code)
            assert.is_true(analysis.has_if_statement)
        end)

        it("detects simple expressions", function()
            local code = "2 + 2 * 3"
            local analysis = utils.analyze_code(code)
            assert.is_true(analysis.is_expression)
            assert.is_false(analysis.has_assignment)
            assert.is_false(analysis.is_function_def)
        end)

        it("detects comment-only code", function()
            local code = "# just a comment"
            local analysis = utils.analyze_code(code)
            assert.is_true(analysis.is_comment_only)
        end)

        it("detects indented code", function()
            local code = "    x = 1\n    y = 2"
            local analysis = utils.analyze_code(code)
            assert.is_true(analysis.is_all_indented)
        end)
    end)

    describe("extract_function_name", function()
        it("extracts function name from definition", function()
            local code = "def my_function():\n    pass"
            local name = utils.extract_function_name(code)
            assert.equals("my_function", name)
        end)

        it("handles functions with arguments", function()
            local code = "def func_with_args(x, y, z=1):"
            local name = utils.extract_function_name(code)
            assert.equals("func_with_args", name)
        end)

        it("returns nil for non-function code", function()
            local code = "x = 1"
            local name = utils.extract_function_name(code)
            assert.is_nil(name)
        end)

        it("handles async functions", function()
            -- Note: async def won't match current pattern
            local code = "async def async_func():"
            local name = utils.extract_function_name(code)
            -- Current implementation doesn't handle async
            assert.is_nil(name)
        end)
    end)

    describe("is_function_called", function()
        it("returns true when function is called", function()
            local code = "def foo():\n    pass\nfoo()"
            assert.is_true(utils.is_function_called(code, "foo"))
        end)

        it("returns false when function is only defined", function()
            local code = "def foo():\n    pass"
            assert.is_false(utils.is_function_called(code, "foo"))
        end)

        it("handles multiple calls", function()
            local code = "def foo():\n    pass\nfoo()\nfoo()"
            assert.is_true(utils.is_function_called(code, "foo"))
        end)

        it("handles function not present", function()
            local code = "x = 1"
            assert.is_false(utils.is_function_called(code, "foo"))
        end)
    end)

    describe("wrap_indented_code", function()
        it("wraps indented code in a function", function()
            local code = "    x = 1\n    y = 2"
            local wrapped = utils.wrap_indented_code(code)
            assert.truthy(wrapped:match("def run_selection"))
            assert.truthy(wrapped:match("run_selection%(%)"))
        end)

        it("adds extra indentation", function()
            local code = "    x = 1"
            local wrapped = utils.wrap_indented_code(code)
            -- Should have double indentation now (original + wrapper)
            assert.truthy(wrapped:match("        x = 1"))
        end)
    end)

    describe("generate_expression_print", function()
        it("generates print statement for expression", function()
            local expr = "2 + 2"
            local result = utils.generate_expression_print(expr)
            assert.truthy(result:match("print"))
            assert.truthy(result:match("Expression result"))
            assert.truthy(result:match("2 %+ 2"))
        end)

        it("trims whitespace from expression", function()
            local expr = "  x + y  "
            local result = utils.generate_expression_print(expr)
            assert.truthy(result:match("{x %+ y}"))
        end)
    end)

    describe("generate_function_call_wrapper", function()
        it("generates __main__ wrapper", function()
            local wrapper = utils.generate_function_call_wrapper("my_func")
            assert.truthy(wrapper:match('__name__ == "__main__"'))
            assert.truthy(wrapper:match("my_func%(%)"))
            assert.truthy(wrapper:match("result ="))
        end)

        it("includes return value printing", function()
            local wrapper = utils.generate_function_call_wrapper("test")
            assert.truthy(wrapper:match("Return value"))
        end)
    end)

    describe("validate_config", function()
        it("accepts valid config", function()
            local config = {
                auto_activate_venv = true,
                execution = {
                    terminal = "split",
                    notification_timeout = 5000,
                },
            }
            local valid, err = utils.validate_config(config)
            assert.is_true(valid)
            assert.is_nil(err)
        end)

        it("rejects non-table config", function()
            local valid, err = utils.validate_config("not a table")
            assert.is_false(valid)
            assert.truthy(err:match("must be a table"))
        end)

        it("rejects invalid terminal option", function()
            local config = {
                execution = {
                    terminal = "invalid",
                },
            }
            local valid, err = utils.validate_config(config)
            assert.is_false(valid)
            assert.truthy(err:match("Invalid terminal"))
        end)

        it("rejects non-number notification_timeout", function()
            local config = {
                execution = {
                    notification_timeout = "not a number",
                },
            }
            local valid, err = utils.validate_config(config)
            assert.is_false(valid)
            assert.truthy(err:match("notification_timeout must be a number"))
        end)

        it("accepts keymaps as false", function()
            local config = {
                keymaps = false,
            }
            local valid, err = utils.validate_config(config)
            assert.is_true(valid)
            assert.is_nil(err)
        end)

        it("rejects keymaps as non-table non-false", function()
            local config = {
                keymaps = "invalid",
            }
            local valid, err = utils.validate_config(config)
            assert.is_false(valid)
            assert.truthy(err:match("keymaps must be a table or false"))
        end)
    end)

    describe("merge_configs", function()
        it("merges simple configs", function()
            local default = { a = 1, b = 2 }
            local override = { b = 3 }
            local result = utils.merge_configs(default, override)
            assert.equals(1, result.a)
            assert.equals(3, result.b)
        end)

        it("deep merges nested configs", function()
            local default = {
                outer = {
                    a = 1,
                    b = 2,
                },
            }
            local override = {
                outer = {
                    b = 3,
                },
            }
            local result = utils.merge_configs(default, override)
            assert.equals(1, result.outer.a)
            assert.equals(3, result.outer.b)
        end)

        it("handles nil override", function()
            local default = { a = 1 }
            local result = utils.merge_configs(default, nil)
            assert.equals(1, result.a)
        end)

        it("adds new keys from override", function()
            local default = { a = 1 }
            local override = { b = 2 }
            local result = utils.merge_configs(default, override)
            assert.equals(1, result.a)
            assert.equals(2, result.b)
        end)

        it("allows false to override true", function()
            local default = { enabled = true }
            local override = { enabled = false }
            local result = utils.merge_configs(default, override)
            assert.is_false(result.enabled)
        end)
    end)

    describe("extract_selection", function()
        it("extracts single line selection", function()
            local lines = { "line 1", "line 2", "line 3" }
            local selection = utils.extract_selection(lines, 2, 1, 2, 6)
            assert.equals("line 2", selection)
        end)

        it("extracts multi-line selection", function()
            local lines = { "line 1", "line 2", "line 3" }
            local selection = utils.extract_selection(lines, 1, 1, 3, 6)
            assert.equals("line 1\nline 2\nline 3", selection)
        end)

        it("handles column positions", function()
            local lines = { "hello world" }
            local selection = utils.extract_selection(lines, 1, 7, 1, 11)
            assert.equals("world", selection)
        end)

        it("returns empty for empty input", function()
            local selection = utils.extract_selection({}, 1, 1, 1, 1)
            assert.equals("", selection)
        end)

        it("handles partial line selection", function()
            local lines = { "first line", "second line", "third line" }
            local selection = utils.extract_selection(lines, 1, 7, 2, 6)
            assert.equals("line\nsecond", selection)
        end)
    end)

    describe("is_venv_path", function()
        it("recognizes .venv path", function()
            assert.is_true(utils.is_venv_path("/project/.venv"))
        end)

        it("recognizes venv path", function()
            assert.is_true(utils.is_venv_path("/project/venv"))
        end)

        it("recognizes .venv in path", function()
            assert.is_true(utils.is_venv_path("/project/.venv/bin/python"))
        end)

        it("rejects non-venv paths", function()
            assert.is_false(utils.is_venv_path("/project/src"))
        end)

        it("handles nil input", function()
            assert.is_false(utils.is_venv_path(nil))
        end)

        it("handles empty string", function()
            assert.is_false(utils.is_venv_path(""))
        end)
    end)

    describe("build_run_command", function()
        it("builds simple command", function()
            local cmd = utils.build_run_command("uv run python", "/path/to/file.py")
            assert.equals("uv run python '/path/to/file.py'", cmd)
        end)

        it("escapes single quotes in path", function()
            local cmd = utils.build_run_command("python", "/path/with'quote/file.py")
            assert.truthy(cmd:match("'\\''"))
        end)

        it("handles spaces in path", function()
            local cmd = utils.build_run_command("python", "/path with spaces/file.py")
            assert.truthy(cmd:match("'/path with spaces/file.py'"))
        end)
    end)
end)
