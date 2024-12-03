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
		event = "UiEnter",
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
		"norcalli/nvim-colorizer.lua",
		cmd = { "ColorizerAttachToBuffer", "ColorizerReloadAllBuffers", "ColorizerDetachFromBuffer", "ColorizerToggle" },
		config = true,
	},
	{
		"gbprod/yanky.nvim",
		event = "VeryLazy",
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
	{
		"echasnovski/mini.splitjoin",
		lazy = true,
		version = false,
		opts = {
			mappings = { toggle = "" },
		},
	},
	{
		"folke/snacks.nvim",
		priority = 1000,
		lazy = false,
		opts = {
			notifier = { enabled = true, timeout = 3000 },
			words = {
				enabled = true,
				debounce = 30,
			},
			rename = { enabled = true },
			statuscolumn = { enabled = true },
			debug = { enabled = true },
			quickfile = {
				enabled = true,
				exclude = { "latex" },
			},
		},
	},
	{ "wakatime/vim-wakatime", lazy = false },
}
