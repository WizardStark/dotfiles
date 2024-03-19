local prefixifier = require("utils").prefixifier
local P = require("utils").PREFIXES
local autocmds = require("legendary").autocmds

prefixifier(autocmds)({
	{
		"BufEnter",
		function()
			if not vim.g.workspaces_loaded then
				vim.g.workspaces_loaded = true
				if next(vim.fn.argv()) == nil then
					local is_floating_win = vim.api.nvim_win_get_config(0).relative ~= ""
					if is_floating_win then
						vim.cmd.wincmd({ args = { "w" }, count = 1 })
					end
					require("workspaces").load_workspaces()
				end
			end
		end,
		prefix = P.auto,
	},
	{
		"FileType",
		opts = {
			pattern = "markdown",
		},
		function()
			vim.opt.wrap = false
		end,
		prefix = P.auto,
	},
	{
		"BufWritePost",
		opts = {
			pattern = "*.bib",
		},
		function()
			vim.cmd([[!bibtex main]])
		end,
		prefix = P.auto,
	},
	{
		"BufWinEnter",
		function()
			if vim.bo.bt == "terminal" then
				vim.opt_local.number = false
				vim.opt_local.relativenumber = false
			end
		end,
		prefix = P.auto,
	},
	{
		"TermOpen",
		function()
			vim.opt_local.number = false
			vim.opt_local.relativenumber = false
		end,
		prefix = P.auto,
	},
	{
		"BufWinEnter",
		function()
			if vim.bo.ft == "help" then
				vim.cmd("wincmd L")
			end
		end,
		prefix = P.auto,
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
			prefix = P.auto,
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
			prefix = P.auto,
		},
	},
	{
		"BufWritePost",
		function()
			require("lint").try_lint()
		end,
		prefix = P.auto,
	},
})

return {}
