return {
	setup = function()
		vim.api.nvim_create_autocmd("UIEnter", {
			callback = function()
				require("user.ui").setup()
			end,
		})
	end,
}
