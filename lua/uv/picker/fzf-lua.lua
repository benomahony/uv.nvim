-- fzf-lua picker integration for uv.nvim
-- This is a stub for future implementation
local M = {}

---Check if fzf-lua is available
---@return boolean
function M.is_available()
	local has_fzf = pcall(require, "fzf-lua")
	return has_fzf
end

---Setup fzf-lua picker (not yet implemented)
---@param callbacks table Table with callback functions
---@return boolean success
function M.setup(callbacks)
	if not M.is_available() then
		return false
	end

	-- TODO: Implement fzf-lua picker support
	-- This would register custom pickers similar to telescope/snacks
	vim.notify("fzf-lua picker support is not yet implemented. Using fallback.", vim.log.levels.WARN)
	return false
end

return M
