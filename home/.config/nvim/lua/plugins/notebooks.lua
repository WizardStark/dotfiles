return {
	{
		"benlubas/molten-nvim",
		ft = { "ipynb", "markdown" },
		version = "^1.0.0",
		build = ":UpdateRemotePlugins",
		dependencies = {
			{
				"quarto-dev/quarto-nvim",
				ft = { "quarto", "markdown" },
				lazy = true,
				dev = false,
				dependencies = {
					"jmbuhr/otter.nvim",
				},
			},
			"GCBallesteros/jupytext.nvim",
		},
		config = function()
			require("config.notebooks")
		end,
	},
}
