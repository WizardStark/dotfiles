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
		"--branch=stable",
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

-- lazy load shada and rplugin (this is such an unnecessary 'optimisation')
vim.api.nvim_create_autocmd("User", {
	pattern = "VeryLazy",
	callback = function()
		vim.o.shada = vim.o.shada .. ",:100"
		pcall(vim.cmd.rshada, { bang = true })
		pcall(vim.cmd.source, vim.fn.stdpath("data") .. "/rplugin.vim")
		pcall(vim.cmd.source, "runtime/plugin/editorconfig.vim")
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
			require("user.init").setup()
			require("user.options").setup()
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
				"editorconfig",
				"shada",
				"rplugin",
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
	checker = { enabled = false },
	-- debug = true,
})
