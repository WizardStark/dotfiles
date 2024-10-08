return {
	highlight = {
		use_nvim_cmp_as_default = true,
	},
	nerd_font_variant = "mono",
	accept = { auto_brackets = { enabled = true } },
	trigger = { signature_help = { enabled = true } },
	keymap = {
		show = "<C-space>",
		hide = "<C-e>",
		accept = "<Tab>",
		select_prev = { "<Up>", "<C-k>" },
		select_next = { "<Down>", "<C-j>" },

		show_documentation = {},
		hide_documentation = {},
		scroll_documentation_up = "<C-b>",
		scroll_documentation_down = "<C-f>",

		snippet_forward = "<Tab>",
		snippet_backward = "<S-Tab>",
	},
	windows = {
		autocomplete = {
			min_width = 30,
			max_width = 60,
			max_height = 10,
			border = "rounded",
			winhighlight = "Normal:BlinkCmpMenu,FloatBorder:BlinkCmpMenuBorder,CursorLine:BlinkCmpMenuSelection,Search:None",
			scrolloff = 2,
			direction_priority = { "s", "n" },
			draw = "simple",
		},
	},
	documentation = {
		min_width = 10,
		max_width = 60,
		max_height = 20,
		border = "rounded",
		winhighlight = "Normal:BlinkCmpDoc,FloatBorder:BlinkCmpDocBorder,CursorLine:BlinkCmpDocCursorLine,Search:None",
		direction_priority = {
			autocomplete_north = { "e", "w", "n", "s" },
			autocomplete_south = { "e", "w", "s", "n" },
		},
		auto_show = true,
		auto_show_delay_ms = 500,
		update_delay_ms = 100,
	},
	signature_help = {
		min_width = 1,
		max_width = 100,
		max_height = 10,
		border = "rounded",
		winhighlight = "Normal:BlinkCmpSignatureHelp,FloatBorder:BlinkCmpSignatureHelpBorder",
	},
}
