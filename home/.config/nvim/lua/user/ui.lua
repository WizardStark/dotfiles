return {
	setup = function()
		local catppuccin_opts = {
			integrations = {
				flash = true,
				gitsigns = true,
				mason = true,
				neotest = true,
				noice = true,
				cmp = true,
				dap = true,
				dap_ui = true,
				diffview = true,
				notify = true,
				treesitter = true,
				ufo = true,
				overseer = true,
				lsp_trouble = true,
			},
		}

		catppuccin_opts = vim.tbl_deep_extend("force", catppuccin_opts, vim.g.catppuccin_opts or {})
		require("catppuccin").setup(catppuccin_opts)
		vim.cmd("colorscheme " .. vim.g.colorscheme)

		if not vim.g.workspaces_loaded then
			if next(vim.fn.argv()) == nil then
				vim.g.workspaces_loaded = true
				local is_floating_win = vim.api.nvim_win_get_config(0).relative ~= ""
				if is_floating_win then
					vim.cmd.wincmd({ args = { "w" }, count = 1 })
				end

				require("workspaces.persistence").load_workspaces()
				require("workspaces.workspaces").setup_lualine()
				vim.cmd.stopinsert()
			else
				require("lualine")
			end
		else
			require("workspaces.marks").clear_marks()
			require("workspaces.marks").display_marks()
		end
	end,
}
