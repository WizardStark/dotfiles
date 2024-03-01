return {
	name = "go run",
	builder = function()
		return {
			cmd = { "go" },
			args = { "run", "." },
			components = { { "on_output_summarize" }, "default" },
		}
	end,
	condition = {
		filetype = { "go" },
	},
}
