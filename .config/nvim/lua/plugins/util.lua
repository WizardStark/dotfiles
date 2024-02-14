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
				autoload_mode = config.AutoloadMode.Disabled,
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
	--notes
	{

		"dhananjaylatkar/notes.nvim",
		event = "VeryLazy",
		dependencies = { "nvim-telescope/telescope.nvim" },
		opts = {
			root = vim.fn.expand("$HOME/notes/"),
		},
	},
	--other
	{
		"rgroli/other.nvim",
		event = "VeryLazy",
		config = function()
			require("other-nvim").setup({
				mappings = {
					{
						pattern = ".*/src/(.*)/(.*)",
						target = {
							{ target = ".*/tst/**/%1/%2" },
							{ target = ".*/tst/**/%1/Test_%2" },
						},
					},
					{
						pattern = ".*/tst/.*/(.*)/(.*)",
						target = ".*/src/%1/%2",
					},
					{
						pattern = ".*/tst/.*/(.*)/Test_(.*)",
						target = ".*/src/%1/%2",
					},
				},

				style = {
					border = "rounded",
					seperator = "|",
					newFileIndicator = "(* new *)",
					width = 0.7,
					minHeight = 2,
				},
			})
		end,
	},
}
