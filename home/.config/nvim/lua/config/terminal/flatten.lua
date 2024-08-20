local saved_terminal
local terms = require("workspaces.toggleterms")
local state = require("workspaces.state")

require("flatten").setup(
	---@module 'flatten'
	{
		window = {
			open = "smart",
		},
		nest_if_no_args = true,
		callbacks = {
			should_block = function(argv)
				return vim.tbl_contains(argv, "-b")
			end,
			post_open = function(bufnr, winnr, ft, is_blocking)
				if is_blocking then
					terms.close_visible_terms(true)
				else
					vim.api.nvim_set_current_win(winnr)
				end
			end,
			block_end = function()
				vim.schedule(function()
					terms.toggle_active_terms(true)
				end)
			end,
		},
	}
)
