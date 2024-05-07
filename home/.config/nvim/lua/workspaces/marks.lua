local M = {}

local state = require("workspaces.state")
local ws = require("workspaces.workspaces")
local utils = require("workspaces.utils")

function M.create_mark()
	local pos = vim.api.nvim_win_get_cursor(0)
	local pos_string = tostring(pos[1]) .. "-" .. tostring(pos[2])
	local workspace_name = state.get().current_workspace.name:gsub(" ", "-")
	local session_name = state.get().current_session.name:gsub(" ", "-")
	local file_path = vim.fn.expand("%:p")
	local cleaned_path = vim.trim(file_path:gsub("/", " ")):gsub(" ", "-")
	local mark_name = workspace_name .. "_" .. session_name .. "_" .. cleaned_path .. "_" .. pos_string

	---@type Mark
	local mark = {
		name = mark_name,
		session_name = session_name,
		workspace_name = workspace_name,
		path = file_path,
		pos = pos,
	}

	table.insert(state.get().marks, mark)
end

---@param mark_name string
---@return Mark | nil
local function find_mark(mark_name)
	for _, v in ipairs(state.get().marks) do
		if v.name == mark_name then
			return v
		end
	end

	return nil
end

---@param mark_name string
function M.goto_mark(mark_name)
	local target_mark = find_mark(mark_name)
	if not target_mark then
		vim.notify(string.format("Mark does not exist"), vim.log.levels.ERROR)
		return
	end

	local target_workspace = utils.find_workspace(target_mark.workspace_name)

	if not target_workspace then
		vim.notify(string.format("Target workspace for mark does not exist"), vim.log.levels.ERROR)
		return
	end

	local target_session = utils.find_session(target_workspace, target_mark.session_name)
	if not target_session then
		vim.notify(string.format("Target session for mark does not exist"), vim.log.levels.ERROR)
		return
	end

	ws.switch_session(target_session, target_workspace)

	-- local pos = target_mark.pos
	vim.cmd("e " .. target_mark.path)
	vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), target_mark.pos)
end

---@param mark_name string
function M.delete_mark(mark_name)
	if not find_mark(mark_name) then
		vim.notify(string.format("Mark does not exist"), vim.log.levels.ERROR)
		return
	end

	for i, v in ipairs(state.get().marks) do
		if v.name == mark_name then
			table.remove(state.get().marks, i)
			break
		end
	end
end

return M
