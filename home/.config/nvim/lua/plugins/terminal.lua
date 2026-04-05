return {
	{
		src = "https://github.com/akinsho/toggleterm.nvim",
		config = function()
			require("config.terminal.toggleterm")
		end,
	},
	{
		src = "https://github.com/chomosuke/term-edit.nvim",
		config = function()
			require("term-edit").setup({
				prompt_end = "╰─",
				mapping = { n = { s = false } },
			})
		end,
	},
}
