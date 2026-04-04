return {
	{
		src = "https://github.com/akinsho/toggleterm.nvim",
		version = "*",
		config = function()
			require("config.terminal.toggleterm")
		end,
	},
	{
		src = "https://github.com/chomosuke/term-edit.nvim",
		version = "1.*",
		config = function()
			require("term-edit").setup({
				prompt_end = "╰─",
				mapping = { n = { s = false } },
			})
		end,
	},
}
