-- Telescope picker integration for uv.nvim
local M = {}

---Check if Telescope is available
---@return boolean
function M.is_available()
	local has_telescope = pcall(require, "telescope")
	return has_telescope
end

---Create UV commands picker for Telescope
---@param callbacks table Table with run_file, run_python_selection, run_python_function, run_command functions
---@return function
function M.pick_uv_commands(callbacks)
	return function()
		local pickers = require("telescope.pickers")
		local finders = require("telescope.finders")
		local sorters = require("telescope.sorters")
		local actions = require("telescope.actions")
		local action_state = require("telescope.actions.state")

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
							if callbacks.run_file then
								callbacks.run_file()
							end
						elseif selection.is_run_selection then
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
									callback = function()
										if callbacks.run_python_selection then
											callbacks.run_python_selection()
										end
										return true
									end,
									once = true,
								})
							end
						elseif selection.is_run_function then
							if callbacks.run_python_function then
								callbacks.run_python_function()
							end
						else
							if selection.needs_input then
								local placeholder = selection.text:match("%[(.-)%]")
								vim.ui.input({ prompt = "Enter " .. (placeholder or "value") .. ": " }, function(input)
									if input and input ~= "" then
										local cmd = selection.cmd .. input
										if callbacks.run_command then
											callbacks.run_command(cmd)
										end
									else
										vim.notify("Cancelled", vim.log.levels.INFO)
									end
								end)
							else
								if callbacks.run_command then
									callbacks.run_command(selection.cmd)
								end
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
end

---Create UV venv picker for Telescope
---@param callbacks table Table with activate_venv, run_command functions
---@return function
function M.pick_uv_venv(callbacks)
	return function()
		local pickers = require("telescope.pickers")
		local finders = require("telescope.finders")
		local sorters = require("telescope.sorters")
		local actions = require("telescope.actions")
		local action_state = require("telescope.actions.state")

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
							if callbacks.run_command then
								callbacks.run_command("uv venv")
							end
						else
							if callbacks.activate_venv then
								callbacks.activate_venv(selection.path)
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
end

---Setup Telescope picker functions
---@param callbacks table Table with callback functions
---@return table Table with pick_uv_commands and pick_uv_venv functions
function M.setup(callbacks)
	if not M.is_available() then
		return nil
	end

	return {
		pick_uv_commands = M.pick_uv_commands(callbacks),
		pick_uv_venv = M.pick_uv_venv(callbacks),
	}
end

return M
