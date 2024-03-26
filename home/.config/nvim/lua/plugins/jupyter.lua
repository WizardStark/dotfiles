return {
	{
		"benlubas/molten-nvim",
		ft = "ipynb",
		version = "^1.0.0", -- use version <2.0.0 to avoid breaking changes
		build = ":UpdateRemotePlugins",
		config = function()
			vim.g.molten_output_win_max_height = 40
		end,
	},
}
