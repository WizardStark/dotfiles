return {
	{
		"lewis6991/gitsigns.nvim",
		event = "VeryLazy",
		opts = {
			current_line_blame = true,
			current_line_blame_opts = {
				virt_text_pos = "right_align",
				delay = 500,
			},
			preview_config = {
				border = "rounded",
			},
		},
	},
	{
		"echasnovski/mini.diff",
		version = false,
		opts = {
			view = {
				signs = {
					add = "┃",
					change = "┃",
					delete = "_",
				},
			},
		},
	},
	{
		"sindrets/diffview.nvim",
		cmd = { "DiffviewOpen", "DiffviewClose" },
		config = true,
	},
}
