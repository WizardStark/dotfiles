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
		},
		config = function()
			require("neotest").setup({
				adapters = {
					require("neotest-python")({
						dap = { justMyCode = false },
					}),
					require("neotest-go")({
						experimental = {
							test_table = true,
						},
						args = { "-count=1", "-timeout=60s" },
					}),
					require("neotest-java")({
						ignore_wrapper = false, -- whether to ignore maven/gradle wrapper
					}),
					require("neotest-vim-test")({
						ignore_file_types = { "python", "vim", "lua", "go", "java" },
					}),
				},
			})
		end,
	},
	{
		"andythigpen/nvim-coverage",
		cmd = { "CoverageShow", "CoverageHide", "CoverageLoad", "CoverageSummary" },
		opts = {},
	},
}
