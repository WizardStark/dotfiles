-- disable netrw at the very start of your init.lua
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.mapleader = " "

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable",
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

local configpath = vim.fn.resolve(vim.fn.stdpath("config") .. "/lua")
vim.g.lclpath = configpath .. "/lcl"
vim.g.lclfilepath = vim.g.lclpath .. "/options.lua"
vim.g.backdrop_buf = nil
vim.g.backdrop_win = nil

if not vim.loop.fs_stat(vim.fn.resolve(vim.fn.stdpath("config") .. "/lua/lcl")) then
	vim.fn.system(
		"mkdir -p "
			.. vim.g.lclpath
			.. " && touch "
			.. vim.g.lclfilepath
			.. " && echo M={} return M >> "
			.. vim.g.lclfilepath
	)
end

require("lazy").setup({
	spec = { { import = "plugins" }, { import = "lcl" }, { import = "config" } },
	install = { colorscheme = { "catppuccin-mocha", "habamax" } },
	ui = { border = "rounded" },
	profiling = { loader = true, require = true },
})
