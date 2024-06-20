local P = require("user.utils").PREFIXES

local mappings = {
	{
		function()
			vim.cmd.e(vim.g.lclpath .. "/options.lua")
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
			require("user.utils").close_non_terminal_buffers(false)
		end,
		prefix = P.misc,
		description = "Force close all non-terminal buffers except the current one",
	},
	{
		function()
			require("user.utils").toggle_keys_window()
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
}

return {
	setup = function()
		local prefixifier = require("user.utils").prefixifier
		local funcs = require("legendary").funcs
		prefixifier(funcs)(mappings)
	end,
}
