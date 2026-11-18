local opt_path = vim.fn.stdpath("data") .. "/site/pack/test/opt/"
for _, name in ipairs({ "telescope.nvim", "snacks.nvim", "fzf-lua" }) do
	vim.opt.runtimepath:append(opt_path .. name)
end

local original_cwd = vim.fn.getcwd()
local original_path = vim.env.PATH
local original_venv = vim.env.VIRTUAL_ENV

local function in_new_project()
	local dir = vim.fn.tempname() .. "/demo"
	vim.fn.mkdir(dir, "p")
	vim.cmd("cd " .. vim.fn.fnameescape(dir))
	return dir
end

local function setup(picker_integration)
	package.loaded["uv"] = nil
	local uv = require("uv")
	uv.setup({
		auto_commands = false,
		keymaps = false,
		notify_activate_venv = false,
		picker_integration = picker_integration,
	})
	return uv
end

local function wait_for(description, condition)
	assert.is_true(vim.wait(60000, condition, 50), "timed out waiting for " .. description)
end

local function terminal_buffers()
	return vim.tbl_filter(function(buf)
		return vim.bo[buf].buftype == "terminal"
	end, vim.api.nvim_list_bufs())
end

local function buffer_text(buf)
	return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
end

local function wait_for_output(text)
	wait_for("terminal output " .. text, function()
		for _, buf in ipairs(terminal_buffers()) do
			if buffer_text(buf):find(text, 1, true) then
				return true
			end
		end
		return false
	end)
end

local function wait_for_project()
	wait_for("uv init to write pyproject.toml", function()
		return vim.fn.filereadable("pyproject.toml") == 1
	end)
end

describe("e2e", function()
	before_each(function()
		assert.are.equal(1, vim.fn.executable("uv"), "uv must be on PATH to run the e2e tests")
	end)

	after_each(function()
		for _, buf in ipairs(terminal_buffers()) do
			pcall(vim.api.nvim_buf_delete, buf, { force = true })
		end
		vim.cmd("silent! only")
		vim.cmd("cd " .. vim.fn.fnameescape(original_cwd))
		vim.env.PATH = original_path
		vim.env.VIRTUAL_ENV = original_venv
	end)

	describe("uv workflow", function()
		it("creates a project with uv init and activates the venv uv sync makes", function()
			in_new_project()
			local uv = setup(false)
			uv.run_command("uv init --name demo")
			wait_for_project()
			uv.run_command("uv sync")
			wait_for("uv sync to create .venv", function()
				return vim.fn.filereadable(".venv/pyvenv.cfg") == 1
			end)
			assert.is_true(uv.auto_activate_venv())
			assert.are.equal(vim.fn.getcwd() .. "/.venv", vim.env.VIRTUAL_ENV)
		end)

		it("runs the current file with uv", function()
			in_new_project()
			vim.fn.writefile({ 'print("hello from uv.nvim")' }, "main.py")
			vim.cmd("edit main.py")
			setup(false).run_file()
			wait_for_output("hello from uv.nvim")
		end)

		it("runs the only function in the file and prints what it returns", function()
			in_new_project()
			vim.fn.writefile({ "def greet():", '    print("hello from greet")', "    return 42" }, "main.py")
			vim.cmd("edit main.py")
			setup(false).run_python_function()
			wait_for_output("hello from greet")
			wait_for_output("Return value: 42")
		end)

		it("runs a visual selection with the definitions it uses", function()
			in_new_project()
			local uv = setup(false)
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"def get_name() -> str:",
				'    return "Andreas"',
				"",
				"",
				"def print_hello():",
				'    print(f"Hello, {get_name()}")',
				"",
				"BOOM = 1 / 0",
			})
			vim.keymap.set("v", "\\t", uv.run_python_selection)
			vim.api.nvim_feedkeys("6GV\\t", "x", false)
			vim.keymap.del("v", "\\t")
			wait_for_output("Hello, Andreas")
		end)
	end)

	describe("pickers", function()
		it("runs uv init chosen in telescope", function()
			in_new_project()
			setup("telescope").pick_uv_commands()
			local state = require("telescope.actions.state")
			local prompt_bufnr
			wait_for("the telescope prompt", function()
				prompt_bufnr = vim.api.nvim_get_current_buf()
				return vim.bo[prompt_bufnr].filetype == "TelescopePrompt"
			end)
			state.get_current_picker(prompt_bufnr):set_prompt("uv init")
			wait_for("telescope to select uv init", function()
				local entry = state.get_selected_entry()
				return entry ~= nil and entry.value.text == "uv init"
			end)
			for _, keymap in ipairs(vim.api.nvim_buf_get_keymap(prompt_bufnr, "i")) do
				if keymap.lhs == "<CR>" then
					keymap.callback()
				end
			end
			wait_for_project()
		end)

		it("runs uv init chosen in snacks", function()
			in_new_project()
			require("snacks")
			setup("snacks")
			local picker = Snacks.picker.pick("uv_commands", { pattern = "uv init" })
			wait_for("snacks to select uv init", function()
				local item = picker:current()
				return not picker:is_active() and item ~= nil and item.text == "uv init"
			end)
			picker:action("confirm")
			wait_for_project()
		end)

		it("runs uv init typed into fzf", function()
			assert.are.equal(1, vim.fn.executable("fzf"), "fzf must be on PATH to run the fzf-lua e2e test")
			in_new_project()
			setup("fzf-lua").pick_uv_commands()
			local fzf_buf
			wait_for("fzf to list the commands", function()
				for _, buf in ipairs(terminal_buffers()) do
					if buffer_text(buf):find("uv init", 1, true) then
						fzf_buf = buf
						return true
					end
				end
				return false
			end)
			vim.api.nvim_chan_send(vim.bo[fzf_buf].channel, "uv init")
			wait_for("fzf to narrow to one match", function()
				return buffer_text(fzf_buf):find("1/8", 1, true) ~= nil
			end)
			vim.api.nvim_chan_send(vim.bo[fzf_buf].channel, "\r")
			wait_for_project()
		end)

		it("runs uv init chosen from the built in vim.ui.select", function()
			in_new_project()
			local uv = setup("select")
			vim.api.nvim_feedkeys("8\r", "t", false)
			uv.pick_uv_commands()
			wait_for_project()
		end)
	end)
end)
