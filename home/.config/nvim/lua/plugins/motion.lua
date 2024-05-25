return {
	--other
	{
		"rgroli/other.nvim",
		cmd = { "Other", "OtherClear", "OtherTabNew", "OtherSplit", "OtherVSplit" },
		config = function()
			require("other-nvim").setup({
				mappings = {
					{
						pattern = ".*/src/(.*)/(.*)",
						target = {
							{ target = ".*/tst/**/%1/%2" },
							{ target = ".*/tst/**/%1/Test_%2" },
						},
					},
					{
						pattern = ".*/tst/.*/(.*)/(.*)",
						target = ".*/src/%1/%2",
					},
					{
						pattern = ".*/tst/.*/(.*)/Test_(.*)",
						target = ".*/src/%1/%2",
					},
				},

				style = {
					border = "rounded",
					seperator = "|",
					newFileIndicator = "(* new *)",
					width = 0.7,
					minHeight = 2,
				},
			})
		end,
	},
	--tabout
	{
		"kawre/neotab.nvim",
		event = "InsertEnter",
		opts = {},
	},
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
			},
			char = {
				enabled = false,
			},
		},
	},
}
