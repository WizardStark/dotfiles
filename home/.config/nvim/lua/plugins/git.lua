return {
	{
		"echasnovski/mini.diff",
		version = false,
		opts = {
			view = {
				style = "sign",
				signs = {
					add = "┃",
					change = "┃",
					delete = "_",
				},
			},
			delay = {
				text_change = 50,
			},
			mappings = {
				apply = "",
				reset = "",
				textobject = "",
				goto_first = "",
				goto_prev = "",
				goto_next = "",
				goto_last = "",
			},
			options = {
				wrap_goto = true,
			},
		},
	},
	{
		"sindrets/diffview.nvim",
		cmd = { "DiffviewOpen", "DiffviewClose" },
		config = true,
	},
	{
		"WizardStark/git-blame.nvim",
		event = "VeryLazy",
		opts = {
			enabled = true,
			message_template = " <summary> • <date> • <author> ",
			date_format = "%Y-%m-%d",
			set_extmark_options = {
				hl_mode = "combine",
				virt_text_pos = "right_align",
			},
		},
	},
}
