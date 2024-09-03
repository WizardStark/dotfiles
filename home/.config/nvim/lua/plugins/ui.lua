return {
	{
		"catppuccin/nvim",
		name = "catppuccin",
		priority = true,
		lazy = true,
		config = true,
	},
	{
		"OXY2DEV/bars-N-lines.nvim",
		lazy = false,
		config = function()
			require("config.ui.status")
		end,
	},
	-- {
	-- 	"nvim-lualine/lualine.nvim",
	-- 	lazy = true,
	-- 	config = function()
	-- 		require("config.ui.lualine")
	-- 	end,
	-- },
	-- {
	-- 	"Bekaboo/dropbar.nvim",
	-- 	event = "UiEnter",
	-- 	dependencies = {
	-- 		"nvim-telescope/telescope-fzf-native.nvim",
	-- 	},
	-- 	config = function()
	-- 		require("config.ui.dropbar")
	-- 	end,
	-- },
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
		version = "4.4.7",
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
		"folke/edgy.nvim",
		event = "VeryLazy",
		config = function()
			require("config.ui.edgy")
		end,
	},
	-- {
	-- 	"b0o/incline.nvim",
	-- 	event = "VeryLazy",
	-- 	dependencies = "echasnovski/mini.icons",
	-- 	config = function()
	-- 		require("config.ui.incline")
	-- 	end,
	-- },
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
}
