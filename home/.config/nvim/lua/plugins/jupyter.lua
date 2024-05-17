return {
	{
		"benlubas/molten-nvim",
		ft = { "ipynb", "markdown" },
		version = "^1.0.0", -- use version <2.0.0 to avoid breaking changes
		build = ":UpdateRemotePlugins",
		dependencies = {
			"quarto-dev/quarto-nvim",
		},
		config = function()
			vim.g.molten_output_win_max_height = 40
			-- vim.g.molten_auto_open_output = false
			vim.g.molten_wrap_output = true
			vim.g.molten_virt_text_output = true
			vim.g.molten_virt_lines_off_by_1 = true

			require("jupytext").setup({
				style = "markdown",
				output_extension = "md",
				force_ft = "markdown",
			})
		end,
	},
	{
		"quarto-dev/quarto-nvim",
		ft = { "quarto", "markdown" },
		lazy = true,
		dev = false,
		opts = {
			completion = {
				enabled = true,
			},
			chunks = "all",
			diagnostics = {
				enabled = true,
				triggers = { "BufWritePost" },
			},
			lspFeatures = {
				languages = { "python" },
			},
			codeRunner = {
				enabled = true,
				default_method = "molten",
			},
		},
		dependencies = {
			"jmbuhr/otter.nvim",
		},
	},
	{
		"GCBallesteros/jupytext.nvim",
		config = true,
		lazy = true,
	},
}
