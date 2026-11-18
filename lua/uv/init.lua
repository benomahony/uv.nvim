-- uv.nvim - Neovim plugin for uv Python package management integration
-- Author: Ben O'Mahony
-- License: MIT

---@class UVExecutionConfig
---@field run_command string
---@field notify_output boolean
---@field notification_timeout integer
---@field terminal '"split"'|'"vsplit"'|'"tab"'|string

---@class UVKeymapsConfig
---@field prefix string
---@field commands boolean
---@field run_file boolean
---@field run_selection boolean
---@field run_function boolean
---@field venv boolean
---@field init boolean
---@field add boolean
---@field remove boolean
---@field sync boolean
---@field sync_all boolean

---@class UVConfig
---@field auto_activate_venv boolean
---@field notify_activate_venv boolean
---@field auto_commands boolean
---@field picker_integration boolean|"snacks"|"telescope"|"fzf-lua"|"select"
---@field keymaps UVKeymapsConfig|false
---@field execution UVExecutionConfig

---@class UVModule
---@field config UVConfig
local M = {}

-- Default configuration
---@type UVConfig
M.config = {
	-- Auto-activate virtual environments when found
	auto_activate_venv = true,
	notify_activate_venv = true,

	-- Auto commands for directory changes
	auto_commands = true,

	-- Integration with picker: true (auto detect), false, "snacks", "telescope", "fzf-lua" or "select" (vim.ui.select)
	picker_integration = true,

	-- Keymaps to register (set to false to disable)
	keymaps = {
		prefix = "<leader>x", -- Main prefix for UV commands
		commands = true, -- Show UV commands menu (<leader>x)
		run_file = true, -- Run current file (<leader>xr)
		run_selection = true, -- Run selection (<leader>xs)
		run_function = true, -- Run function (<leader>xf)
		venv = true, -- Environment management (<leader>xe)
		init = true, -- Initialize UV project (<leader>xi)
		add = true, -- Add a package (<leader>xa)
		remove = true, -- Remove a package (<leader>xd)
		sync = true, -- Sync packages (<leader>xc)
		sync_all = true, -- uv sync --all-extras --all-groups --all-packages (<leader>xC)
	},

	-- Execution options
	execution = {
		-- Python run command template
		run_command = "uv run python",

		-- Where to open the terminal: "split" | "vsplit" | "tab"
		terminal = "split",

		-- Show output in notifications (used by M.run_command)
		notify_output = true,

		-- Notification timeout in ms
		notification_timeout = 10000,
	},
}

-- Command runner - runs shell commands and captures output
---@param cmd string
function M.run_command(cmd)
	vim.fn.jobstart(cmd, {
		on_exit = function(_, exit_code)
			if not M.config.execution.notify_output then
				return
			end
			if exit_code == 0 then
				vim.notify("Command completed successfully: " .. cmd, vim.log.levels.INFO)
			else
				vim.notify("Command failed with exit code " .. exit_code .. ": " .. cmd, vim.log.levels.ERROR)
			end
		end,
		on_stdout = function(_, data)
			if not M.config.execution.notify_output then
				return
			end
			if data and #data > 1 then
				local output = table.concat(data, "\n")
				if output and output:match("%S") then
					vim.notify(output, vim.log.levels.INFO)
				end
			end
		end,
		on_stderr = function(_, data)
			if not M.config.execution.notify_output then
				return
			end
			if data and #data > 1 then
				local output = table.concat(data, "\n")
				if output and output:match("%S") then
					vim.notify(output, vim.log.levels.WARN)
				end
			end
		end,
		stdout_buffered = true,
		stderr_buffered = true,
	})
end

-- Check if auto-activate is enabled (checks buffer-local, then global, then config)
-- This allows granular per-directory/buffer control similar to LazyVim's autoformat
---@return boolean
function M.is_auto_activate_enabled()
	-- Buffer-local variable takes precedence if set
	local buf_value = vim.b.uv_auto_activate_venv
	if buf_value ~= nil then
		return buf_value
	end

	-- Global vim variable takes precedence over config
	local global_value = vim.g.uv_auto_activate_venv
	if global_value ~= nil then
		return global_value
	end

	-- Fall back to config value
	return M.config.auto_activate_venv
end

