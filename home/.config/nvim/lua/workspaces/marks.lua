local M = {}

local state = require("workspaces.state")
local ws = require("workspaces.workspaces")
local utils = require("workspaces.utils")
local toggleterms = require("workspaces.toggleterms")

local ns = "ws_marks"
vim.fn.sign_define(
	"WorkspaceMark",
	{ text = "", texthl = "SnacksPickerIconProperty", numhl = "SnacksPickerIconProperty" }
)

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
	M.clear_marks()
	M.display_marks()
end

---@param mark_name string
---@return Mark | nil
local function find_mark(mark_name)
	for _, mark in ipairs(state.get().marks) do
		if mark.name == mark_name then
			return mark
		end
	end

	return nil
end

---@param workspace_name string
---@param session_name string
---@param path string
---@param pos number[]
---@return Mark | nil
local function find_mark_by_metadata(workspace_name, session_name, path, pos)
	for _, mark in ipairs(state.get().marks) do
		if
			mark.workspace_name == workspace_name
			and mark.session_name == session_name
			and mark.path == path
			and pos[1] == mark.pos[1]
		then
			return mark
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

	toggleterms.close_visible_terms(true)
	local toggled_types = require("user.utils").toggle_special_buffers({})

	vim.cmd("e " .. target_mark.path)
	vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), target_mark.pos)

	require("user.utils").toggle_special_buffers(toggled_types)
	toggleterms.toggle_active_terms(true)
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

	M.clear_marks()
	M.display_marks()
end

function M.toggle_mark()
	local pos = vim.api.nvim_win_get_cursor(0)
	local target_mark = find_mark_by_metadata(
		state.get().current_workspace.name,
		state.get().current_workspace.current_session_name,
		vim.fn.expand("%:p"),
		pos
	)

	if not target_mark then
		M.create_mark()
	else
		M.delete_mark(target_mark.name)
	end
end

---@param mark_name string
function M.rename_mark(mark_name)
	if not find_mark(mark_name) then
		vim.notify(string.format("Mark does not exist"), vim.log.levels.ERROR)
		return
	end

	for i, v in ipairs(state.get().marks) do
		if v.name == mark_name then
			vim.ui.input({
				prompt = "Mark name",
				default = "",
				kind = "tabline",
			}, function(input)
				if input then
					state.get().marks[i].display_name = input
				else
					vim.notify("Rename cancelled")
				end
			end)
			break
		end
	end
end

function M.display_marks()
	local count = 1
	local current_workspace = state.get().current_workspace.name
	local current_session = state.get().current_workspace.current_session_name
	local lines_with_marks = {}
	for _, mark in ipairs(state.get().marks) do
		if
			mark.workspace_name == current_workspace
			and mark.session_name == current_session
			and mark.path == vim.fn.expand("%:p")
		then
			table.insert(lines_with_marks, mark.pos[1])
		end
	end

	for _, line in ipairs(lines_with_marks) do
		vim.fn.sign_place(count, ns, "WorkspaceMark", vim.api.nvim_get_current_buf(), { lnum = line, priority = 20 })
	end
end

function M.clear_marks()
	vim.fn.sign_unplace(ns, { buffer = vim.api.nvim_get_current_buf() })
end

return M
