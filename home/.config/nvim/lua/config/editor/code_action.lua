require("tiny-code-action").setup(
	---@module 'tiny-code-action'
	{
		backend = "delta",
		backend_opts = {
			delta = {
				args = {
					"--config=" .. os.getenv("HOME") .. "/.config/delta/delta.config",
					"--width=" .. vim.fn.round(0.69 * vim.o.columns),
				},
			},
		},
	}
)
