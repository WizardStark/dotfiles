local M = {}

local state = require("workspaces.state")

M.icons = {
	last = "",
	cur = "",
}

---@param workspace Workspace
---@param session_name string
---@return WorkspaceSession | nil
function M.find_session(workspace, session_name)
	for _, v in ipairs(workspace.sessions) do
		if v.name == session_name then
			return v
		end
	end

	return nil
end

---@param workspace Workspace
---@param session WorkspaceSession
---@return number | nil
function M.find_session_index(workspace, session)
	for i, v in ipairs(workspace.sessions) do
		if v.name == session.name then
			return i
		end
	end

	return nil
end

---@param workspace_name string
---@return Workspace | nil
function M.find_workspace(workspace_name)
	for _, v in ipairs(state.get().workspaces) do
		if v.name == workspace_name then
			return v
		end
	end

	return nil
end

---@param workspace_name string
---@return number | nil
function M.find_workspace_index(workspace_name)
	for i, v in ipairs(state.get().workspaces) do
		if v.name == workspace_name then
			return i
		end
	end

	return nil
end

---Verifies is a given session name is valid
---@param name string
---@return boolean
function M.verify_session_name(name)
	if name == nil or name == "" then
		vim.notify("Session names cannot be nil or empty", vim.log.levels.ERROR)
		return false
	end

	return true
end

---Verifies is a given workspace name is valid
---@param name string
---@return boolean
function M.verify_workspace_name(name)
	if name == nil or name == "" then
		vim.notify("Workspace names cannot be nil or empty", vim.log.levels.ERROR)
		return false
	end

	return true
end

return M
