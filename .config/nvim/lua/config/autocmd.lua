require("legendary").autocmds({
	{
		"FileType",
		pattern = "markdown",
		function()
			vim.opt.wrap = false
		end,
	},
	{
		"BufWritePost",
		pattern = ".bib",
		function()
			vim.cmd([[!bibtex main]])
		end,
	},
	{
		name = "UserSessionManager",
		clear = true,
		{
			"VimEnter",
			nested = true,
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
					require("session_manager").save_current_session()
				end
			end,
		},
	},
})
