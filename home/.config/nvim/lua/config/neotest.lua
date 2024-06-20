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
		require("neotest-gradle"),
	},
})
