-- Standalone tests for uv.nvim configuration
-- Run with: nvim --headless -u tests/minimal_init.lua -c "luafile tests/standalone/test_config.lua" -c "qa!"

local t = require("tests.standalone.runner")

t.describe("uv.nvim configuration", function()
    t.describe("default configuration", function()
        t.it("has auto_activate_venv enabled by default", function()
            package.loaded["uv"] = nil
            local uv = require("uv")
            t.assert_true(uv.config.auto_activate_venv)
        end)

        t.it("has notify_activate_venv enabled by default", function()
            package.loaded["uv"] = nil
            local uv = require("uv")
            t.assert_true(uv.config.notify_activate_venv)
        end)

        t.it("has auto_commands enabled by default", function()
            package.loaded["uv"] = nil
            local uv = require("uv")
            t.assert_true(uv.config.auto_commands)
        end)

        t.it("has picker_integration enabled by default", function()
            package.loaded["uv"] = nil
            local uv = require("uv")
            t.assert_true(uv.config.picker_integration)
        end)

        t.it("has keymaps configured by default", function()
            package.loaded["uv"] = nil
            local uv = require("uv")
            t.assert_type("table", uv.config.keymaps)
        end)

        t.it("has correct default keymap prefix", function()
            package.loaded["uv"] = nil
            local uv = require("uv")
            t.assert_equals("<leader>x", uv.config.keymaps.prefix)
        end)

        t.it("has all keymaps enabled by default", function()
            package.loaded["uv"] = nil
            local uv = require("uv")
            local keymaps = uv.config.keymaps
            t.assert_true(keymaps.commands)
            t.assert_true(keymaps.run_file)
            t.assert_true(keymaps.run_selection)
            t.assert_true(keymaps.run_function)
            t.assert_true(keymaps.venv)
            t.assert_true(keymaps.init)
            t.assert_true(keymaps.add)
            t.assert_true(keymaps.remove)
            t.assert_true(keymaps.sync)
            t.assert_true(keymaps.sync_all)
        end)

        t.it("has execution config by default", function()
            package.loaded["uv"] = nil
            local uv = require("uv")
            t.assert_type("table", uv.config.execution)
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

        t.it("has notify_output enabled by default", function()
            package.loaded["uv"] = nil
            local uv = require("uv")
            t.assert_true(uv.config.execution.notify_output)
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
            -- Other defaults should remain
            t.assert_true(uv.config.notify_activate_venv)
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

        t.it("allows partial keymap override", function()
            package.loaded["uv"] = nil
            local uv = require("uv")
            uv.setup({
                keymaps = {
                    prefix = "<leader>u",
                    run_file = false,
                },
                auto_commands = false,
                picker_integration = false,
            })
            t.assert_equals("<leader>u", uv.config.keymaps.prefix)
            t.assert_false(uv.config.keymaps.run_file)
            -- Others should remain true
            t.assert_true(uv.config.keymaps.run_selection)
        end)

        t.it("allows custom execution config", function()
            package.loaded["uv"] = nil
            local uv = require("uv")
            uv.setup({
                execution = {
                    run_command = "python3",
                    terminal = "vsplit",
                    notify_output = false,
                },
                auto_commands = false,
                keymaps = false,
                picker_integration = false,
            })
            t.assert_equals("python3", uv.config.execution.run_command)
            t.assert_equals("vsplit", uv.config.execution.terminal)
            t.assert_false(uv.config.execution.notify_output)
        end)

        t.it("handles empty config gracefully", function()
            package.loaded["uv"] = nil
            local uv = require("uv")
            t.assert_no_error(function()
                uv.setup({})
            end)
            -- Defaults should remain
            t.assert_true(uv.config.auto_activate_venv)
        end)

        t.it("handles nil config gracefully", function()
            package.loaded["uv"] = nil
            local uv = require("uv")
            t.assert_no_error(function()
                uv.setup(nil)
            end)
            -- Defaults should remain
            t.assert_true(uv.config.auto_activate_venv)
        end)
    end)

    t.describe("terminal configuration", function()
        t.it("accepts split terminal option", function()
            package.loaded["uv"] = nil
            local uv = require("uv")
            uv.setup({
                execution = { terminal = "split" },
                auto_commands = false,
                keymaps = false,
                picker_integration = false,
            })
            t.assert_equals("split", uv.config.execution.terminal)
        end)

        t.it("accepts vsplit terminal option", function()
            package.loaded["uv"] = nil
            local uv = require("uv")
            uv.setup({
                execution = { terminal = "vsplit" },
                auto_commands = false,
                keymaps = false,
                picker_integration = false,
            })
            t.assert_equals("vsplit", uv.config.execution.terminal)
        end)

        t.it("accepts tab terminal option", function()
            package.loaded["uv"] = nil
            local uv = require("uv")
            uv.setup({
                execution = { terminal = "tab" },
                auto_commands = false,
                keymaps = false,
                picker_integration = false,
            })
            t.assert_equals("tab", uv.config.execution.terminal)
        end)
    end)
end)

t.describe("uv.nvim user commands", function()
    t.it("registers UVInit command", function()
        package.loaded["uv"] = nil
        local uv = require("uv")
        uv.setup({
            auto_commands = false,
            keymaps = false,
            picker_integration = false,
        })
        local commands = vim.api.nvim_get_commands({})
        t.assert_not_nil(commands.UVInit)
    end)

    t.it("registers UVRunFile command", function()
        package.loaded["uv"] = nil
        local uv = require("uv")
        uv.setup({
            auto_commands = false,
            keymaps = false,
            picker_integration = false,
        })
        local commands = vim.api.nvim_get_commands({})
        t.assert_not_nil(commands.UVRunFile)
    end)

    t.it("registers UVRunSelection command", function()
        package.loaded["uv"] = nil
        local uv = require("uv")
        uv.setup({
            auto_commands = false,
            keymaps = false,
            picker_integration = false,
        })
        local commands = vim.api.nvim_get_commands({})
        t.assert_not_nil(commands.UVRunSelection)
    end)

    t.it("registers UVRunFunction command", function()
        package.loaded["uv"] = nil
        local uv = require("uv")
        uv.setup({
            auto_commands = false,
            keymaps = false,
            picker_integration = false,
        })
        local commands = vim.api.nvim_get_commands({})
        t.assert_not_nil(commands.UVRunFunction)
    end)

    t.it("registers UVAddPackage command", function()
        package.loaded["uv"] = nil
        local uv = require("uv")
        uv.setup({
            auto_commands = false,
            keymaps = false,
            picker_integration = false,
        })
        local commands = vim.api.nvim_get_commands({})
        t.assert_not_nil(commands.UVAddPackage)
    end)

    t.it("registers UVRemovePackage command", function()
        package.loaded["uv"] = nil
        local uv = require("uv")
        uv.setup({
            auto_commands = false,
            keymaps = false,
            picker_integration = false,
        })
        local commands = vim.api.nvim_get_commands({})
        t.assert_not_nil(commands.UVRemovePackage)
    end)
end)

t.describe("uv.nvim global exposure", function()
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
end)

-- Print results and exit
local exit_code = t.print_results()
vim.cmd("cq " .. exit_code)
