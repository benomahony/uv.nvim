-- Tests for picker configuration module
local picker_config = require("uv.picker.config")

describe("picker.config", function()
	describe("valid picker values", function()
		it("accepts 'auto' as valid picker", function()
			assert.is_true(picker_config.is_valid("auto"))
		end)

		it("accepts 'snacks' as valid picker", function()
			assert.is_true(picker_config.is_valid("snacks"))
		end)

		it("accepts 'telescope' as valid picker", function()
			assert.is_true(picker_config.is_valid("telescope"))
		end)

		it("accepts 'fzf-lua' as valid picker", function()
			assert.is_true(picker_config.is_valid("fzf-lua"))
		end)

		it("accepts false to disable picker", function()
			assert.is_true(picker_config.is_valid(false))
		end)

		it("rejects invalid string values", function()
			assert.is_false(picker_config.is_valid("invalid"))
			assert.is_false(picker_config.is_valid(""))
		end)

		it("rejects invalid types", function()
			assert.is_false(picker_config.is_valid(123))
			assert.is_false(picker_config.is_valid({}))
			assert.is_false(picker_config.is_valid(nil))
		end)

		-- Backwards compatibility: true should be treated as "auto"
		it("accepts true for backwards compatibility (treated as auto)", function()
			assert.is_true(picker_config.is_valid(true))
		end)
	end)

	describe("normalize", function()
		it("returns auto unchanged", function()
			assert.are.equal("auto", picker_config.normalize("auto"))
		end)

		it("returns snacks unchanged", function()
			assert.are.equal("snacks", picker_config.normalize("snacks"))
		end)

		it("returns telescope unchanged", function()
			assert.are.equal("telescope", picker_config.normalize("telescope"))
		end)

		it("returns fzf-lua unchanged", function()
			assert.are.equal("fzf-lua", picker_config.normalize("fzf-lua"))
		end)

		it("converts true to auto for backwards compatibility", function()
			assert.are.equal("auto", picker_config.normalize(true))
		end)

		it("returns false unchanged (disabled)", function()
			assert.is_false(picker_config.normalize(false))
		end)

		it("defaults to auto for invalid values", function()
			assert.are.equal("auto", picker_config.normalize("invalid"))
			assert.are.equal("auto", picker_config.normalize(nil))
			assert.are.equal("auto", picker_config.normalize(123))
		end)
	end)

	describe("get_available_pickers", function()
		it("returns a table", function()
			local available = picker_config.get_available_pickers()
			assert.is_table(available)
		end)
	end)
end)
