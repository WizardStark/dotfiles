return {
	name = "py run",
	builder = function()
		local file = vim.fn.expand("%:p")
		return {
			cmd = { "python3" },
			args = { file },
			components = { { "on_output_summarize" }, "default" },
		}
	end,
	condition = {
		filetype = { "python" },
	},
}
