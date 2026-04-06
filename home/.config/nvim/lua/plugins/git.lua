return {
	{
		src = "https://github.com/echasnovski/mini.diff",
		event = "UIEnter",
		config = function()
			require("mini.diff").setup({
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
			})
		end,
	},
	{
		src = "https://github.com/esmuellert/codediff.nvim",
		dependencies = { { src = "https://github.com/MunifTanjim/nui.nvim" } },
		config = function()
			require("codediff").setup({
				keymaps = {
					view = {
						next_hunk = "<M-n>",
						prev_hunk = "<M-t>",
						toggle_layout = "<C-S-v>",
					},
				},
			})
		end,
	},
	{
		src = "https://github.com/WizardStark/git-blame.nvim",
		config = function()
			require("gitblame").setup({
				enabled = true,
				message_template = " <summary> • <date> • <author> ",
				date_format = "%Y-%m-%d",
				set_extmark_options = {
					hl_mode = "combine",
					virt_text_pos = "right_align",
				},
			})
		end,
	},
	{
		src = "https://github.com/WizardStark/github-pr-reviewer.nvim",
		enabled = function()
			return vim.fn.executable("gh") == 1
		end,
		config = function()
			require("github-pr-reviewer").setup({
				mark_as_viewed_key = "<CR>",
				diff_view_toggle_key = "<C-S-v>",
				toggle_floats_key = "<C-r>",
				next_hunk_key = "<M-n>",
				prev_hunk_key = "<M-t>",
				next_file_key = "]f",
				prev_file_key = "[f",
			})
		end,
	},
}