-- Toggle auto-activate venv setting
---@param buffer_local? boolean If true, toggles buffer-local variable instead of global
function M.toggle_auto_activate_venv(buffer_local)
	local current = M.is_auto_activate_enabled()
	local new_value = not current

	if buffer_local then
		vim.b.uv_auto_activate_venv = new_value
	else
		vim.g.uv_auto_activate_venv = new_value
	end

	if M.config.notify_activate_venv then
		local scope = buffer_local and "buffer" or "global"
		vim.notify(
			string.format("UV auto-activate venv (%s): %s", scope, new_value and "enabled" or "disabled"),
			vim.log.levels.INFO
		)
	end
end

-- Virtual environment activation
---@param venv_path string
function M.activate_venv(venv_path)
	-- For Mac, run the source command to apply to the current shell (kept for reference)
	local _command = "source " .. venv_path .. "/bin/activate"
	-- Set environment variables for the current Neovim instance
	vim.env.VIRTUAL_ENV = venv_path
	vim.env.PATH = venv_path .. "/bin:" .. vim.env.PATH
	-- Notify user
	if M.config.notify_activate_venv then
		vim.notify("Activated virtual environment: " .. venv_path, vim.log.levels.INFO)
	end
end

-- Auto-activate the .venv if it exists at the project root
-- Respects the granular vim.g/vim.b.uv_auto_activate_venv settings
---@return boolean
function M.auto_activate_venv()
	-- Check if auto-activation is enabled (respects buffer/global vim vars)
	if not M.is_auto_activate_enabled() then
		return false
	end

	local venv_path = vim.fn.getcwd() .. "/.venv"
	if vim.fn.isdirectory(venv_path) == 1 then
		M.activate_venv(venv_path)
		return true
	end
	return false
end

-- Statusline helper: Check if a virtual environment is active
---@return boolean
function M.is_venv_active()
	return vim.env.VIRTUAL_ENV ~= nil
end

-- Statusline helper: Get the name of the active virtual environment
-- Reads the prompt from pyvenv.cfg if available, otherwise returns the venv folder name
---@return string|nil
function M.get_venv()
	if not vim.env.VIRTUAL_ENV then
		return nil
	end

	-- Try to read prompt from pyvenv.cfg
	local pyvenv_cfg = vim.env.VIRTUAL_ENV .. "/pyvenv.cfg"

	if vim.fn.filereadable(pyvenv_cfg) == 1 then
		local lines = vim.fn.readfile(pyvenv_cfg)
		for _, line in ipairs(lines) do
			local prompt = line:match("^%s*prompt%s*=%s*(.+)%s*$")
			if prompt then
				return prompt
			end
		end
	end

	-- Fallback to venv folder name
	return vim.fn.fnamemodify(vim.env.VIRTUAL_ENV, ":t")
end

-- Statusline helper: Get the full path of the active virtual environment
---@return string|nil
function M.get_venv_path()
	return vim.env.VIRTUAL_ENV
end

-- Internal: open a terminal according to execution.terminal (no helper exported)
---@param cmd string
---@param input string
---@return string
local function shell_args(input)
	local args = {}
	for arg in input:gmatch("%S+") do
		table.insert(args, vim.fn.shellescape(arg))
	end
	return table.concat(args, " ")
end

local function open_term(cmd)
	local where = M.config.execution.terminal or "vsplit"
	if where == "split" then
		vim.cmd("split")
	elseif where == "tab" then
		vim.cmd("tabnew")
	else
		vim.cmd("vsplit")
	end
	vim.cmd("term " .. cmd)
end

local selection_prelude = [=[
import ast as _ast
import sys as _sys
import textwrap as _textwrap


def _uv_load_context(path, start, end):
    source = open(path).read()
    try:
        tree = _ast.parse(source)
    except SyntaxError as error:
        print(
            f"uv.nvim: buffer has a syntax error on line {error.lineno}: {error.msg}, running selection without file context",
            file=_sys.stderr,
        )
        return
    snippet = _textwrap.dedent("\n".join(source.splitlines()[start - 1 : end]))
    try:
        selected = _ast.parse(snippet)
    except SyntaxError:
        selected = _ast.parse("def _():\n" + _textwrap.indent(snippet, "    "))

    def used(node):
        return {n.id for n in _ast.walk(node) if isinstance(n, _ast.Name)}

    def bound(stmt):
        if isinstance(stmt, (_ast.FunctionDef, _ast.AsyncFunctionDef, _ast.ClassDef)):
            return {stmt.name}
        if isinstance(stmt, (_ast.Import, _ast.ImportFrom)):
            return {(a.asname or a.name).split(".")[0] for a in stmt.names}
        if isinstance(stmt, _ast.Assign):
            return {n.id for t in stmt.targets for n in _ast.walk(t) if isinstance(n, _ast.Name)}
        if isinstance(stmt, (_ast.AnnAssign, _ast.AugAssign)):
            return {n.id for n in _ast.walk(stmt.target) if isinstance(n, _ast.Name)}
        return set()

    needed = used(selected) | {"*"}
    included = []
    changed = True
    while changed:
        changed = False
        for stmt in tree.body:
            if stmt not in included and bound(stmt) & needed:
                included.append(stmt)
                needed |= used(stmt)
                changed = True
    body = [stmt for stmt in tree.body if stmt in included]
    exec(compile(_ast.Module(body=body, type_ignores=[]), path, "exec"), globals())


_uv_load_context(%s, %d, %d)
]=]

