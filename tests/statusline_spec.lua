local uv = require("uv")

local original_venv = vim.env.VIRTUAL_ENV
local test_dir = vim.fn.tempname()
vim.fn.mkdir(test_dir, "p")

local function create_test_venv(venv_name, prompt)
	local venv_dir = test_dir .. "/" .. venv_name
	vim.fn.mkdir(venv_dir, "p")

	local pyvenv_cfg = venv_dir .. "/pyvenv.cfg"
	local file = io.open(pyvenv_cfg, "w")
	file:write("home = /usr/bin\n")
	file:write("include-system-site-packages = false\n")
	if prompt then
		file:write("prompt = " .. prompt .. "\n")
	end
	file:close()

	return venv_dir
end

describe("is_venv_active()", function()
	after_each(function()
		vim.env.VIRTUAL_ENV = original_venv
	end)

	it("returns false when no venv is active", function()
		vim.env.VIRTUAL_ENV = nil
		assert.is_false(uv.is_venv_active())
	end)

	it("returns true when a venv is active", function()
		vim.env.VIRTUAL_ENV = test_dir .. "/some-project/.venv"
		assert.is_true(uv.is_venv_active())
	end)
end)

describe("get_venv()", function()
	after_each(function()
		vim.env.VIRTUAL_ENV = original_venv
	end)

	it("returns nil when no venv is active", function()
		vim.env.VIRTUAL_ENV = nil
		assert.is_nil(uv.get_venv())
	end)

	it("returns prompt from pyvenv.cfg", function()
		local venv_path = create_test_venv("test-venv", "my-awesome-project")
		vim.env.VIRTUAL_ENV = venv_path
		assert.are.equal("my-awesome-project", uv.get_venv())
	end)

	it("returns venv folder name when no prompt in pyvenv.cfg", function()
		local venv_path = create_test_venv("custom-env", nil)
		vim.env.VIRTUAL_ENV = venv_path
		assert.are.equal("custom-env", uv.get_venv())
	end)

	it("returns venv folder name when no pyvenv.cfg exists", function()
		local venv_dir = test_dir .. "/no-cfg"
		vim.fn.mkdir(venv_dir, "p")
		vim.env.VIRTUAL_ENV = venv_dir
		assert.are.equal("no-cfg", uv.get_venv())
	end)
end)

describe("get_venv_path()", function()
	after_each(function()
		vim.env.VIRTUAL_ENV = original_venv
	end)

	it("returns nil when no venv is active", function()
		vim.env.VIRTUAL_ENV = nil
		assert.is_nil(uv.get_venv_path())
	end)

	it("returns the full venv path when active", function()
		local expected_path = test_dir .. "/test-project/.venv"
		vim.fn.mkdir(expected_path, "p")
		vim.env.VIRTUAL_ENV = expected_path
		assert.are.equal(expected_path, uv.get_venv_path())
	end)
end)

-- Cleanup at end
vim.env.VIRTUAL_ENV = original_venv
vim.fn.delete(test_dir, "rf")
