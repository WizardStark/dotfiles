---@diagnostic disable: missing-fields
require("trouble").setup(
	---@module 'trouble'
	{
		auto_preview = true,
		auto_refresh = false,
		focus = true,
		preview = {
			type = "float",
			relative = "editor",
			border = "rounded",
			title = "Preview",
			title_pos = "center",
			position = { 0.5, 0.5 },
			size = { width = 0.8, height = 0.45 },
			zindex = 200,
		},
		modes = {
			lsp_references = {
				params = {
					include_declaration = true,
				},
			},
			diagnostics_buffer = {
				mode = "diagnostics",
				filter = { buf = 0 },
			},
			cascade = {
				mode = "diagnostics",
				filter = function(items)
					local severity = vim.diagnostic.severity.HINT
					for _, item in ipairs(items) do
						severity = math.min(severity, item.severity)
					end
					return vim.tbl_filter(function(item)
						return item.severity == severity and item.filename:find((vim.loop or vim.uv).cwd(), 1, true)
					end, items)
				end,
			},
		},
	}
)
