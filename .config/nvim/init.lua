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

if not vim.loop.fs_stat(vim.fn.expand("$HOME/.config/lcl/lua/init.lua")) then
	vim.fn.system(
		"mkdir -p ~/.config/lcl/lua && touch ~/.config/lcl/lua/init.lua && echo M={} return M >> ~/.config/lcl/lua/init.lua"
	)
end

require("lazy").setup({
	spec = { { import = "plugins" }, { import = "config" } },
	ui = { border = "rounded" },
})
