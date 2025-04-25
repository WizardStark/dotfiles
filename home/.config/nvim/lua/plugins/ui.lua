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
		config = function()
			require("config.ui.dropbar")
		end,
	},
	{
		"folke/noice.nvim",
		event = "UiEnter",
		dependencies = {
			"MunifTanjim/nui.nvim",
		},
		config = function()
			require("config.ui.noice")
		end,
	},
	{
		"MeanderingProgrammer/render-markdown.nvim",
		opts = {
			file_types = { "markdown", "Avante" },
		},
		ft = { "markdown", "Avante" },
	},
	{
		"folke/trouble.nvim",
		lazy = true,
		cmd = "Trouble",
		config = function()
			require("config.ui.trouble")
		end,
	},
	{
		"echasnovski/mini.icons",
		lazy = true,
		config = function()
			require("mini.icons").setup()
			MiniIcons.mock_nvim_web_devicons()
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
		event = "UiEnter",
		config = function()
			require("config.ui.bufresize")
		end,
	},
	{
		"b0o/incline.nvim",
		event = "UiEnter",
		dependencies = "echasnovski/mini.icons",
		config = function()
			require("config.ui.incline")
		end,
	},
	{
		"mistricky/codesnap.nvim",
		build = "make",
		event = "VeryLazy",
		cmd = { "CodeSnap", "CodeSnapSave", "CodeSnapASCII" },
		lazy = true,
		config = function()
			require("config.ui.codesnap")
		end,
	},
	{
		"mistweaverco/kulala.nvim",
		lazy = true,
		config = function()
			require("kulala").setup()
		end,
	},
	{
		"xzbdmw/colorful-menu.nvim",
		event = { "InsertEnter", "CmdlineEnter" },
		opts = {},
	},
}
