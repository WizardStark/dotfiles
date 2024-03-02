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
				if vim.bo.ft == "help" then
					vim.cmd("wincmd L")
				end
			end,
		},
		{
			name = "UserSessionManager",
			clear = true,
			{
				"VimEnter",
				opts = {
					nested = true,
				},
				function()
					if vim.fn.argc() == 0 and not vim.g.started_with_stdin then
						local ok, _ = pcall(require("session_manager").load_current_dir_session, true)
						if not ok then
							vim.notify("Session corrupted, deleting")
							vim.cmd([[:SessionManager delete_current_dir_session<CR>]])
						end
					end
				end,
			},
			{
				"VimLeavePre",
				function()
					if vim.fn.expand("%:p"):find(vim.fn.getcwd(), 1, true) then
						local buflist = vim.api.nvim_list_bufs()
						for _, bufnr in ipairs(buflist) do
							if vim.bo[bufnr].bt == "terminal" then
								vim.cmd("bd! " .. tostring(bufnr))
							end
						end
						require("session_manager").save_current_session()
					end
				end,
			},
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
	}),
}
