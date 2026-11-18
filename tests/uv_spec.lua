local uv = require("uv")

local original_path = vim.env.PATH
local original_venv = vim.env.VIRTUAL_ENV
local original_cwd = vim.fn.getcwd()

local function reset_env()
	vim.env.PATH = original_path
	vim.env.VIRTUAL_ENV = original_venv
	vim.cmd("cd " .. vim.fn.fnameescape(original_cwd))
end

local function fresh_uv()
	package.loaded["uv"] = nil
	return require("uv")
end

describe("uv.nvim", function()
	after_each(function()
		reset_env()
	end)

	describe("configuration", function()
		it("has correct defaults", function()
			local m = fresh_uv()
			assert.is_true(m.config.auto_activate_venv)
			assert.are.equal("<leader>x", m.config.keymaps.prefix)
			assert.are.equal("uv run python", m.config.execution.run_command)
			assert.are.equal("split", m.config.execution.terminal)
		end)

		it("merges custom config", function()
			local m = fresh_uv()
			m.setup({ auto_activate_venv = false, auto_commands = false, keymaps = false, picker_integration = false })
			assert.is_false(m.config.auto_activate_venv)
			assert.is_true(m.config.notify_activate_venv)
		end)

		it("accepts custom execution config", function()
			local m = fresh_uv()
			m.setup({
				execution = { run_command = "python3", terminal = "vsplit" },
				auto_commands = false,
				keymaps = false,
				picker_integration = false,
			})
			assert.are.equal("python3", m.config.execution.run_command)
			assert.are.equal("vsplit", m.config.execution.terminal)
		end)
	end)

	describe("commands", function()
		it("registers user commands", function()
			local m = fresh_uv()
			m.setup({ auto_commands = false, keymaps = false, picker_integration = false })
			local cmds = vim.api.nvim_get_commands({})
			assert.is_not_nil(cmds.UVInit)
			assert.is_not_nil(cmds.UVRunFile)
			assert.is_not_nil(cmds.UVRunSelection)
			assert.is_not_nil(cmds.UVRunFunction)
		end)

		it("shell escapes UVAddPackage and UVRemovePackage arguments", function()
			local m = fresh_uv()
			m.setup({ auto_commands = false, keymaps = false, picker_integration = false })
			local ran = {}
			m.run_command = function(cmd)
				table.insert(ran, cmd)
			end
			vim.cmd("UVAddPackage pytest --dev")
			vim.cmd("UVRemovePackage requests")
			assert.are.same({ "uv add 'pytest' '--dev'", "uv remove 'requests'" }, ran)
		end)
	end)

	describe("add_package", function()
		local original_input = vim.ui.input

		after_each(function()
			vim.ui.input = original_input
		end)

		it("shell escapes the package name typed in", function()
			local m = fresh_uv()
			local ran = nil
			m.run_command = function(cmd)
				ran = cmd
			end
			vim.ui.input = function(_, on_confirm)
				on_confirm("requests; rm -rf ~")
			end
			m.add_package()
			assert.are.equal("uv add 'requests;' 'rm' '-rf' '~'", ran)
		end)
	end)

	describe("run_command", function()
		local original_notify = vim.notify

		after_each(function()
			vim.notify = original_notify
		end)

		it("reports the exit code of a failed command", function()
			local messages = {}
			vim.notify = function(msg)
				table.insert(messages, msg)
			end
			fresh_uv().run_command("exit 3")
			assert.is_true(vim.wait(5000, function()
				return #messages > 0
			end))
			assert.are.equal("Command failed with exit code 3: exit 3", messages[#messages])
		end)
	end)

	describe("activate_venv", function()
		it("sets VIRTUAL_ENV", function()
			local m = fresh_uv()
			m.config.notify_activate_venv = false
			local test_path = vim.fn.tempname()
			vim.fn.mkdir(test_path .. "/bin", "p")

			m.activate_venv(test_path)
			assert.are.equal(test_path, vim.env.VIRTUAL_ENV)

			vim.fn.delete(test_path, "rf")
		end)

		it("prepends to PATH", function()
			local m = fresh_uv()
			m.config.notify_activate_venv = false
			local test_path = vim.fn.tempname()
			vim.fn.mkdir(test_path .. "/bin", "p")

			m.activate_venv(test_path)
			assert.are.equal(1, vim.env.PATH:find(test_path .. "/bin", 1, true))

			vim.fn.delete(test_path, "rf")
		end)
	end)

	describe("auto_activate_venv", function()
		it("returns false when no .venv exists", function()
			local m = fresh_uv()
			m.config.notify_activate_venv = false
			local temp_dir = vim.fn.tempname()
			vim.fn.mkdir(temp_dir, "p")
			vim.cmd("cd " .. vim.fn.fnameescape(temp_dir))

			assert.is_false(m.auto_activate_venv())

			vim.fn.delete(temp_dir, "rf")
		end)

		it("returns true when .venv exists", function()
			local m = fresh_uv()
			m.config.notify_activate_venv = false
			local temp_dir = vim.fn.tempname()
			vim.fn.mkdir(temp_dir .. "/.venv/bin", "p")
			vim.cmd("cd " .. vim.fn.fnameescape(temp_dir))

			assert.is_true(m.auto_activate_venv())

			vim.fn.delete(temp_dir, "rf")
		end)
	end)

	describe("setup", function()
		it("exposes run_command globally", function()
			local m = fresh_uv()
			_G.run_command = nil
			m.setup({ auto_commands = false, keymaps = false, picker_integration = false })
			assert.are.equal("function", type(_G.run_command))
		end)
	end)

	describe("picker_integration", function()
		local original_select = vim.ui.select
		local original_input = vim.ui.input
		local original_notify = vim.notify
		local telescope_modules = {
			"telescope",
			"telescope.pickers",
			"telescope.finders",
			"telescope.sorters",
			"telescope.actions",
			"telescope.actions.state",
		}
		local sources, ran, telescope_spec, telescope_selected

		local function commands_keymap(picker_integration, with_snacks)
			sources = {}
			if with_snacks ~= false then
				_G.Snacks = { picker = { sources = sources, preview = {} } }
			end
			local m = fresh_uv()
			m.setup({ auto_commands = false, picker_integration = picker_integration })
			m.run_command = function(cmd)
				ran = cmd
			end
			return vim.fn.maparg("<leader>x", "n")
		end

		local function choose(index)
			vim.ui.select = function(items, _, on_choice)
				on_choice(items[index])
			end
		end

		local function stub_telescope()
			package.loaded["telescope"] = {}
			package.loaded["telescope.pickers"] = {
				new = function(_, spec)
					return {
						find = function()
							telescope_spec = spec
						end,
					}
				end,
			}
			package.loaded["telescope.finders"] = {
				new_table = function(finder)
					return finder
				end,
			}
			package.loaded["telescope.sorters"] = { get_generic_fuzzy_sorter = function() end }
			package.loaded["telescope.actions"] = { close = function() end }
			package.loaded["telescope.actions.state"] = {
				get_selected_entry = function()
					return telescope_selected
				end,
			}
		end

		local function confirm_in_telescope(index)
			telescope_selected = telescope_spec.finder.entry_maker(telescope_spec.finder.results[index])
			local on_select
			telescope_spec.attach_mappings(1, function(_, _, fn)
				on_select = fn
			end)
			on_select()
			return telescope_selected.display
		end

		local function in_empty_dir()
			local dir = vim.fn.tempname()
			vim.fn.mkdir(dir, "p")
			vim.cmd("cd " .. vim.fn.fnameescape(dir))
			return dir
		end

		after_each(function()
			_G.Snacks = nil
			vim.ui.select = original_select
			vim.ui.input = original_input
			vim.notify = original_notify
			package.loaded["fzf-lua"] = nil
			for _, name in ipairs(telescope_modules) do
				package.loaded[name] = nil
			end
			ran, telescope_spec, telescope_selected = nil, nil, nil
			pcall(vim.keymap.del, "n", "<leader>x")
		end)

		it("registers both and maps telescope when auto detecting telescope and snacks", function()
			stub_telescope()
			assert.matches("pick_uv_commands", commands_keymap(true), nil, true)
			assert.is_not_nil(sources.uv_commands)
		end)

		it("auto detects fzf-lua when it is the only picker", function()
			package.loaded["fzf-lua"] = { fzf_exec = function() end }
			assert.matches("pick_uv_commands", commands_keymap(true, false), nil, true)
		end)

		it("runs the command chosen in telescope", function()
			stub_telescope()
			commands_keymap("telescope")
			require("uv").pick_uv_commands()
			assert.are.equal("uv sync", confirm_in_telescope(5))
			assert.are.equal("uv sync", ran)
		end)

		it("offers to create a venv in telescope when there is none", function()
			in_empty_dir()
			stub_telescope()
			commands_keymap("telescope")
			require("uv").pick_uv_venv()
			assert.are.equal("+ Create new virtual environment (uv venv)", confirm_in_telescope(1))
			assert.are.equal("uv venv", ran)
		end)

		it("offers to create a venv in snacks when there is none", function()
			in_empty_dir()
			commands_keymap(true)
			local item = sources.uv_venv.finder()[1]
			assert.are.equal("+ Create new virtual environment (uv venv)", sources.uv_venv.format(item)[1][1])
			sources.uv_venv.confirm({ close = function() end }, item)
			assert.are.equal("uv venv", ran)
		end)

		it("activates the existing venv chosen through vim.ui.select", function()
			local dir = in_empty_dir()
			vim.fn.mkdir(dir .. "/.venv/bin", "p")
			local label
			vim.ui.select = function(items, opts, on_choice)
				label = opts.format_item(items[1])
				on_choice(items[1])
			end
			commands_keymap("select")
			local m = require("uv")
			m.config.notify_activate_venv = false
			m.pick_uv_venv()
			assert.are.equal("○ .venv (Activate)", label)
			assert.are.equal(vim.fn.getcwd() .. "/.venv", vim.env.VIRTUAL_ENV)
		end)

		it("asks for a selection then runs it when Run selection is picked in normal mode", function()
			local messages, ran_selection = {}, false
			vim.notify = function(msg)
				table.insert(messages, msg)
			end
			choose(2)
			commands_keymap("select")
			local m = require("uv")
			m.run_python_selection = function()
				ran_selection = true
			end
			m.pick_uv_commands()
			assert.matches("Please select text first", messages[1], nil, true)
			assert.is_false(ran_selection)
			vim.api.nvim_feedkeys("V\27", "x", false)
			assert.is_true(ran_selection)
		end)

		it("previews uv help in snacks and clears the preview for other items", function()
			commands_keymap(true)
			local previewed, cleared
			_G.Snacks.picker.preview.cmd = function(cmd)
				previewed = cmd
			end
			sources.uv_commands.preview({ item = { text = "uv add [package]" } })
			sources.uv_commands.preview({
				item = { text = "Run current file" },
				preview = {
					set_lines = function(_, lines)
						cleared = lines
					end,
				},
			})
			assert.are.equal("uv add --help", previewed)
			assert.are.same({}, cleared)
		end)

		it("auto detects snacks and registers its sources", function()
			assert.matches("Snacks.picker.pick", commands_keymap(true), nil, true)
			assert.is_not_nil(sources.uv_commands)
		end)

		it("runs the command confirmed in the snacks picker", function()
			commands_keymap(true)
			sources.uv_commands.confirm({ close = function() end }, sources.uv_commands.finder()[5])
			assert.are.equal("uv sync", ran)
		end)

		it("uses only telescope when configured even if snacks is available", function()
			assert.matches("pick_uv_commands", commands_keymap("telescope"), nil, true)
			assert.is_nil(sources.uv_commands)
		end)

		it("lists commands and runs the one chosen through vim.ui.select", function()
			local labels = {}
			vim.ui.select = function(items, opts, on_choice)
				for _, item in ipairs(items) do
					table.insert(labels, opts.format_item(item))
				end
				on_choice(items[5])
			end
			assert.matches("pick_uv_commands", commands_keymap("select"), nil, true)
			require("uv").pick_uv_commands()
			assert.are.equal("Run current file", labels[1])
			assert.are.equal("uv sync", ran)
		end)

		it("runs the command chosen through fzf-lua", function()
			package.loaded["fzf-lua"] = {
				fzf_exec = function(_, opts)
					opts.actions.default({ "uv init" })
				end,
			}
			assert.matches("pick_uv_commands", commands_keymap("fzf-lua"), nil, true)
			require("uv").pick_uv_commands()
			assert.are.equal("uv init", ran)
		end)

		it("shell escapes the package typed into the picker", function()
			choose(4)
			vim.ui.input = function(_, on_confirm)
				on_confirm("requests; rm -rf ~")
			end
			commands_keymap("select")
			require("uv").pick_uv_commands()
			assert.are.equal("uv add 'requests;' 'rm' '-rf' '~'", ran)
		end)

		it("sets no picker keymap when disabled", function()
			assert.are.equal("", commands_keymap(false))
		end)
	end)

	describe("run_python_selection", function()
		local cache_file = vim.fn.expand("$HOME") .. "/.cache/nvim/uv_run/run_selection.py"

		local function run_selection_on(line)
			vim.api.nvim_feedkeys(line .. "GV\\t", "x", false)
			vim.cmd("close")
			return table.concat(vim.fn.readfile(cache_file), "\n")
		end

		before_each(function()
			local m = fresh_uv()
			m.config.execution.run_command = "true"
			vim.keymap.set("v", "\\t", m.run_python_selection)
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"def get_name() -> str:",
				'    return "Andreas"',
				"",
				"",
				"def print_hello():",
				'    print(f"Hello, {get_name()}")',
				"",
				"BOOM = 1 / 0",
			})
		end)

		after_each(function()
			vim.keymap.del("v", "\\t")
		end)

		it("uses the current selection when called from visual mode", function()
			assert.matches('def run_selection():\n        return "Andreas"', run_selection_on(2), nil, true)
			assert.matches('def run_selection():\n        print(f"Hello', run_selection_on(6), nil, true)
		end)

		it("runs with only the definitions it references", function()
			run_selection_on(6)
			assert.are.equal("Hello, Andreas\n", vim.fn.system({ "python3", cache_file }))
		end)

		it("warns and still runs the selection when the buffer has a syntax error", function()
			vim.api.nvim_buf_set_lines(0, 0, -1, false, { "def broken(:", 'print("ran")' })
			run_selection_on(2)
			local output = vim.fn.system({ "python3", cache_file })
			assert.matches("syntax error on line 1", output, nil, true)
			assert.matches("ran\n", output, nil, true)
		end)
	end)
end)
