return {
	{
		src = "https://github.com/chrisgrieser/nvim-various-textobjs",
		config = function()
			require("various-textobjs").setup({
				keymaps = {
					useDefaults = false,
				},
			})
		end,
	},
	{
		src = "https://github.com/mrjones2014/smart-splits.nvim",
		config = function()
			require("config.motion.smart-splits")
		end,
	},
	{
		src = "https://github.com/folke/flash.nvim",
		config = function()
			require("config.motion.flash")
		end,
	},
	{
		src = "https://github.com/s1n7ax/nvim-window-picker",
		name = "window-picker",
		config = function()
			require("config.motion.window-picker")
		end,
	},
	{
		src = "https://github.com/mawkler/demicolon.nvim",
		dependencies = {
			{ src = "https://github.com/nvim-treesitter/nvim-treesitter" },
			{ src = "https://github.com/nvim-treesitter/nvim-treesitter-textobjects" },
		},
		config = function()
			require("config.motion.demicolon")
		end,
	},
}
