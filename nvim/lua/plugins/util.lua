return {
	--sessions
	{
		"coffebar/neovim-project",
		opts = {
			projects = { -- define project roots
				"~/projects/*",
				"~/.config/*",
				"~/workplace/*/src/*",
				"~/code/*",
				"~/dotfiles/",
			},
			session_manager_opts = {
				autosave_ignore_filetypes = {
					"ccc-ui",
					"gitcommit",
					"gitrebase",
					"qf",
				},
			},
			last_session_on_startup = false,
		},
		init = function()
			-- enable saving the state of plugins in the session
			vim.opt.sessionoptions:append("globals") -- save global variables that start with an uppercase letter and contain at least one lowercase letter.
		end,
		dependencies = {
			{ "nvim-lua/plenary.nvim" },
			{ "nvim-telescope/telescope.nvim", tag = "0.1.4" },
			{ "Shatur/neovim-session-manager" },
		},
		lazy = false,
		priority = 100,
	},
	--indent blankline
	{
		"lukas-reineke/indent-blankline.nvim",
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
		keys = {
			{
				"s",
				mode = { "n", "x", "o" },
				function()
					require("flash").jump()
				end,
				desc = "Flash",
			},
			{
				"r",
				mode = "o",
				function()
					require("flash").remote()
				end,
				desc = "Remote Flash",
			},
			{
				"R",
				mode = { "o", "x" },
				function()
					require("flash").treesitter_search()
				end,
				desc = "Treesitter Search",
			},
			{
				"<c-s>",
				mode = { "c" },
				function()
					require("flash").toggle()
				end,
				desc = "Toggle Flash Search",
			},
		},
	},
	-- moving code blocks
	{
		"echasnovski/mini.move",
		event = "VeryLazy",
		version = false,
		opts = {
			mappings = {
				-- Move visual selection in Visual mode. Defaults are Alt (Meta) + hjkl.
				left = "<M-h>",
				right = "<M-l>",
				down = "<M-j>",
				up = "<M-k>",

				-- Move current line in Normal mode
				line_left = "",
				line_right = "",
				line_down = "",
				line_up = "",
			},
		},
	},
	-- surround
	{
		"kylechui/nvim-surround",
		version = "*", -- Use for stability; omit to use `main` branch for the latest features
		event = "VeryLazy",
		config = function()
			require("nvim-surround").setup({
				-- Configuration here, or leave empty to use defaults
			})
		end,
	},
	-- undotree
	{
		"mbbill/undotree",
		event = { "VeryLazy" },
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
		opts = {
			strategy = "toggleterm",
			templates = { "builtin", "user.py_run" },
		},
	},
	--codium
	{
		"Exafunction/codeium.nvim",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"hrsh7th/nvim-cmp",
		},
		config = function()
			require("codeium").setup({})
		end,
	},
}
