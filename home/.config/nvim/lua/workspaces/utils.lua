local M = {}

local state = require("workspaces.state")

M.icons = {
	last = "",
	cur = "",
}

local _, colors = pcall(require("catppuccin.palettes").get_palette, "mocha")

-- This function needs to be called whenever the tabs change
function M.setup_lualine()
	local tabs = {}
	local current_workspace = state.get().current_workspace

	for i, v in ipairs(current_workspace.sessions) do
		local is_selected = v.name == current_workspace.current_session_name
		local is_last_session = v.name == current_workspace.last_session_name

		tabs[i] = {
			mode = 2,
			color = function()
				return { fg = is_selected and colors.blue or colors.text }
			end,
			on_click = function()
				M.switch_session(v.name)
			end,
			function()
				local res = tostring(i) .. " " .. v.name
				if is_selected then
					return M.icons.cur .. " " .. res
				elseif is_last_session then
					return M.icons.last .. " " .. res
				end
				return res
			end,
		}
	end

	require("lualine").setup({
		tabline = {
			lualine_a = {
				function()
					return current_workspace.name
				end,
			},
			lualine_b = tabs,
		},
	})
end

---@param workspace Workspace
---@param session_name string
---@return Session | nil
function M.find_session(workspace, session_name)
	for _, v in ipairs(workspace.sessions) do
		if v.name == session_name then
			return v
		end
	end

	return nil
end

---@param workspace Workspace
---@param session Session
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
