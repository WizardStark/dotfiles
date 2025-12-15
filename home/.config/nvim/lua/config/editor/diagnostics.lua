require("tiny-inline-diagnostic").setup({
	options = {
		show_source = {
			enabled = true,
			if_many = true,
		},

		add_messages = {
			messages = true,
			display_count = true,
			show_multiple_glyphs = true,
		},

		multilines = {
			enabled = true,
			always_show = true,
			trim_whitespaces = false,
			tabstop = 4,
			severity = nil,
		},

		show_related = {
			enabled = true,
			max_count = 10,
		},
	},
})
vim.diagnostic.config({ virtual_text = false })
