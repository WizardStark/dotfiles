return {
	{
		"chrisgrieser/nvim-various-textobjs",
		lazy = true,
		opts = {
			keymaps = {
				useDefaults = false,
			},
		},
	},
	{
		"mrjones2014/smart-splits.nvim",
		lazy = true,
		config = function()
			require("config.motion.smart-splits")
		end,
	},
	{
		"folke/flash.nvim",
		lazy = true,
		config = function()
			require("config.motion.flash")
		end,
	},
	{
		"s1n7ax/nvim-window-picker",
		name = "window-picker",
		lazy = true,
		version = "2.*",
		config = function()
			require("config.motion.window-picker")
		end,
	},
}
