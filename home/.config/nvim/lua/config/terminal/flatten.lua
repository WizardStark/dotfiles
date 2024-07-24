local saved_terminal

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
)
