local uv = require("uv")

describe("remove_package", function()
	it("sets up keymap when enabled", function()
		uv.setup({ keymaps = { prefix = "<leader>u", remove_package = true } })

		local keymaps = vim.api.nvim_get_keymap("n")
		local found = false
		for _, km in ipairs(keymaps) do
			if km.desc == "UV Remove Package" then
				found = true
				assert.is_truthy(km.rhs:match("remove_package") or km.callback)
				break
			end
		end
		assert.is_true(found, "should have remove_package keymap defined")
	end)
end)
