local prefixifier = require("utils").prefixifier
local P = require("utils").PREFIXES
local funcs = require("legendary").funcs

prefixifier(funcs)({
	{
		function()
			vim.cmd.e(vim.g.lclfilepath)
		end,
		prefix = P.misc,
		description = "Edit local config",
	},
	{
		function()
			require("workspaces.persistence").load_workspaces()
		end,
		prefix = P.work,
		description = "Load workspaces",
	},
	{
		function()
			require("workspaces.persistence").purge_session_files()
		end,
		prefix = P.work,
		description = "Delete all session files",
	},
	{
		function()
			require("utils").close_non_terminal_buffers(false)
		end,
		prefix = P.misc,
		description = "Force close all non-terminal buffers except the current one",
	},
	{
		function()
			require("utils").toggle_keys_window()
		end,
		prefix = P.misc,
		description = "Toggle window that logs keypresses",
	},

	{
		function()
			require("lint").try_lint()
		end,
		prefix = P.code,
		description = "Run linter",
	},
})
return {}
