return {
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
	-- surround
	{
		"kylechui/nvim-surround",
		version = "*",
		event = "VeryLazy",
		config = true,
	},
	-- undotree
	{
		"mbbill/undotree",
		lazy = true,
	},
	--toggle booleans
	{
		"rmagatti/alternate-toggler",
		lazy = true,
		config = true,
	},
	--overseer tasks
	{
		"stevearc/stickybuf.nvim",
		event = "VeryLazy",
		opts = {
			get_auto_pin = function(bufnr)
				if vim.bo[bufnr].filetype == "minifiles" then
					return "filetype"
				end
				return require("stickybuf").should_auto_pin(bufnr)
			end,
		},
	},
	{
		"chrishrb/gx.nvim",
		cmd = { "Browse" },
		dependencies = { "nvim-lua/plenary.nvim" },
		init = function()
			vim.g.netrw_nogx = 1
		end,
		config = function()
			local app
			if vim.fn.has("mac") then
				app = "open"
			elseif vim.fn.has("wsl") then
				app = "wslview"
			else
				app = "xdg-open"
			end
			require("gx").setup({
				open_browser_app = app,
			})
		end,
	},
	{

		"dhananjaylatkar/notes.nvim",
		cmd = { "NotesNew", "NotesFind", "NotesGrep" },
		dependencies = { "nvim-telescope/telescope.nvim" },
		opts = {
			root = vim.fn.expand("$HOME/notes/"),
		},
	},
	{
		"mrjones2014/legendary.nvim",
		priority = 10000,
		lazy = false,
		dependencies = { "stevearc/dressing.nvim" },
		config = function()
			require("legendary").setup({
				select_prompt = " Command palette",
				sort = {
					frecency = false,
				},
			})
		end,
	},
	{
		"thunder-coding/zincoxide",
		lazy = true,
		cmd = { "Z", "Zg", "Zt", "Zw" },
		opts = {
			zincoxide_cmd = "zoxide",
			complete = true,
			behaviour = "tabs",
		},
	},
	{
		"briangwaltney/paren-hint.nvim",
		event = "VeryLazy",
		dependencies = {
			"nvim-treesitter/nvim-treesitter",
		},
		config = true,
	},
	{
		"gbprod/substitute.nvim",
		lazy = true,
		config = true,
	},
	{
		"chrisgrieser/nvim-recorder",
		lazy = true,
		dependencies = "rcarriga/nvim-notify",
		opts = {
			slots = { "a", "r", "s", "m" },
		},
	},
	{
		"rrethy/vim-illuminate",
		event = "VeryLazy",
		config = function()
			require("illuminate").configure({
				delay = 20,
				large_file_cutoff = 10000,
				min_count_to_highlight = 2,
				filetypes_denylist = {
					"minifiles",
				},
			})
		end,
	},
	{
		"norcalli/nvim-colorizer.lua",
		cmd = { "ColorizerAttachToBuffer", "ColorizerReloadAllBuffers", "ColorizerDetachFromBuffer", "ColorizerToggle" },
		config = true,
	},
	{
		"gbprod/yanky.nvim",
		opts = {
			highlight = {
				timer = 350,
			},
		},
	},
	{
		"NStefan002/screenkey.nvim",
		cmd = "Screenkey",
		lazy = true,
		version = "*",
		opts = {
			win_opts = {
				relative = "editor",
				anchor = "SE",
				width = 60,
				height = 3,
				border = "single",
			},
			compress_after = 3,
			clear_after = 60,
			disable = {
				filetypes = { "toggleterm" },
				buftypes = { "terminal" },
			},
		},
	},
	{
		"MagicDuck/grug-far.nvim",
		lazy = true,
		config = true,
	},
	{
		"folke/ts-comments.nvim",
		event = "VeryLazy",
		config = true,
	},
}