-- Function to create a temporary file with the necessary context and selected code
function M.run_python_selection()
	-- Get visual selection
	---@return string
	local function get_visual_selection()
		if vim.fn.mode():match("^[vV\22]") then
			vim.cmd("normal! \27")
		end
		local start_pos = vim.fn.getpos("'<")
		local end_pos = vim.fn.getpos("'>")
		local lines = vim.fn.getline(start_pos[2], end_pos[2])

		if #lines == 0 then
			return ""
		end

		-- Adjust last line to end at the column position of end_pos
		if #lines > 0 then
			lines[#lines] = lines[#lines]:sub(1, end_pos[3])
		end

		-- Adjust first line to start at the column position of start_pos
		if #lines > 0 then
			lines[1] = lines[1]:sub(start_pos[3])
		end

		return table.concat(lines, "\n")
	end

	-- Get selected code
	local selection = get_visual_selection()
	if selection == "" then
		vim.notify("No code selected", vim.log.levels.WARN)
		return
	end

	-- Create temp file
	local temp_dir = vim.fn.expand("$HOME") .. "/.cache/nvim/uv_run"
	vim.fn.mkdir(temp_dir, "p")
	local temp_file = temp_dir .. "/run_selection.py"
	local file, err = io.open(temp_file, "w")
	if not file then
		vim.notify("Failed to create temporary file " .. temp_file .. ": " .. err, vim.log.levels.ERROR)
		return
	end

	local source_file = temp_dir .. "/run_selection_source.py"
	vim.fn.writefile(vim.api.nvim_buf_get_lines(0, 0, -1, false), source_file)
	file:write(string.format(selection_prelude, vim.inspect(source_file), vim.fn.line("'<"), vim.fn.line("'>")))
	file:write("\n")

	-- Write selected code
	file:write("# SELECTED CODE\n")

	-- Check if the selection is all indented (which would cause syntax errors)
	local is_all_indented = true
	for line in selection:gmatch("[^\r\n]+") do
		if not line:match("^%s+") and line ~= "" then
			is_all_indented = false
			break
		end
	end

	-- Process the selection to determine what type of code it is
	local is_function_def = selection:match("^%s*def%s+[%w_]+%s*%(") ~= nil
	local is_class_def = selection:match("^%s*class%s+[%w_]+") ~= nil
	local has_print = selection:match("print%s*%(") ~= nil
	local is_expression = not is_function_def
		and not is_class_def
		and not selection:match("=")
		and not selection:match("%s*for%s+")
		and not selection:match("%s*if%s+")
		and not has_print

	-- If the selection is all indented, we need to dedent it or wrap it in a function
	if is_all_indented then
		file:write("def run_selection():\n")
		-- Write the selection with original indentation
		for line in selection:gmatch("[^\r\n]+") do
			file:write("    " .. line .. "\n")
		end
		file:write("\n# Auto-call the wrapper function\n")
		file:write("run_selection()\n")
	else
		-- Write the original selection
		file:write(selection .. "\n")

		-- For expressions, we'll add a print statement to see the result
		if is_expression then
			file:write("\n# Auto-added print for expression\n")
			file:write('print(f"Expression result: {' .. selection:gsub("^%s+", ""):gsub("%s+$", "") .. '}")\n')
		-- For function definitions without calls, we'll add a call
		elseif is_function_def then
			local function_name = selection:match("def%s+([%w_]+)%s*%(")
			-- Check if the function is already called in the selection
			if function_name and not selection:match(function_name .. "%s*%(.-%)") then
				file:write("\n# Auto-added function call\n")
				file:write('if __name__ == "__main__":\n')
				file:write('    print(f"Auto-executing function: ' .. function_name .. '")\n')
				file:write("    result = " .. function_name .. "()\n")
				file:write("    if result is not None:\n")
				file:write('        print(f"Return value: {result}")\n')
			end
		-- If there's no print statement in the code, add an output marker
		elseif not has_print and not selection:match("^%s*#") then
			file:write("\n# Auto-added execution marker\n")
			file:write('print("Code executed successfully.")\n')
		end
	end

	file:close()

	-- Run the temp file
	vim.notify("Running selected code...", vim.log.levels.INFO)
	local cmd = M.config.execution.run_command .. " " .. vim.fn.shellescape(temp_file)
	open_term(cmd)
end

-- Function displaying a dropdown to select a package to remove
function M.remove_package()
	local package_list = vim.fn.systemlist("uv pip list --format=freeze | cut -d= -f1")

	-- Show a picker to select the package
	vim.ui.select(package_list, {
		prompt = "Select package to remove:",
	}, function(choice)
		if choice then
			M.run_command("uv remove " .. vim.fn.shellescape(choice))
		end
	end)
end

-- Function prompting for a package to add
function M.add_package()
	vim.ui.input({ prompt = "Enter package name: " }, function(input)
		if input and input ~= "" then
			M.run_command("uv add " .. shell_args(input))
		end
	end)
end

-- Function to run a specific Python function
function M.run_python_function()
	-- Get current buffer content
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local buffer_content = table.concat(lines, "\n")

	-- Find all function definitions
	---@type string[]
	local functions = {}
	for line in buffer_content:gmatch("[^\r\n]+") do
		local func_name = line:match("^def%s+([%w_]+)%s*%(")
		if func_name then
			table.insert(functions, func_name)
		end
	end

	if #functions == 0 then
		vim.notify("No functions found in current file", vim.log.levels.WARN)
		return
	end

	-- Create temp file for function selection picker
	---@param func_name string
	local function run_function(func_name)
		local temp_dir = vim.fn.expand("$HOME") .. "/.cache/nvim/uv_run"
		vim.fn.mkdir(temp_dir, "p")
		local temp_file = temp_dir .. "/run_function.py"
		local current_file = vim.fn.expand("%:p")

		local file, err = io.open(temp_file, "w")
		if not file then
			vim.notify("Failed to create temporary file " .. temp_file .. ": " .. err, vim.log.levels.ERROR)
			return
		end

		-- Get the module name (file name without .py)
		local module_name = vim.fn.fnamemodify(current_file, ":t:r")
		local module_dir = vim.fn.fnamemodify(current_file, ":h")

		-- Write imports
		file:write("import sys\n")
		file:write("sys.path.insert(0, " .. vim.inspect(module_dir) .. ")\n")
		file:write("import " .. module_name .. "\n\n")
		file:write('if __name__ == "__main__":\n')
		file:write('    print(f"Running function: ' .. func_name .. '")\n')
		file:write("    result = " .. module_name .. "." .. func_name .. "()\n")
		file:write("    if result is not None:\n")
		file:write('        print(f"Return value: {result}")\n')
		file:close()

		-- Run the temp file
		vim.notify("Running function: " .. func_name, vim.log.levels.INFO)
		local cmd = M.config.execution.run_command .. " " .. vim.fn.shellescape(temp_file)
		open_term(cmd)
	end

	-- If there's only one function, run it directly
	if #functions == 1 then
		run_function(functions[1])
		return
	end

	-- Otherwise, show a picker to select the function
	vim.ui.select(functions, {
		prompt = "Select function to run:",
		format_item = function(item)
			return "def " .. item .. "()"
		end,
	}, function(choice)
		if choice then
			run_function(choice)
		end
	end)
end

-- Run current file
function M.run_file()
	local current_file = vim.fn.expand("%:p")
	if current_file and current_file ~= "" then
		vim.notify("Running: " .. vim.fn.expand("%:t"), vim.log.levels.INFO)
		local cmd = M.config.execution.run_command .. " " .. vim.fn.shellescape(current_file)
		open_term(cmd)
	else
		vim.notify("No file is open", vim.log.levels.WARN)
	end
end

---@return "snacks"|"telescope"|"fzf-lua"|"select"|nil
local function get_picker()
	local choice = M.config.picker_integration
	if choice == "telescope" or (choice == true and pcall(require, "telescope")) then
		return "telescope"
	end
	if choice == "snacks" or (choice == true and _G.Snacks and _G.Snacks.picker) then
		return "snacks"
	end
	if choice == "fzf-lua" or (choice == true and pcall(require, "fzf-lua")) then
		return "fzf-lua"
	end
	if choice == "select" then
		return "select"
	end
end

local function run_selection_from_picker()
	local mode = vim.fn.mode()
	if mode == "v" or mode == "V" or mode == "\22" then
		vim.cmd("normal! \27")
		vim.defer_fn(function()
			M.run_python_selection()
		end, 100)
		return
	end
	vim.notify("Please select text first. Enter visual mode (v) and select code to run.", vim.log.levels.INFO)
	vim.api.nvim_create_autocmd("ModeChanged", {
		pattern = "[vV\x16]*:n",
		callback = function()
			M.run_python_selection()
			return true
		end,
		once = true,
	})
end

---@return { text: string, desc: string, action: fun()? }[]
local function command_items()
	return {
		{ text = "Run current file", desc = "Run current file with Python", action = M.run_file },
		{ text = "Run selection", desc = "Run selected Python code", action = run_selection_from_picker },
		{ text = "Run function", desc = "Run specific Python function", action = M.run_python_function },
		{ text = "uv add [package]", desc = "Install a package" },
		{ text = "uv sync", desc = "Sync packages from lockfile" },
		{ text = "uv sync --all-extras --all-packages --all-groups", desc = "Sync all extras, groups and packages" },
		{ text = "uv remove [package]", desc = "Remove a package" },
		{ text = "uv init", desc = "Initialize a new project" },
	}
end

---@param item { text: string, action: fun()? }
local function run_command_item(item)
	if item.action then
		item.action()
		return
	end
	local param_name = item.text:match("%[(.-)%]")
	if not param_name then
		M.run_command(item.text)
		return
	end
	vim.ui.input({ prompt = "Enter " .. param_name .. ": " }, function(input)
		if not input or input == "" then
			vim.notify("Cancelled", vim.log.levels.INFO)
			return
		end
		M.run_command((item.text:gsub("%[.-%]", function()
			return shell_args(input)
		end)))
	end)
end

---@return { text: string, path: string?, is_current: boolean?, is_create: boolean? }[]
local function venv_items()
	if vim.fn.isdirectory(".venv") == 1 then
		return {
			{
				text = ".venv",
				path = vim.fn.getcwd() .. "/.venv",
				is_current = vim.env.VIRTUAL_ENV and vim.env.VIRTUAL_ENV:match(".venv$") ~= nil,
			},
		}
	end
	return { { text = "Create new virtual environment (uv venv)", is_create = true } }
end

---@param item { text: string, is_current: boolean?, is_create: boolean? }
---@return string
local function format_venv_item(item)
	if item.is_create then
		return "+ " .. item.text
	end
	return (item.is_current and "● " or "○ ") .. item.text .. " (Activate)"
end

---@param item { path: string?, is_create: boolean? }
local function run_venv_item(item)
	if item.is_create then
		M.run_command("uv venv")
	else
		M.activate_venv(item.path)
	end
end

local function setup_snacks_picker()
	Snacks.picker.sources.uv_commands = {
		finder = command_items,
		preview = function(ctx)
			local cmd = ctx.item.text:match("^(uv %a+)")
			if cmd then
				Snacks.picker.preview.cmd(cmd .. " --help", ctx)
			else
				ctx.preview:set_lines({})
			end
		end,
		format = function(item)
			return { { item.text .. " - " .. item.desc } }
		end,
		confirm = function(picker, item)
			if item then
				picker:close()
				run_command_item(item)
			end
		end,
	}

	Snacks.picker.sources.uv_venv = {
		finder = venv_items,
		format = function(item)
			return { { format_venv_item(item) } }
		end,
		confirm = function(picker, item)
			picker:close()
			if item then
				run_venv_item(item)
			end
		end,
	}
end

local function setup_telescope_picker()
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local sorters = require("telescope.sorters")
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")

	local function pick(title, items, format, on_choice)
		pickers
			.new({}, {
				prompt_title = title,
				finder = finders.new_table({
					results = items,
					entry_maker = function(entry)
						return { value = entry, display = format(entry), ordinal = format(entry) }
					end,
				}),
				sorter = sorters.get_generic_fuzzy_sorter(),
				attach_mappings = function(prompt_bufnr, map)
					local function on_select()
						local selection = action_state.get_selected_entry().value
						actions.close(prompt_bufnr)
						on_choice(selection)
					end

					map("i", "<CR>", on_select)
					map("n", "<CR>", on_select)
					return true
				end,
			})
			:find()
	end

	function M.pick_uv_commands()
		pick("UV Commands", command_items(), function(item)
			return item.text
		end, run_command_item)
	end

	function M.pick_uv_venv()
		pick("UV Virtual Environments", venv_items(), format_venv_item, run_venv_item)
	end
end

---@param picker "fzf-lua"|"select"
local function setup_select_picker(picker)
	local function pick(title, items, format, on_choice)
		if picker == "select" then
			vim.ui.select(items, { prompt = title, format_item = format }, function(item)
				if item then
					on_choice(item)
				end
			end)
			return
		end
		local labels, by_label = {}, {}
		for _, item in ipairs(items) do
			table.insert(labels, format(item))
			by_label[format(item)] = item
		end
		require("fzf-lua").fzf_exec(labels, {
			prompt = title .. "> ",
			actions = {
				default = function(selected)
					if selected and by_label[selected[1]] then
						on_choice(by_label[selected[1]])
					end
				end,
			},
		})
	end

	function M.pick_uv_commands()
		pick("UV Commands", command_items(), function(item)
			return item.text
		end, run_command_item)
	end

	function M.pick_uv_venv()
		pick("UV Virtual Environments", venv_items(), format_venv_item, run_venv_item)
	end
end

-- Set up command pickers for integration with UI plugins
function M.setup_pickers()
	local choice = M.config.picker_integration
	if (choice == true or choice == "snacks") and _G.Snacks and _G.Snacks.picker then
		setup_snacks_picker()
	end
	if (choice == true or choice == "telescope") and pcall(require, "telescope") then
		setup_telescope_picker()
	end
	local picker = get_picker()
	if picker == "fzf-lua" or picker == "select" then
		setup_select_picker(picker)
	end
end

-- Set up user commands
function M.setup_commands()
	vim.api.nvim_create_user_command("UVInit", function()
		M.run_command("uv init")
	end, {})

	vim.api.nvim_create_user_command("UVRunSelection", function()
		M.run_python_selection()
	end, { range = true })

	vim.api.nvim_create_user_command("UVRunFunction", function()
		M.run_python_function()
	end, {})

	vim.api.nvim_create_user_command("UVRunFile", function()
		M.run_file()
	end, {})

	vim.api.nvim_create_user_command("UVAddPackage", function(opts)
		M.run_command("uv add " .. shell_args(opts.args))
	end, { nargs = 1 })

	vim.api.nvim_create_user_command("UVRemovePackage", function(opts)
		M.run_command("uv remove " .. shell_args(opts.args))
	end, { nargs = 1 })

	-- Toggle auto-activate venv (granular control)
	vim.api.nvim_create_user_command("UVAutoActivateToggle", function()
		M.toggle_auto_activate_venv(false)
	end, { desc = "Toggle auto-activate venv globally" })

	vim.api.nvim_create_user_command("UVAutoActivateToggleBuffer", function()
		M.toggle_auto_activate_venv(true)
	end, { desc = "Toggle auto-activate venv for current buffer" })
end

-- Set up keymaps
function M.setup_keymaps()
	local keymaps = M.config.keymaps
	if not keymaps then
		return
	end

	local prefix = keymaps.prefix or "<leader>x"
	local picker = get_picker()

	-- Main UV command menu
	if keymaps.commands then
		if picker == "snacks" then
			vim.api.nvim_set_keymap(
				"n",
				prefix,
				"<cmd>lua Snacks.picker.pick('uv_commands')<CR>",
				{ noremap = true, silent = true, desc = "UV Commands" }
			)
			vim.api.nvim_set_keymap(
				"v",
				prefix,
				":<C-u>lua Snacks.picker.pick('uv_commands')<CR>",
				{ noremap = true, silent = true, desc = "UV Commands" }
			)
		end
		if picker and picker ~= "snacks" then
			vim.api.nvim_set_keymap(
				"n",
				prefix,
				"<cmd>lua require('uv').pick_uv_commands()<CR>",
				{ noremap = true, silent = true, desc = "UV Commands" }
			)
			vim.api.nvim_set_keymap(
				"v",
				prefix,
				":<C-u>lua require('uv').pick_uv_commands()<CR>",
				{ noremap = true, silent = true, desc = "UV Commands" }
			)
		end
	end

	-- Run current file
	if keymaps.run_file then
		vim.api.nvim_set_keymap(
			"n",
			prefix .. "r",
			"<cmd>UVRunFile<CR>",
			{ noremap = true, silent = true, desc = "UV Run Current File" }
		)
	end

	-- Run selection
	if keymaps.run_selection then
		vim.api.nvim_set_keymap(
			"v",
			prefix .. "s",
			":<C-u>UVRunSelection<CR>",
			{ noremap = true, silent = true, desc = "UV Run Selection" }
		)
	end

	-- Run function
	if keymaps.run_function then
		vim.api.nvim_set_keymap(
			"n",
			prefix .. "f",
			"<cmd>UVRunFunction<CR>",
			{ noremap = true, silent = true, desc = "UV Run Function" }
		)
	end

	-- Environment management
	if keymaps.venv then
		if picker == "snacks" then
			vim.api.nvim_set_keymap(
				"n",
				prefix .. "e",
				"<cmd>lua Snacks.picker.pick('uv_venv')<CR>",
				{ noremap = true, silent = true, desc = "UV Environment" }
			)
		end
		if picker and picker ~= "snacks" then
			vim.api.nvim_set_keymap(
				"n",
				prefix .. "e",
				"<cmd>lua require('uv').pick_uv_venv()<CR>",
				{ noremap = true, silent = true, desc = "UV Environment" }
			)
		end
	end

	-- Initialize UV project
	if keymaps.init then
		vim.api.nvim_set_keymap(
			"n",
			prefix .. "i",
			"<cmd>UVInit<CR>",
			{ noremap = true, silent = true, desc = "UV Init" }
		)
	end

	-- Add a package
	if keymaps.add then
		vim.api.nvim_set_keymap(
			"n",
			prefix .. "a",
			"<cmd>lua require('uv').add_package()<CR>",
			{ noremap = true, silent = true, desc = "UV Add Package" }
		)
	end

	-- Remove a package
	if keymaps.remove then
		vim.api.nvim_set_keymap(
			"n",
			prefix .. "d",
			"<cmd>lua require('uv').remove_package()<CR>",
			{ noremap = true, silent = true, desc = "UV Remove Package" }
		)
	end

	-- Sync packages
	if keymaps.sync then
		vim.api.nvim_set_keymap(
			"n",
			prefix .. "c",
			"<cmd>lua require('uv').run_command('uv sync')<CR>",
			{ noremap = true, silent = true, desc = "UV Sync Packages" }
		)
	end
	if keymaps.sync_all then
		vim.api.nvim_set_keymap(
			"n",
			prefix .. "C",
			"<cmd>lua require('uv').run_command('uv sync --all-extras --all-packages --all-groups')<CR>",
			{ noremap = true, silent = true, desc = "UV Sync All Extras, Groups and Packages" }
		)
	end
end

-- Set up auto commands
function M.setup_autocommands()
	if M.config.auto_commands then
		-- Auto-activate on startup (respects vim.g/vim.b settings internally)
		M.auto_activate_venv()

		-- Re-activate when directory changes
		-- The actual activation check happens inside auto_activate_venv()
		-- which respects vim.g.uv_auto_activate_venv and vim.b.uv_auto_activate_venv
		vim.api.nvim_create_autocmd({ "DirChanged" }, {
			pattern = { "global" },
			callback = function()
				M.auto_activate_venv()
			end,
		})
	end
end

-- Main setup function
---@param opts UVConfig|nil
function M.setup(opts)
	-- Merge user configuration with defaults
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	-- Set up commands
	M.setup_commands()

	-- Set up keymaps if enabled
	if M.config.keymaps ~= false then
		M.setup_keymaps()
	end

	-- Set up autocommands if enabled
	if M.config.auto_commands ~= false then
		M.setup_autocommands()
	end

	-- Set up pickers if integration is enabled
	if M.config.picker_integration then
		M.setup_pickers()
	end

	-- Make run_command globally accessible (can be removed if not needed)
	_G.run_command = M.run_command
end

return M
