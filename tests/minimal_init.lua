-- Minimal init.lua for running plenary tests
vim.opt.runtimepath:prepend(vim.fn.getcwd())

local plenary_path = vim.fn.stdpath("data") .. "/site/pack/test/start/plenary.nvim"
if vim.fn.isdirectory(plenary_path) == 0 then
	vim.fn.system({ "git", "clone", "https://github.com/nvim-lua/plenary.nvim", plenary_path })
end
vim.opt.runtimepath:append(plenary_path)

vim.g.mapleader = " "
vim.opt.swapfile = false
