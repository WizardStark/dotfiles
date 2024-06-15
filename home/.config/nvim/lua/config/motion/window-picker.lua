require("window-picker").setup({
	show_prompt = false,
	hint = "floating-big-letter",
	filter_rules = {
		autoselect_one = false,
		include_current_win = false,
		bo = {
			filetype = {
				"noice",
			},
			buftype = {
				"nofile",
				"nowrite",
			},
		},
	},
	selection_chars = "scntk,aeih",
})
