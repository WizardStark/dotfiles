vim.loader.enable()
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

require("user.cmdline").setup()

vim.api.nvim_create_autocmd("User", {
	pattern = "VeryLazy",
	callback = function()
		vim.o.shada = vim.o.shada .. ",:100"
		pcall(vim.cmd.rshada, { bang = true })
		pcall(vim.cmd.source, "runtime/plugin/editorconfig.vim")
	end,
})

local configpath = vim.fn.stdpath("config") --[[@as string]]
vim.g.lclpath = configpath .. "/lua/lcl"

if not vim.loop.fs_stat(vim.g.lclpath) then
	vim.fn.system(
		"mkdir -p "
			.. vim.g.lclpath
			.. " && touch "
			.. (vim.g.lclpath .. "/options.lua")
			.. " && echo M={} return M >> "
			.. (vim.g.lclpath .. "/options.lua")
	)
end

if not vim.loop.fs_stat(vim.g.lclpath .. "/plugins") then
	vim.notify("in the plugin creation thing")
	vim.fn.system(
		"mkdir -p "
			.. (vim.g.lclpath .. "/plugins")
			.. " && touch "
			.. (vim.g.lclpath .. "/plugins/plugins.lua")
			.. " && echo return {} >> "
			.. (vim.g.lclpath .. "/plugins/plugins.lua")
	)
end

vim.g.backdrop_buf = nil
vim.g.backdrop_win = nil
vim.g.colorscheme = "catppuccin-mocha"

require("user.pack").setup({
	spec = {
		{ import = "plugins" },
		{ import = "lcl.plugins" },
	},
})

require("user.options").setup()
require("user.init").setup()
