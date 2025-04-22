local P = require("user.utils").PREFIXES
M = {}
M.functions = {}
local mappings = {
	{
		callback = function()
			vim.cmd.e(vim.g.lclpath .. "/options.lua")
		end,
		prefix = P.misc,
		description = "Edit local config",
	},
	{
		callback = function()
			require("workspaces.persistence").load_workspaces()
		end,
		prefix = P.work,
		description = "Load workspaces",
	},
	{
		callback = function()
			require("workspaces.persistence").purge_session_files()
		end,
		prefix = P.work,
		description = "Delete all session files",
	},
	{
		callback = function()
			require("user.utils").close_non_terminal_buffers(false)
		end,
		prefix = P.misc,
		description = "Force close all non-terminal buffers except the current one",
	},
	{
		callback = function()
			require("user.utils").force_close_other_buffers()
		end,
		prefix = P.misc,
		description = "Force close all buffers except the current one",
	},
	{
		callback = function()
			require("user.utils").toggle_keys_window()
		end,
		prefix = P.misc,
		description = "Toggle window that logs keypresses",
	},
	{
		callback = function()
			require("lint").try_lint()
		end,
		prefix = P.code,
		description = "Run linter",
	},
}

local prefixifier = require("user.utils").prefixifier
prefixifier(function(maps)
	for _, map in ipairs(maps) do
		map.desc = map.description
		map.type = "unmapped"
	end
	M.functions = maps
end)(mappings)

return M
