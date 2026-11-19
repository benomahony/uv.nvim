-- Picker configuration module
-- Handles validation and normalization of picker_integration config

local M = {}

---@alias PickerType "auto"|"snacks"|"telescope"|"fzf-lua"|false

-- Valid picker values
local VALID_PICKERS = {
	["auto"] = true,
	["snacks"] = true,
	["telescope"] = true,
	["fzf-lua"] = true,
}

---Check if a value is a valid picker configuration
---@param value any
---@return boolean
function M.is_valid(value)
	if value == false then
		return true
	end
	if value == true then
		return true -- backwards compatibility
	end
	if type(value) ~= "string" then
		return false
	end
	return VALID_PICKERS[value] == true
end

---Normalize picker configuration value
---Converts legacy boolean true to "auto", handles invalid values
---@param value any
---@return PickerType
function M.normalize(value)
	if value == false then
		return false
	end
	if value == true then
		return "auto" -- backwards compatibility
	end
	if type(value) == "string" and VALID_PICKERS[value] then
		return value
	end
	return "auto" -- default for invalid values
end

---Check which pickers are available in the current environment
---@return table<string, boolean>
function M.get_available_pickers()
	local available = {}

	-- Check for Snacks
	if _G.Snacks and _G.Snacks.picker then
		available.snacks = true
	end

	-- Check for Telescope
	local has_telescope = pcall(require, "telescope")
	if has_telescope then
		available.telescope = true
	end

	-- Check for fzf-lua
	local has_fzf = pcall(require, "fzf-lua")
	if has_fzf then
		available["fzf-lua"] = true
	end

	return available
end

return M
