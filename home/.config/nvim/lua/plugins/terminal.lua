return {
	{
		"akinsho/toggleterm.nvim",
		cmd = "ToggleTerm",
		version = "*",
		config = function()
			require("config.terminal.toggleterm")
		end,
	},
	{
		"chomosuke/term-edit.nvim",
		ft = "toggleterm",
		version = "1.*",
		opts = {
			prompt_end = "╰─",
			mapping = { n = { s = false } },
		},
	},
	{
		"stevearc/overseer.nvim",
		cmd = { "OverseerRun", "OverseerToggle" },
		config = function()
			require("config.terminal.overseer")
		end,
	},
}
