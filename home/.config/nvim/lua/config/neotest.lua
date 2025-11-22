require("neotest").setup({
	adapters = {
		require("neotest-python")({
			dap = { justMyCode = false },
			python = require("user.utils").get_python_venv(),
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
		require("neotest-gradle"),
	},
})
