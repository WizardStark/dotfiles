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
	--bookmarks
	{
		"tomasky/bookmarks.nvim",
		opts = {
			sign_priority = 8,
		},
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
		event = "VeryLazy",
		opts = { useDefaultKeymaps = true },
	},
	--mutli-cursor
	{
		"brenton-leighton/multiple-cursors.nvim",
		event = "VeryLazy",
		opts = {},
	},
	--smart splits
	{
		"mrjones2014/smart-splits.nvim",
		event = "VeryLazy",
		opts = {},
	},
	-- Quick navigation
	{
		"folke/flash.nvim",
		event = "VeryLazy",
		opts = {
			modes = {
				search = {
					enabled = false,
				},
			},
		},
	},
}
