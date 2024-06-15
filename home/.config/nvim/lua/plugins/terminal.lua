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
		"willothy/flatten.nvim",
		lazy = false,
		priority = 1001,
		config = function()
			require("config.terminal.flatten")
		end,
	},
	{
		"Zeioth/compiler.nvim",
		cmd = { "CompilerOpen", "CompilerToggleResults", "CompilerRedo" },
		dependencies = {
			{
				"stevearc/overseer.nvim",
				cmd = { "CompilerOpen", "CompilerToggleResults", "CompilerRedo" },
				config = function()
					require("config.terminal.overseer")
				end,
			},
		},
		config = true,
	},
}
