return {
	"yetone/avante.nvim",
	event = "VeryLazy",
	version = false, -- Never set this value to "*"! Never!
	build = "make",
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		"nvim-lua/plenary.nvim",
		"MunifTanjim/nui.nvim",
		"saghen/blink.cmp",
		"echasnovski/mini.icons",
	},
	config = function()
		require("config.editor.llm")
	end,
}
