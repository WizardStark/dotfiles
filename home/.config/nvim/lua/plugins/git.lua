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
		"sindrets/diffview.nvim",
		cmd = { "DiffviewOpen", "DiffviewClose" },
		config = true,
	},
	{
		"akinsho/git-conflict.nvim",
		version = "*",
		event = "VeryLazy",
		config = true,
	},
}
