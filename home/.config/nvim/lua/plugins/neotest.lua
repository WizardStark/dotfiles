return {
	{
		"nvim-neotest/neotest",
		cmd = { "Neotest" },
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-treesitter/nvim-treesitter",
			"nvim-neotest/neotest-python",
			"nvim-neotest/neotest-go",
			"rcasia/neotest-java",
			"nvim-neotest/neotest-vim-test",
			"nvim-neotest/nvim-nio",
			"weilbith/neotest-gradle",
		},
		config = function()
			require("config.neotest")
		end,
	},
	{
		"andythigpen/nvim-coverage",
		cmd = { "CoverageShow", "CoverageHide", "CoverageLoad", "CoverageSummary" },
		config = true,
	},
}
