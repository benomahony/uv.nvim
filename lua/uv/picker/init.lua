-- Picker module for uv.nvim
-- Provides a unified interface for picker integrations (Snacks, Telescope, fzf-lua)

local config = require("uv.picker.config")
local snacks = require("uv.picker.snacks")
local telescope = require("uv.picker.telescope")

local M = {}

---@type table|nil Stored telescope picker functions
M._telescope_pickers = nil

---Resolve which picker to use based on config and availability
---@param picker_config PickerType
---@return string|false The resolved picker name or false if disabled
function M.resolve_picker(picker_config)
	local normalized = config.normalize(picker_config)

	if normalized == false then
		return false
	end

	if normalized ~= "auto" then
		-- User explicitly requested a specific picker
		return normalized
	end

	-- Auto mode: try pickers in priority order
	if snacks.is_available() then
		return "snacks"
	end

	if telescope.is_available() then
		return "telescope"
	end

	-- No picker available
	return false
end

---Setup pickers based on configuration
---@param picker_config PickerType
---@param callbacks table Callback functions for picker actions
---@return boolean success
function M.setup(picker_config, callbacks)
	local picker = M.resolve_picker(picker_config)

	if picker == false then
		return false
	end

	if picker == "snacks" then
		return snacks.setup(callbacks)
	end

	if picker == "telescope" then
		M._telescope_pickers = telescope.setup(callbacks)
		return M._telescope_pickers ~= nil
	end

	-- fzf-lua support can be added here in the future
	return false
end

---Get the commands picker function for the resolved picker
---@return function|nil
function M.get_commands_picker()
	if M._telescope_pickers then
		return M._telescope_pickers.pick_uv_commands
	end
	return nil
end

---Get the venv picker function for the resolved picker
---@return function|nil
function M.get_venv_picker()
	if M._telescope_pickers then
		return M._telescope_pickers.pick_uv_venv
	end
	return nil
end

---Get keymap command for the commands picker
---@param picker_config PickerType
---@return string|nil keymap_cmd, string|nil picker_name
function M.get_commands_keymap(picker_config)
	local picker = M.resolve_picker(picker_config)

	if picker == "snacks" and snacks.is_available() then
		return "<cmd>lua Snacks.picker.pick('uv_commands')<CR>", "snacks"
	end

	if picker == "telescope" and telescope.is_available() then
		return "<cmd>lua require('uv').pick_uv_commands()<CR>", "telescope"
	end

	return nil, nil
end

---Get keymap command for the venv picker
---@param picker_config PickerType
---@return string|nil keymap_cmd, string|nil picker_name
function M.get_venv_keymap(picker_config)
	local picker = M.resolve_picker(picker_config)

	if picker == "snacks" and snacks.is_available() then
		return "<cmd>lua Snacks.picker.pick('uv_venv')<CR>", "snacks"
	end

	if picker == "telescope" and telescope.is_available() then
		return "<cmd>lua require('uv').pick_uv_venv()<CR>", "telescope"
	end

	return nil, nil
end

return M
