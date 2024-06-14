return {
	{
		"catppuccin/nvim",
		name = "catppuccin",
		config = true,
	},
	{
		"nvim-lualine/lualine.nvim",
		lazy = true,
		config = function()
			require("config.ui.lualine")
		end,
	},
	{
		"Bekaboo/dropbar.nvim",
		dependencies = {
			"nvim-telescope/telescope-fzf-native.nvim",
		},
	},
	--ufo
	{
		"rcarriga/nvim-notify",
		event = "VeryLazy",
		config = true,
	},
	{
		"smjonas/inc-rename.nvim",
		lazy = true,
		cmd = { "IncRename" },
		config = true,
	},
	{
		"folke/noice.nvim",
		event = "UiEnter",
		dependencies = {
			"MunifTanjim/nui.nvim",
			"rcarriga/nvim-notify",
		},
		config = function()
			require("config.ui.noice")
		end,
	},
	{
		"stevearc/dressing.nvim",
		event = "UiEnter",
		opts = {
			select = {
				get_config = function(opts)
					if opts.kind == "legendary.nvim" then
						return {
							backend = "telescope",
							telescope = require("telescope.themes").get_ivy({}),
						}
					end
				end,
			},
			input = {
				get_config = function(opts)
					if opts.kind == "tabline" then
						return {
							relative = "win",
						}
					end
				end,
			},
		},
	},
	--markdown "rendering"
	{
		"MeanderingProgrammer/markdown.nvim",
		ft = "markdown",
		dependencies = { "nvim-treesitter/nvim-treesitter" },
		config = function()
			require("render-markdown").setup({})
		end,
	},
	--lsp diagnostics
	{
		"folke/trouble.nvim",
		lazy = true,
		dependencies = { "nvim-tree/nvim-web-devicons" },
		opts = {
			modes = {
				diagnostics_buffer = {
					mode = "diagnostics", -- inherit from diagnostics mode
					filter = { buf = 0 }, -- filter diagnostics to the current buffer
				},
			},
		},
	},
	--todo highlighting
	{
		"folke/todo-comments.nvim",
		dependencies = { "nvim-lua/plenary.nvim" },
		opts = {},
	},
	--reactive ui lib
	{
		"grapp-dev/nui-components.nvim",
		dependencies = {
			"MunifTanjim/nui.nvim",
		},
		lazy = true,
	},
	{
		"kwkarlwang/bufresize.nvim",
		config = function()
			require("bufresize").setup({
				register = {
					trigger_events = { "BufWinEnter", "WinEnter" },
					keys = {},
				},
				resize = {
					trigger_events = {
						"VimResized",
					},
					increment = 1,
				},
			})
		end,
	},
}
