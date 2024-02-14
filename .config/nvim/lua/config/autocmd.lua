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
				if string.find(vim.fn.expand("%:p"), vim.fn.getcwd()) then
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
})
