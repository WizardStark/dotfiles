require("flatten").setup(
	---@module 'flatten'
	{
		window = {
			open = "smart",
		},
		nest_if_no_args = true,
		hooks = {
			should_block = function(argv)
				return vim.tbl_contains(argv, "-b")
			end,
			post_open = function(bufnr, winnr, ft, is_blocking)
				if is_blocking then
					require("workspaces.toggleterms").close_visible_terms(true)
				end
			end,
			block_end = function()
				vim.schedule(function()
					require("workspaces.toggleterms").toggle_active_terms(true)
				end)
			end,
		},
	}
)
