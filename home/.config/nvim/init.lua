-- disable netrw at the very start of your init.lua
vim.loader.enable()
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

local shada = vim.o.shada
vim.o.shada = ""
vim.api.nvim_create_autocmd("User", {
	pattern = "VeryLazy",
	callback = function()
		vim.o.shada = shada
		pcall(vim.cmd.rshada, { bang = true })
	end,
})

local configpath = vim.fn.stdpath("config") --[[@as string]]
vim.g.lclpath = configpath .. "/lua/lcl"
vim.g.lclfilepath = vim.g.lclpath .. "/options.lua"
vim.g.backdrop_buf = nil
vim.g.backdrop_win = nil
vim.g.colorscheme = "catppuccin-mocha"

if not vim.loop.fs_stat(vim.g.lclpath) then
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
	{ import = "plugins" },
	{
		name = "user.init",
		main = "user",
		dir = configpath,
		lazy = false,
		config = function()
			require("user")
		end,
	},
	{
		name = "user.options",
		main = "user.options",
		dir = configpath,
		priority = 100000,
		event = "VimEnter",
		config = true,
	},
	{
		name = "user.ui",
		main = "user.ui",
		dir = configpath,
		event = "VeryLazy",
		config = true,
	},
	{
		name = "user.autocmds",
		main = "user.autocmds",
		dir = configpath,
		event = "VeryLazy",
		config = true,
	},
	{
		name = "user.keymaps",
		main = "user.keymaps",
		dir = configpath,
		event = "VeryLazy",
		config = true,
	},
	{
		name = "user.functions",
		main = "user.functions",
		dir = configpath,
		event = "VeryLazy",
		config = true,
	},
}, {
	install = {
		colorscheme = { "habamax" },
	},
	ui = {
		border = "rounded",
	},
	diff = {
		cmd = "diffview.nvim",
	},
	-- profiling = {
	-- 	loader = true,
	-- 	require = true,
	-- },
	performance = {
		cache = {
			enabled = true,
			disable_events = { "UiEnter" },
		},
		reset_packpath = true,
		rtp = {
			reset = true,
			disabled_plugins = {
				"gzip",
				"matchit",
				"matchparen",
				"netrwPlugin",
				"tarPlugin",
				"tohtml",
				"tutor",
				"zipPlugin",
				"man",
				"osc52",
				"spellfile",
			},
		},
	},
})
