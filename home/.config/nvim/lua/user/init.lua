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
				require("user.functions")
				require("user.keymaps").setup()
				require("mini.diff").enable(0)
				vim.api.nvim_create_autocmd("LspProgress", {
					callback = function(ev)
						local value = ev.data.params.value
						vim.api.nvim_echo({ { value.message or "done" } }, false, {
							id = "lsp." .. ev.data.client_id,
							kind = "progress",
							source = "vim.lsp",
							title = value.title,
							status = value.kind ~= "end" and "running" or "success",
							percent = value.percentage,
						})
					end,
				})
			end,
		})
	end,
}
