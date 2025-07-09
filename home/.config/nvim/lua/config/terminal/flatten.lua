local saved_terminal

require("flatten").setup(
	---@module 'flatten'
	{
		window = {
			open = "alternate",
		},
		nest_if_no_args = true,
		hooks = {
			should_block = function(argv)
				return vim.tbl_contains(argv, "-b")
			end,
			pre_open = function()
				if not vim.g.workspaces_loaded then
					local term = require("toggleterm.terminal")
					local termid = term.get_focused_id()
					saved_terminal = term.get(termid)
				end
			end,
			post_open = function(ctx)
				if ctx.is_blocking then
					if vim.g.workspaces_loaded then
						require("workspaces.toggleterms").close_visible_terms(true)
					elseif saved_terminal then
						saved_terminal:close()
					end
				else
					vim.api.nvim_set_current_win(ctx.winnr)
				end
			end,
			block_end = function()
				vim.schedule(function()
					if vim.g.workspaces_loaded then
						require("workspaces.toggleterms").toggle_active_terms(true)
					elseif saved_terminal then
						saved_terminal:open()
						saved_terminal = nil
					end
				end)
			end,
		},
	}
)
