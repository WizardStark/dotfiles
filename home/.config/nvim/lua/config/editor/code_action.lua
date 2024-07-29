require("tiny-code-action").setup(
	---@module 'tiny-code-action'
	{
		backend = "delta",
		backend_opts = {
			use_git_config = true,
		},
	}
)
