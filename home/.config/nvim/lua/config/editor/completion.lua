local cmp = require("cmp")
local window_scroll_bordered = cmp.config.window.bordered({
	scrolloff = 3,
	scrollbar = true,
})
-- `/` cmdline setup.
cmp.setup.cmdline("/", {
	mapping = cmp.mapping.preset.cmdline(),
	window = {
		documentation = window_scroll_bordered,
		completion = window_scroll_bordered,
	},
	sources = {
		{ name = "buffer" },
	},
})
-- `:` cmdline setup.
cmp.setup.cmdline(":", {
	mapping = cmp.mapping.preset.cmdline(),
	window = {
		documentation = window_scroll_bordered,
		completion = window_scroll_bordered,
	},
	sources = cmp.config.sources({
		{ name = "path" },
	}, {
		{
			name = "cmdline",
			option = {
				ignore_cmds = { "Man", "!" },
			},
		},
	}),
})
