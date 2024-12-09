require("trouble").setup(
	---@module 'trouble'
	{
		auto_preview = false,
		auto_refresh = false,
		focus = true,
		modes = {
			lsp_references = {
				params = {
					include_declaration = true,
				},
			},
			diagnostics_buffer = {
				mode = "diagnostics", -- inherit from diagnostics mode
				filter = { buf = 0 }, -- filter diagnostics to the current buffer
			},
			wsdiags = {
				mode = "diagnostics", -- inherit from diagnostics mode
				filter = {
					any = {
						buf = 0, -- current buffer
						{
							severity = vim.diagnostic.severity.ERROR,
							function(item)
								return item.filename:find((vim.loop or vim.uv).cwd(), 1, true)
							end,
						},
					},
				},
			},
		},
	}
)
