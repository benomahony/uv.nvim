-- Minimal init.lua for running plenary tests
vim.opt.runtimepath:prepend(vim.fn.getcwd())

local plenary_path = vim.fn.stdpath("data") .. "/site/pack/test/start/plenary.nvim"
if vim.fn.isdirectory(plenary_path) == 0 then
	vim.fn.system({ "git", "clone", "https://github.com/nvim-lua/plenary.nvim", plenary_path })
end
vim.opt.runtimepath:append(plenary_path)

local function install_e2e_plugin(repo, ref)
	local path = vim.fn.stdpath("data") .. "/site/pack/test/opt/" .. repo:match("[^/]+$")
	if vim.fn.isdirectory(path) == 1 then
		return
	end
	vim.fn.system({ "git", "init", "-q", path })
	vim.fn.system({ "git", "-C", path, "fetch", "-q", "--depth", "1", "https://github.com/" .. repo, ref })
	vim.fn.system({ "git", "-C", path, "checkout", "-q", "FETCH_HEAD" })
	if vim.v.shell_error ~= 0 then
		vim.fn.delete(path, "rf")
		error("Could not fetch " .. repo .. " at " .. ref .. " into " .. path .. ", check your network and retry")
	end
end

install_e2e_plugin("nvim-telescope/telescope.nvim", "0.1.8")
install_e2e_plugin("folke/snacks.nvim", "v2.31.0")
install_e2e_plugin("ibhagwan/fzf-lua", "82ddfe6efc56480c052fd213e0cbb2f024dfd754")

vim.g.mapleader = " "
vim.opt.swapfile = false
