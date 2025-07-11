-- uv.nvim - Neovim plugin for uv Python package management integration
-- Author: Ben O'Mahony
-- License: MIT

local M = {}

-- Default configuration
M.config = {
	-- Auto-activate virtual environments when found
	auto_activate_venv = true,
	notify_activate_venv = true,

	-- Auto commands for directory changes
	auto_commands = true,

	-- Integration with picker (like Telescope or other UI components)
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

		-- Show output in notifications
		notify_output = true,

		-- Notification timeout in ms
		notification_timeout = 10000,
	},
}

-- Command runner - runs shell commands and captures output
function M.run_command(cmd)
	-- Run command in background and capture output
	vim.fn.jobstart(cmd, {
		on_exit = function(_, exit_code)
			if exit_code == 0 then
				vim.notify("Command completed successfully: " .. cmd, vim.log.levels.INFO)
			else
				vim.notify("Command failed: " .. cmd, vim.log.levels.ERROR)
			end
		end,
		on_stdout = function(_, data)
			if data and #data > 1 then
				-- Only show meaningful output (not empty lines)
				local output = table.concat(data, "\n")
				if output and output:match("%S") then
					vim.notify(output, vim.log.levels.INFO)
				end
			end
		end,
		on_stderr = function(_, data)
			if data and #data > 1 then
				-- Show errors
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

-- Virtual environment activation
function M.activate_venv(venv_path)
	-- For Mac, run the source command to apply to the current shell
	local command = "source " .. venv_path .. "/bin/activate"
	-- Set environment variables for the current Neovim instance
	vim.env.VIRTUAL_ENV = venv_path
	vim.env.PATH = venv_path .. "/bin:" .. vim.env.PATH
	-- Notify user
	if M.config.notify_activate_venv then
		vim.notify("Activated virtual environment: " .. venv_path, vim.log.levels.INFO)
	end
end

-- Auto-activate the .venv if it exists at the project root
function M.auto_activate_venv()
	local venv_path = vim.fn.getcwd() .. "/.venv"
	if vim.fn.isdirectory(venv_path) == 1 then
		M.activate_venv(venv_path)
		return true
	end
	return false
end

-- Function to create a temporary file with the necessary context and selected code
function M.run_python_selection()
	-- Get visual selection
	local get_visual_selection = function()
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

	-- Get current buffer content to extract imports and global variables
	local get_buffer_globals = function()
		local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
		local imports = {}
		local globals = {}
		local in_class = false
		local class_indent = 0

		for _, line in ipairs(lines) do
			-- Detect imports
			if line:match("^%s*import ") or line:match("^%s*from .+ import") then
				table.insert(imports, line)
			end

			-- Detect class definitions to skip class variables
			if line:match("^%s*class ") then
				in_class = true
				class_indent = line:match("^(%s*)"):len()
			end

			-- Check if we're exiting a class block
			if in_class and line:match("^%s*[^%s#]") then
				local current_indent = line:match("^(%s*)"):len()
				if current_indent <= class_indent then
					in_class = false
				end
			end

			-- Detect global variable assignments (not in class, not inside functions)
			if not in_class and not line:match("^%s*def ") and line:match("^%s*[%w_]+ *=") then
				-- Check if it's not indented (global scope)
				if not line:match("^%s%s+") then
					table.insert(globals, line)
				end
			end
		end

		return imports, globals
	end

	-- Get selected code
	local selection = get_visual_selection()
	if selection == "" then
		vim.notify("No code selected", vim.log.levels.WARN)
		return
	end

	-- Get imports and globals
	local imports, globals = get_buffer_globals()

	-- Create temp file
	local temp_dir = vim.fn.expand("$HOME") .. "/.cache/nvim/uv_run"
	vim.fn.mkdir(temp_dir, "p")
	local temp_file = temp_dir .. "/run_selection.py"
	local file = io.open(temp_file, "w")
	if not file then
		vim.notify("Failed to create temporary file", vim.log.levels.ERROR)
		return
	end

	-- Write imports
	for _, imp in ipairs(imports) do
		file:write(imp .. "\n")
	end
	file:write("\n")

	-- Write globals
	for _, glob in ipairs(globals) do
		file:write(glob .. "\n")
	end
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
	local is_function_def = selection:match("^%s*def%s+[%w_]+%s*%(")
	local is_class_def = selection:match("^%s*class%s+[%w_]+")
	local has_print = selection:match("print%s*%(")
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
	vim.fn.jobstart(M.config.execution.run_command .. " " .. vim.fn.shellescape(temp_file), {
		on_stdout = function(_, data)
			if data and #data > 1 then
				local output = table.concat(data, "\n")
				if output and output:match("%S") then
					vim.notify(output, vim.log.levels.INFO, {
						title = "Python Output",
						timeout = M.config.execution.notification_timeout,
					})
				end
			end
		end,
		on_stderr = function(_, data)
			if data and #data > 1 then
				local output = table.concat(data, "\n")
				if output and output:match("%S") then
					vim.notify(output, vim.log.levels.ERROR, {
						title = "Python Error",
						timeout = M.config.execution.notification_timeout,
					})
				end
			end
		end,
		on_exit = function(_, exit_code)
			if exit_code == 0 then
				vim.notify("Selected code executed successfully", vim.log.levels.INFO)
			else
				vim.notify("Selected code execution failed with exit code: " .. exit_code, vim.log.levels.ERROR)
			end
		end,
		stdout_buffered = true,
		stderr_buffered = true,
	})
end

-- Function to run a specific Python function
function M.run_python_function()
	-- Get current buffer content
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local buffer_content = table.concat(lines, "\n")

	-- Find all function definitions
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
	local run_function = function(func_name)
		-- Create a temporary file with a main block to call the function
		local temp_dir = vim.fn.expand("$HOME") .. "/.cache/nvim/uv_run"
		vim.fn.mkdir(temp_dir, "p")
		local temp_file = temp_dir .. "/run_function.py"
		local current_file = vim.fn.expand("%:p")

		-- Create a wrapper script that imports the current file and calls the function
		local file = io.open(temp_file, "w")
		if not file then
			vim.notify("Failed to create temporary file", vim.log.levels.ERROR)
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
		vim.fn.jobstart(M.config.execution.run_command .. " " .. vim.fn.shellescape(temp_file), {
			on_stdout = function(_, data)
				if data and #data > 1 then
					local output = table.concat(data, "\n")
					if output and output:match("%S") then
						vim.notify(output, vim.log.levels.INFO, {
							title = "Function Output",
							timeout = M.config.execution.notification_timeout,
						})
					end
				end
			end,
			on_stderr = function(_, data)
				if data and #data > 1 then
					local output = table.concat(data, "\n")
					if output and output:match("%S") then
						vim.notify(output, vim.log.levels.ERROR, {
							title = "Function Error",
							timeout = M.config.execution.notification_timeout,
						})
					end
				end
			end,
			on_exit = function(_, exit_code)
				if exit_code == 0 then
					vim.notify("Function executed successfully", vim.log.levels.INFO)
				else
					vim.notify("Function execution failed with exit code: " .. exit_code, vim.log.levels.ERROR)
				end
			end,
			stdout_buffered = true,
			stderr_buffered = true,
		})
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
		-- Run python on the current file and capture output to notifications
		vim.fn.jobstart(M.config.execution.run_command .. " " .. vim.fn.shellescape(current_file), {
			on_stdout = function(_, data)
				if data and #data > 1 then
					local output = table.concat(data, "\n")
					if output and output:match("%S") then
						vim.notify(output, vim.log.levels.INFO, {
							title = "Python Output",
							timeout = M.config.execution.notification_timeout,
						})
					end
				end
			end,
			on_stderr = function(_, data)
				if data and #data > 1 then
					local output = table.concat(data, "\n")
					if output and output:match("%S") then
						vim.notify(output, vim.log.levels.ERROR, {
							title = "Python Error",
							timeout = M.config.execution.notification_timeout,
						})
					end
				end
			end,
			on_exit = function(_, exit_code)
				if exit_code == 0 then
					vim.notify("Program execution completed successfully", vim.log.levels.INFO, {
						title = "Python Execution",
					})
				else
					vim.notify("Program execution failed with exit code: " .. exit_code, vim.log.levels.ERROR, {
						title = "Python Execution",
					})
				end
			end,
			stdout_buffered = true,
			stderr_buffered = true,
		})
	else
		vim.notify("No file is open", vim.log.levels.WARN)
	end
end

-- Set up command pickers for integration with UI plugins
function M.setup_pickers()
	-- Check if Snacks is available
	if _G.Snacks and _G.Snacks.picker then
		-- Register UV command source
		Snacks.picker.sources.uv_commands = {
			finder = function()
				return {
					{ text = "Run current file", desc = "Run current file with Python", is_run_current = true },
					{ text = "Run selection", desc = "Run selected Python code", is_run_selection = true },
					{ text = "Run function", desc = "Run specific Python function", is_run_function = true },
					{ text = "uv add [package]", desc = "Install a package" },
					{ text = "uv sync", desc = "Sync packages from lockfile" },
					{
						text = "uv sync --all-extras --all-packages --all-groups",
						desc = "Sync all extras, groups and packages",
					},
					{ text = "uv remove [package]", desc = "Remove a package" },
					{ text = "uv init", desc = "Initialize a new project" },
				}
			end,
			format = function(item)
				return { { item.text .. " - " .. item.desc } }
			end,
			confirm = function(picker, item)
				if item then
					picker:close()
					if item.is_run_current then
						M.run_file()
						return
					elseif item.is_run_selection then
						-- Check if there's a visual selection
						local mode = vim.fn.mode()

						if mode == "v" or mode == "V" or mode == "" then
							vim.cmd("normal! \27") -- Exit visual mode
							vim.defer_fn(function()
								M.run_python_selection()
							end, 100)
						else
							-- If not in visual mode, prompt the user to select text
							vim.notify(
								"Please select text first. Enter visual mode (v) and select code to run.",
								vim.log.levels.INFO
							)
							-- After notification, we'll set up a one-time autocmd to catch when visual mode is exited
							vim.api.nvim_create_autocmd("ModeChanged", {
								pattern = "[vV\x16]*:n", -- When changing from any visual mode to normal mode
								callback = function(ev)
									M.run_python_selection()
									return true -- Delete the autocmd after it's been triggered
								end,
								once = true,
							})
						end
						return
					elseif item.is_run_function then
						M.run_python_function()
						return
					end

					local cmd = item.text
					-- Check if command needs input
					if cmd:match("%[(.-)%]") then
						local param_name = cmd:match("%[(.-)%]")
						vim.ui.input({ prompt = "Enter " .. param_name .. ": " }, function(input)
							if not input or input == "" then
								vim.notify("Cancelled", vim.log.levels.INFO)
								return
							end
							-- Replace the placeholder with actual input
							local actual_cmd = cmd:gsub("%[" .. param_name .. "%]", input)
							M.run_command(actual_cmd)
						end)
					else
						-- Run the command directly
						M.run_command(cmd)
					end
				end
			end,
		}

		-- Register UV venv source
		Snacks.picker.sources.uv_venv = {
			finder = function()
				local venvs = {}
				-- Check for .venv directory (uv's default)
				if vim.fn.isdirectory(".venv") == 1 then
					table.insert(venvs, {
						text = ".venv",
						path = vim.fn.getcwd() .. "/.venv",
						is_current = vim.env.VIRTUAL_ENV and vim.env.VIRTUAL_ENV:match(".venv$") ~= nil,
					})
				end
				if #venvs == 0 then
					table.insert(venvs, {
						text = "Create new virtual environment (uv venv)",
						is_create = true,
					})
				end
				return venvs
			end,
			format = function(item)
				if item.is_create then
					return { { "+ " .. item.text } }
				else
					local icon = item.is_current and "● " or "○ "
					return { { icon .. item.text .. " (Activate)" } }
				end
			end,
			confirm = function(picker, item)
				picker:close()
				if item then
					if item.is_create then
						M.run_command("uv venv")
					else
						M.activate_venv(item.path)
					end
				end
			end,
		}
	end

	-- Check if Telescope is available
	local has_telescope, telescope = pcall(require, "telescope")
	if has_telescope then
		local pickers = require("telescope.pickers")
		local finders = require("telescope.finders")
		local sorters = require("telescope.sorters")
		local actions = require("telescope.actions")
		local action_state = require("telescope.actions.state")

		-- UV Commands picker for Telescope
		M.pick_uv_commands = function()
			local items = {
				{ text = "Run current file", is_run_current = true },
				{ text = "Run selection", is_run_selection = true },
				{ text = "Run function", is_run_function = true },
				{ text = "uv add [package]", cmd = "uv add ", needs_input = true },
				{ text = "uv sync", cmd = "uv sync" },
				{
					text = "uv sync --all-extras --all-packages --all-groups",
					cmd = "uv sync --all-extras --all-packages --all-groups",
				},
				{ text = "uv remove [package]", cmd = "uv remove ", needs_input = true },
				{ text = "uv init", cmd = "uv init" },
			}

			pickers
				.new({}, {
					prompt_title = "UV Commands",
					finder = finders.new_table({
						results = items,
						entry_maker = function(entry)
							return {
								value = entry,
								display = entry.text,
								ordinal = entry.text,
							}
						end,
					}),
					sorter = sorters.get_generic_fuzzy_sorter(),
					attach_mappings = function(prompt_bufnr, map)
						local function on_select()
							local selection = action_state.get_selected_entry().value
							actions.close(prompt_bufnr)
							if selection.is_run_current then
								M.run_file()
							elseif selection.is_run_selection then
								local mode = vim.fn.mode()
								if mode == "v" or mode == "V" or mode == "" then
									vim.cmd("normal! \27")
									vim.defer_fn(function()
										M.run_python_selection()
									end, 100)
								else
									vim.notify(
										"Please select text first. Enter visual mode (v) and select code to run.",
										vim.log.levels.INFO
									)
									vim.api.nvim_create_autocmd("ModeChanged", {
										pattern = "[vV\x16]*:n",
										callback = function()
											M.run_python_selection()
											return true
										end,
										once = true,
									})
								end
							elseif selection.is_run_function then
								M.run_python_function()
							else
								if selection.needs_input then
									local placeholder = selection.text:match("%[(.-)%]")
									vim.ui.input(
										{ prompt = "Enter " .. (placeholder or "value") .. ": " },
										function(input)
											if input and input ~= "" then
												local cmd = selection.cmd .. input
												M.run_command(cmd)
											else
												vim.notify("Cancelled", vim.log.levels.INFO)
											end
										end
									)
								else
									M.run_command(selection.cmd)
								end
							end
						end

						map("i", "<CR>", on_select)
						map("n", "<CR>", on_select)
						return true
					end,
				})
				:find()
		end

		-- UV venv picker for Telescope
		M.pick_uv_venv = function()
			local items = {}
			if vim.fn.isdirectory(".venv") == 1 then
				table.insert(items, {
					text = ".venv",
					path = vim.fn.getcwd() .. "/.venv",
					is_current = vim.env.VIRTUAL_ENV and vim.env.VIRTUAL_ENV:match(".venv$") ~= nil,
				})
			end
			if #items == 0 then
				table.insert(items, { text = "Create new virtual environment (uv venv)", is_create = true })
			end

			pickers
				.new({}, {
					prompt_title = "UV Virtual Environments",
					finder = finders.new_table({
						results = items,
						entry_maker = function(entry)
							local display = entry.is_create and "+ " .. entry.text
								or ((entry.is_current and "● " or "○ ") .. entry.text .. " (Activate)")
							return {
								value = entry,
								display = display,
								ordinal = display,
							}
						end,
					}),
					sorter = sorters.get_generic_fuzzy_sorter(),
					attach_mappings = function(prompt_bufnr, map)
						local function on_select()
							local selection = action_state.get_selected_entry().value
							actions.close(prompt_bufnr)
							if selection.is_create then
								M.run_command("uv venv")
							else
								M.activate_venv(selection.path)
							end
						end

						map("i", "<CR>", on_select)
						map("n", "<CR>", on_select)
						return true
					end,
				})
				:find()
		end
	end
end

-- Set up user commands
function M.setup_commands()
	-- Set up UV commands
	vim.api.nvim_create_user_command("UVInit", function()
		M.run_command("uv init")
	end, {})

	-- Command to run selected code
	vim.api.nvim_create_user_command("UVRunSelection", function()
		M.run_python_selection()
	end, { range = true })

	-- Command to run a specific function
	vim.api.nvim_create_user_command("UVRunFunction", function()
		M.run_python_function()
	end, {})

	-- Command to run the current file
	vim.api.nvim_create_user_command("UVRunFile", function()
		M.run_file()
	end, {})
end

-- Set up keymaps
function M.setup_keymaps()
	local keymaps = M.config.keymaps
	local prefix = keymaps.prefix or "<leader>x"

	-- Main UV command menu
	if keymaps.commands then
		if _G.Snacks and _G.Snacks.picker then
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
		local has_telescope = pcall(require, "telescope")
		if has_telescope then
			vim.api.nvim_set_keymap(
				"n",
				prefix,
				"<cmd>lua require('uv').pick_uv_commands()<CR>",
				{ noremap = true, silent = true, desc = "UV Commands (Telescope)" }
			)
			vim.api.nvim_set_keymap(
				"v",
				prefix,
				":<C-u>lua require('uv').pick_uv_commands()<CR>",
				{ noremap = true, silent = true, desc = "UV Commands (Telescope)" }
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
		if _G.Snacks and _G.Snacks.picker then
			vim.api.nvim_set_keymap(
				"n",
				prefix .. "e",
				"<cmd>lua Snacks.picker.pick('uv_venv')<CR>",
				{ noremap = true, silent = true, desc = "UV Environment" }
			)
		end
		local has_telescope_venv = pcall(require, "telescope")
		if has_telescope_venv then
			vim.api.nvim_set_keymap(
				"n",
				prefix .. "e",
				"<cmd>lua require('uv').pick_uv_venv()<CR>",
				{ noremap = true, silent = true, desc = "UV Environment (Telescope)" }
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
			"<cmd>lua vim.ui.input({prompt = 'Enter package name: '}, function(input) if input and input ~= '' then require('uv').run_command('uv add ' .. input) end end)<CR>",
			{ noremap = true, silent = true, desc = "UV Add Package" }
		)
	end

	-- Remove a package
	if keymaps.remove then
		vim.api.nvim_set_keymap(
			"n",
			prefix .. "d",
			"<cmd>lua vim.ui.input({prompt = 'Enter package name: '}, function(input) if input and input ~= '' then require('uv').run_command('uv remove ' .. input) end end)<CR>",
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
		-- Auto-activate .venv if it exists
		if M.config.auto_activate_venv then
			M.auto_activate_venv()

			-- Also set up auto-command to check when entering a directory
			vim.api.nvim_create_autocmd({ "DirChanged" }, {
				pattern = { "global" },
				callback = function()
					M.auto_activate_venv()
				end,
			})
		end
	end
end

-- Main setup function
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
