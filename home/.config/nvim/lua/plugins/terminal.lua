return {
	{
		"akinsho/toggleterm.nvim",
		event = "VeryLazy",
		version = "*",
		config = true,
		opts = {
			open_mapping = [[<c-~>]],
			on_exit = function(term, job, exit_code, name)
				local session_terms = require("workspaces.toggleterms").get_session_terms()
				for _, value in ipairs(session_terms) do
					if value.global_id == term.id then
						require("workspaces.toggleterms").delete_term(value.local_id)
					end
				end
			end,
		},
	},
	{
		"chomosuke/term-edit.nvim",
		ft = "toggleterm",
		version = "1.*",
		opts = {
			prompt_end = "╰─",
			mapping = { n = { s = false } },
		},
	},
	{
		"willothy/flatten.nvim",
		lazy = false,
		priority = 1001,
		opts = function()
			local saved_terminal

			return {
				window = {
					open = "smart",
				},
				nest_if_no_args = true,
				callbacks = {
					should_block = function(argv)
						return vim.tbl_contains(argv, "-b")
					end,
					pre_open = function()
						local term = require("toggleterm.terminal")
						local termid = term.get_focused_id()
						saved_terminal = term.get(termid)
					end,
					post_open = function(bufnr, winnr, ft, is_blocking)
						if is_blocking and saved_terminal then
							saved_terminal:close()
						else
							vim.api.nvim_set_current_win(winnr)
						end
					end,
					block_end = function()
						vim.schedule(function()
							if saved_terminal then
								saved_terminal:open()
								saved_terminal = nil
							end
						end)
					end,
				},
			}
		end,
	},
	{
		"Zeioth/compiler.nvim",
		cmd = { "CompilerOpen", "CompilerToggleResults", "CompilerRedo" },
		dependencies = {
			{
				"stevearc/overseer.nvim",
				cmd = { "CompilerOpen", "CompilerToggleResults", "CompilerRedo" },
				opts = {
					task_list = {
						direction = "bottom",
						min_height = 25,
						max_height = 25,
						default_detail = 1,
					},
				},
			},
		},
		config = true,
	},
}
