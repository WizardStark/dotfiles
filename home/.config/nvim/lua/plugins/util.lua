return {
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
					return "buftype"
				end
				return require("stickybuf").should_auto_pin(bufnr)
			end,
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
		opts = {
			slots = { "a", "r", "s", "m" },
			mapping = {
				switchSlot = "<C-S-q>",
			},
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
		event = "UiEnter",
		config = function()
			require("config.editor.snacks")
		end,
	},
	{
		"nvimtools/hydra.nvim",
		lazy = true,
	},
}
