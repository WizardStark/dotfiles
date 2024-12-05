vim.loader.enable()
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.mapleader = " "
vim.g.maplocalleader = ","

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=v11.14.2",
		-- "--branch=stable",
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

-- lazy load shada
local shada = vim.o.shada
vim.o.shada = ""
vim.api.nvim_create_autocmd("User", {
	pattern = "VeryLazy",
	callback = function()
		vim.o.shada = shada
		pcall(vim.cmd.rshada, { bang = true })
	end,
})

-- setup local entrypoint
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

require("lazy").setup({
	{ import = "plugins" },
	{
		name = "user.init",
		main = "user",
		dir = configpath .. "/lua/user",
		lazy = false,
		config = function()
			require("user")
		end,
	},
	{
		name = "user.options",
		dir = configpath .. "/lua/user/options.lua",
		priority = 100000,
		event = "VimEnter",
		config = function()
			require("user.options").setup()
		end,
	},
	{
		name = "user.ui",
		dir = configpath .. "/lua/user/ui.lua",
		event = "UiEnter",
		config = function()
			require("user.ui").setup()
		end,
	},
	{
		name = "user.autocmds",
		dir = configpath .. "/lua/user/autocmds.lua",
		event = "VeryLazy",
		config = function()
			require("user.autocmds").setup()
		end,
	},
	{
		name = "user.keymaps",
		dir = configpath .. "/lua/user/keymaps.lua",
		event = "VeryLazy",
		config = function()
			require("user.keymaps").setup()
		end,
	},
	{
		name = "user.functions",
		dir = configpath .. "/lua/user/functions.lua",
		event = "VeryLazy",
		config = function()
			require("user.functions").setup()
		end,
	},
	{ import = "lcl.plugins", event = "VeryLazy" },
}, {
	install = {
		colorscheme = { "catppuccin-mocha", "habamax" },
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
	checker = { enabled = false},
	-- debug = true,
})
