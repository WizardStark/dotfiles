return {
	{
		"echasnovski/mini.diff",
		event = "UiEnter",
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
		"esmuellert/codediff.nvim",
		dependencies = { "MunifTanjim/nui.nvim" },
		cmd = "CodeDiff",
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
	{
		"otavioschwanck/github-pr-reviewer.nvim",
		event = "VeryLazy",
		enabled = function()
			return vim.fn.executable("gh") == 1
		end,
		opts = {
			mark_as_viewed_key = "<CR>",
			diff_view_toggle_key = "<C-S-v>",
			toggle_floats_key = "<C-r>",
			next_hunk_key = "<M-n>",
			prev_hunk_key = "<M-t>",
			next_file_key = "]q",
			prev_file_key = "[q",
		},
	},
}
