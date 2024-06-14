return {
	--more text objects
	{
		"chrisgrieser/nvim-various-textobjs",
		lazy = true,
		opts = {
			useDefaultKeymaps = false,
		},
	},
	--smart splits
	{
		"mrjones2014/smart-splits.nvim",
		lazy = true,
		opts = {},
	},
	-- Quick navigation
	{
		"folke/flash.nvim",
		lazy = true,
		opts = {
			jump = {
				autojump = true,
			},
			modes = {
				search = {
					enabled = true,
				},
				char = {
					enabled = false,
				},
			},
		},
	},
	{
		"s1n7ax/nvim-window-picker",
		name = "window-picker",
		event = "VeryLazy",
		version = "2.*",
		config = function()
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
		end,
	},
}
