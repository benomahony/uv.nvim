-- Minimal init.lua for running tests
-- This sets up the runtime path and loads required plugins

local plenary_path = vim.fn.stdpath("data") .. "/lazy/plenary.nvim"

-- Add plenary to runtime path if it exists
if vim.fn.isdirectory(plenary_path) == 1 then
    vim.opt.runtimepath:append(plenary_path)
else
    -- Try alternative locations
    local alt_paths = {
        vim.fn.expand("~/.local/share/nvim/lazy/plenary.nvim"),
        vim.fn.expand("~/.local/share/nvim/site/pack/packer/start/plenary.nvim"),
        vim.fn.expand("~/.local/share/nvim/site/pack/*/start/plenary.nvim"),
    }
    for _, path in ipairs(alt_paths) do
        if vim.fn.isdirectory(path) == 1 then
            vim.opt.runtimepath:append(path)
            break
        end
    end
end

-- Add the plugin itself to runtime path
vim.opt.runtimepath:prepend(vim.fn.getcwd())

-- Set up globals used by tests
vim.g.mapleader = " "

-- Disable some features for cleaner testing
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false
