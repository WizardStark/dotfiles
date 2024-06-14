return {
	setup = function()
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
