-- Snacks picker integration for uv.nvim
local M = {}

---Check if Snacks picker is available
---@return boolean
function M.is_available()
	return _G.Snacks ~= nil and _G.Snacks.picker ~= nil
end

---Get the commands source configuration for Snacks picker
---@param callbacks table Table with run_file, run_python_selection, run_python_function, run_command functions
---@return table
function M.get_commands_source(callbacks)
	return {
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
				if item.is_run_current then
					if callbacks.run_file then
						callbacks.run_file()
					end
					return
				elseif item.is_run_selection then
					local mode = vim.fn.mode()
					if mode == "v" or mode == "V" or mode == "" then
						vim.cmd("normal! \27")
						vim.defer_fn(function()
							if callbacks.run_python_selection then
								callbacks.run_python_selection()
							end
						end, 100)
					else
						vim.notify(
							"Please select text first. Enter visual mode (v) and select code to run.",
							vim.log.levels.INFO
						)
						vim.api.nvim_create_autocmd("ModeChanged", {
							pattern = "[vV\x16]*:n",
							callback = function(_)
								if callbacks.run_python_selection then
									callbacks.run_python_selection()
								end
								return true
							end,
							once = true,
						})
					end
					return
				elseif item.is_run_function then
					if callbacks.run_python_function then
						callbacks.run_python_function()
					end
					return
				end

				local cmd = item.text
				if cmd:match("%[(.-)%]") then
					local param_name = cmd:match("%[(.-)%]")
					vim.ui.input({ prompt = "Enter " .. param_name .. ": " }, function(input)
						if not input or input == "" then
							vim.notify("Cancelled", vim.log.levels.INFO)
							return
						end
						local actual_cmd = cmd:gsub("%[" .. param_name .. "%]", input)
						if callbacks.run_command then
							callbacks.run_command(actual_cmd)
						end
					end)
				else
					if callbacks.run_command then
						callbacks.run_command(cmd)
					end
				end
			end
		end,
	}
end

---Get the venv source configuration for Snacks picker
---@param callbacks table Table with activate_venv, run_command functions
---@return table
function M.get_venv_source(callbacks)
	return {
		finder = function()
			local venvs = {}
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
					if callbacks.run_command then
						callbacks.run_command("uv venv")
					end
				else
					if callbacks.activate_venv then
						callbacks.activate_venv(item.path)
					end
				end
			end
		end,
	}
end

---Setup Snacks picker sources
---@param callbacks table Table with callback functions
function M.setup(callbacks)
	if not M.is_available() then
		return false
	end

	Snacks.picker.sources.uv_commands = M.get_commands_source(callbacks)
	Snacks.picker.sources.uv_venv = M.get_venv_source(callbacks)
	return true
end

return M
