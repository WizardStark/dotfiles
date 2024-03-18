return {
	{
		"bluz71/vim-moonfly-colors",
		name = "moonfly",
		lazy = false,
		priority = 1000,
	},
	{
		"catppuccin/nvim",
		name = "catppuccin",
		priority = 1000,
		opts = {
			color_overrides = {
				mocha = {
					green = "#92c48e",
					text = "#94e2d5",
					base = "#080808",
					mantle = "#080808",
					crust = "#080808",
					-- base = "#0e0e0e",
					-- mantle = "#0e0e0e",
					-- crust = "#0e0e0e",
				},
			},
		},
		config = function(_, opts)
			require("catppuccin").setup(opts)
		end,
	},
}
