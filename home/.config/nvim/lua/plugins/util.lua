return {
	-- surround
	{
		src = "https://github.com/nvim-mini/mini.surround",
		config = function()
			require("mini.surround").setup()
		end,
	},
	{
		src = "https://github.com/nvim-mini/mini.ai",
		config = function()
			require("mini.ai").setup()
		end,
	},
	--toggle booleans
	{
		src = "https://github.com/rmagatti/alternate-toggler",
		packadd_bang = true,
		config = function()
			require("alternate-toggler").setup({})
		end,
	},
	{
		src = "https://github.com/stevearc/stickybuf.nvim",
		config = function()
			require("stickybuf").setup({
				get_auto_pin = function(bufnr)
					if vim.bo[bufnr].filetype == "minifiles" then
						return "buftype"
					end
					return require("stickybuf").should_auto_pin(bufnr)
				end,
			})
		end,
	},
	{
		src = "https://github.com/briangwaltney/paren-hint.nvim",
		dependencies = {
			{ src = "https://github.com/nvim-treesitter/nvim-treesitter" },
		},
		config = function()
			require("paren-hint").setup()
		end,
	},
	{
		src = "https://github.com/gbprod/substitute.nvim",
		config = function()
			require("substitute").setup()
		end,
	},
	{
		src = "https://github.com/chrisgrieser/nvim-recorder",
		config = function()
			require("recorder").setup({
				slots = { "a", "r", "s", "m" },
				mapping = {
					switchSlot = "<C-S-q>",
				},
			})
		end,
	},
	{
		src = "https://github.com/NStefan002/screenkey.nvim",
		version = "*",
		config = function()
			require("screenkey").setup({
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
			})
		end,
	},
	{
		src = "https://github.com/MagicDuck/grug-far.nvim",
		config = function()
			require("grug-far").setup()
		end,
	},
	{
		src = "https://github.com/folke/ts-comments.nvim",
		config = function()
			require("ts-comments").setup()
		end,
	},
	{
		src = "https://github.com/echasnovski/mini.splitjoin",
		config = function()
			require("mini.splitjoin").setup({
				mappings = { toggle = "" },
			})
		end,
	},
	{
		src = "https://github.com/folke/snacks.nvim",
		event = "UiEnter",
		config = function()
			require("config.editor.snacks")
		end,
	},
	{
		src = "https://github.com/nvimtools/hydra.nvim",
	},
}
