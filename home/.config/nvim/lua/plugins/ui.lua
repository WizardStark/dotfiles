return {
	{
		src = "https://github.com/catppuccin/nvim",
		name = "catppuccin",
		priority = 1000,
		config = function()
			require("catppuccin").setup()
		end,
	},
	{
		src = "https://github.com/nvim-lualine/lualine.nvim",
		event = "UIEnter",
		config = function()
			require("config.ui.lualine")
		end,
	},
	{
		src = "https://github.com/MeanderingProgrammer/render-markdown.nvim",
		config = function()
			require("render-markdown").setup({
				file_types = { "markdown" },
			})
		end,
	},
	{
		src = "https://github.com/folke/trouble.nvim",
		config = function()
			require("config.ui.trouble")
		end,
	},
	{
		src = "https://github.com/echasnovski/mini.icons",
		event = "UIEnter",
		config = function()
			require("mini.icons").setup()
			MiniIcons.mock_nvim_web_devicons()
		end,
	},
	{
		src = "https://github.com/folke/todo-comments.nvim",
		dependencies = { { src = "https://github.com/nvim-lua/plenary.nvim" } },
		config = function()
			require("todo-comments").setup()
		end,
	},
	{
		src = "https://github.com/grapp-dev/nui-components.nvim",
		dependencies = {
			{ src = "https://github.com/MunifTanjim/nui.nvim" },
		},
	},
	{
		src = "https://github.com/kwkarlwang/bufresize.nvim",
		config = function()
			require("config.ui.bufresize")
		end,
	},
	{
		src = "https://github.com/b0o/incline.nvim",
		dependencies = { { src = "https://github.com/echasnovski/mini.icons" } },
		config = function()
			require("config.ui.incline")
		end,
	},
	{
		src = "https://github.com/xzbdmw/colorful-menu.nvim",
		config = function()
			require("colorful-menu").setup({})
		end,
	},
	{
		src = "https://github.com/stevearc/quicker.nvim",
		---@module "quicker"
		---@type quicker.SetupOptions
		config = function()
			require("quicker").setup({})
		end,
	},
}
