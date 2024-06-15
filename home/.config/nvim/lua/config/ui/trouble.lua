require("trouble").setup({
	modes = {
		diagnostics_buffer = {
			mode = "diagnostics", -- inherit from diagnostics mode
			filter = { buf = 0 }, -- filter diagnostics to the current buffer
		},
	},
})
