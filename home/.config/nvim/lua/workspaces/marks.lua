local M = {}

local state = require("workspaces.state")
local utils = require("workspaces.utils")

function M.create_mark()
	local pos = vim.api.nvim_win_get_cursor(0)
	local workspace_name = state.get().current_workspace.name:gsub(" ", "-")
	local session_name = state.get().current_session.name:gsub(" ", "-")
	local file_path = vim.fn.expand("%:p"):gsub("/", "-")

	---@type Mark
	local mark = {
		session_name = session_name,
		workspace_name = workspace_name,
		path = file_path,
		pos = pos,
	}

	table.insert(state.get().marks, mark)
end

return M
