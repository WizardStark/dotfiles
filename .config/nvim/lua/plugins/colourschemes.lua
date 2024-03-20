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
					crust = "#1e1e2e",
					base = "#0e0e1e",
					mantle = "#101018",
				},
			},
		},
		config = function(_, opts)
			require("catppuccin").setup(opts)
		end,
	},
}
