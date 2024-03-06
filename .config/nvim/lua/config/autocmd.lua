return {
	require("legendary").autocmds({
		{
			"FileType",
			opts = {
				pattern = "markdown",
			},
			function()
				vim.opt.wrap = false
			end,
		},
		{
			"BufWritePost",
			opts = {
				pattern = "*.bib",
			},
			function()
				vim.cmd([[!bibtex main]])
			end,
		},
		{
			"BufWinEnter",
			function()
				if vim.bo.bt == "terminal" then
					vim.opt_local.number = false
					vim.opt_local.relativenumber = false
				end
			end,
		},
		{
			"TermOpen",
			function()
				vim.opt_local.number = false
				vim.opt_local.relativenumber = false
			end,
		},
		{
			"BufWinEnter",
			function()
				if vim.bo.ft == "help" then
					vim.cmd("wincmd L")
				end
			end,
		},
		{
			name = "UserMiniFiles",
			{
				"User",
				opts = {
					pattern = "MiniFilesWindowOpen",
				},
				function(args)
					local win_id = args.data.win_id
					vim.api.nvim_win_set_config(win_id, { border = "rounded" })
				end,
			},
			{
				"User",
				opts = {
					pattern = "MiniFilesBufferCreate",
				},
				function(args)
					local MiniFiles = require("mini.files")
					local buf_id = args.data.buf_id
					vim.keymap.set("n", "h", function()
						MiniFiles.go_out()
						MiniFiles.go_out()
						MiniFiles.go_in()
					end, { buffer = buf_id })
				end,
			},
		},
		{
			"BufWritePost",
			function()
				require("lint").try_lint()
			end,
		},
		{
			"VimEnter",
			function()
				require("workspaces").load_workspaces()
			end,
		},
	}),
}
