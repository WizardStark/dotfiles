local prefixifier = require("utils").prefixifier
local P = require("utils").PREFIXES
local funcs = require("legendary").funcs

prefixifier(funcs)({
	{
		function()
			local ok, _ = pcall(dofile, vim.fn.expand("$HOME/.config/lcl/lua/init.lua"))
			if not ok then
				vim.cmd.e("~/.config/lcl/lua/init.lua")
			else
				vim.notify("Local config does not exist, please close and reopen vim")
			end
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
})
return {}
