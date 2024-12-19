return {
	setup = function()
		vim.api.nvim_create_autocmd("UiEnter", {
			callback = function()
				require("user.ui").setup()
			end,
		})
		vim.api.nvim_create_autocmd("User", {
			pattern = "VeryLazy",
			callback = function()
				require("user.autocmds").setup()
				require("user.commands").setup()
				require("user.functions").setup()
				require("user.keymaps").setup()
				require("mini.diff").enable(0)
			end,
		})
	end,
}
