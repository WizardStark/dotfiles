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
		"--branch=stable", -- latest stable release
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
	{ import = "plugins" },
	{ import = "config" },
	ui = { border = "rounded" },
})

local function loadLCL()
	local ok, lcl = pcall(dofile, vim.fn.expand("$HOME/.config/lcl/lcl.lua"))

	if ok then
		LCL = lcl
	else
		LCL = {}
		vim.notify("No local config found")
	end

	LCL.reload = function()
		vim.notify("Reloading local config")
		loadLCL()
	end
end

loadLCL()
