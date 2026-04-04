return {
	{
		src = "https://github.com/nvim-neotest/neotest",
		dependencies = {
			{ src = "https://github.com/nvim-lua/plenary.nvim" },
			{ src = "https://github.com/nvim-treesitter/nvim-treesitter" },
			{ src = "https://github.com/nvim-neotest/neotest-python" },
			{ src = "https://github.com/nvim-neotest/neotest-go" },
			{ src = "https://github.com/rcasia/neotest-java" },
			{ src = "https://github.com/nvim-neotest/neotest-vim-test" },
			{ src = "https://github.com/nvim-neotest/nvim-nio" },
			{ src = "https://github.com/weilbith/neotest-gradle" },
		},
		config = function()
			require("config.neotest")
		end,
	},
	{
		src = "https://github.com/andythigpen/nvim-coverage",
		config = function()
			require("coverage").setup()
		end,
	},
}
