return {
	--sessions
	{
		"Shatur/neovim-session-manager",
		dependencies = {
			"nvim-lua/plenary.nvim",
		},
		config = function()
			local config = require("session_manager.config")
			require("session_manager").setup({
				autoload_mode = config.AutoloadMode.CurrentDir,
			})
		end,
	},
	--indent blankline
	{
		"lukas-reineke/indent-blankline.nvim",
		event = "VeryLazy",
		main = "ibl",
		opts = {
			indent = {
				char = "│",
			},
			scope = {
				show_start = false,
				show_end = false,
			},
		},
	},
	-- Quick navigation
	{
		"folke/flash.nvim",
		event = "VeryLazy",
		opts = {
			modes = {
				search = {
					enabled = false,
				},
			},
		},
	},
	-- surround
	{
		"kylechui/nvim-surround",
		version = "*", -- Use for stability; omit to use `main` branch for the latest features
		event = "VeryLazy",
		opts = {},
	},
	-- undotree
	{
		"mbbill/undotree",
		event = "VeryLazy",
	},
	--smart splits
	{
		"mrjones2014/smart-splits.nvim",
		event = "VeryLazy",
		opts = {},
	},
	--toggle booleans
	{
		"rmagatti/alternate-toggler",
		event = "VeryLazy",
		opts = {},
	},
	--mutli-cursor
	{
		"brenton-leighton/multiple-cursors.nvim",
		event = "VeryLazy",
		opts = {},
	},
	--more text objects
	{
		"chrisgrieser/nvim-various-textobjs",
		event = "VeryLazy",
		opts = { useDefaultKeymaps = true },
	},
	--overseer
	{
		"stevearc/overseer.nvim",
		event = "VeryLazy",
		opts = {
			strategy = "toggleterm",
			templates = { "builtin", "user.py_run" },
		},
	},
	--codium
	{
		"Exafunction/codeium.nvim",
		event = "VeryLazy",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"hrsh7th/nvim-cmp",
		},
		config = function()
			require("codeium").setup({})
		end,
	},
	--bookmarks
	{
		"tomasky/bookmarks.nvim",
		opts = {
			sign_priority = 8,
		},
	},
	--tabout
	{
		"kawre/neotab.nvim",
		event = "InsertEnter",
		opts = {},
	},
	--snippet creation
	{
		"chrisgrieser/nvim-scissors",
		event = "VeryLazy",
		dependencies = "nvim-telescope/telescope.nvim", -- optional
		opts = {},
	},
	--open links
	{

		"chrishrb/gx.nvim",
		cmd = { "Browse" },
		dependencies = { "nvim-lua/plenary.nvim" },
		config = true,
		init = function()
			vim.g.netrw_nogx = 1
		end,
	},
	{

		"dhananjaylatkar/notes.nvim",
		event = "VeryLazy",
		dependencies = { "nvim-telescope/telescope.nvim" },
		opts = {
			root = vim.fn.expand("$HOME/notes/"),
		},
	},
}
