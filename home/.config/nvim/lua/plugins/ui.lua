return {
	{
		"catppuccin/nvim",
		name = "catppuccin",
		priority = true,
		lazy = true,
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
		event = "UiEnter",
		dependencies = {
			"nvim-telescope/telescope-fzf-native.nvim",
		},
		config = function()
			require("config.ui.dropbar")
		end,
	},
	{
		"rcarriga/nvim-notify",
		config = true,
		event = "UiEnter",
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
		config = function()
			require("config.ui.dressing")
		end,
	},
	{
		"MeanderingProgrammer/markdown.nvim",
		ft = "markdown",
		dependencies = { "nvim-treesitter/nvim-treesitter" },
		config = function()
			require("render-markdown").setup({})
		end,
	},
	{
		"folke/trouble.nvim",
		lazy = true,
		dependencies = { "nvim-tree/nvim-web-devicons" },
		config = function()
			require("config.ui.trouble")
		end,
	},
	{
		"folke/todo-comments.nvim",
		event = "UiEnter",
		dependencies = { "nvim-lua/plenary.nvim" },
		config = true,
	},
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
			require("config.ui.bufresize")
		end,
	},
}
