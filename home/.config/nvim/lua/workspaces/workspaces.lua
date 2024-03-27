local M = {}

local Path = require("plenary.path")
local state = require("workspaces.state")
local utils = require("workspaces.utils")
local bps = require("workspaces.breakpoints")
local persist = require("workspaces.persistence")

---Sets session metadata such as last file and line num
---@param session Session
---@param toggled_types string[]
function M.set_session_metadata(session, toggled_types)
	local buf_path = vim.fn.expand("%:p")
	---@cast buf_path string:

	if buf_path ~= "" and Path:new(buf_path):exists() then
		session.last_file_line = unpack(vim.fn.getcurpos(), 2, 2)
		session.last_file = buf_path
	else
		session.last_file_line = nil
		session.last_file = nil
	end

	session.toggled_types = toggled_types
	session.breakpoints = bps.get_breakpoints()
end

--- Switch to target session, does nothing if it is equal to current session
---@param target_session Session
---@param target_workspace Workspace
function M.switch_session(target_session, target_workspace)
	if target_session == state.get().current_session then
		return
	end

	local within_workspace = target_workspace == state.get().current_workspace

	vim.cmd.wa()
	local toggled_types = require("utils").toggle_special_buffers({})

	persist.write_nvim_session_file(state.get().current_workspace, state.get().current_session)
	M.set_session_metadata(state.get().current_session, toggled_types)
	require("utils").close_non_terminal_buffers()

	if within_workspace then
		state.get().last_session = state.get().current_session
	else
		state.get().last_session = utils.find_session(target_workspace, target_workspace.last_session_name)
	end

	state.get().current_session = target_session

	if within_workspace then
		state.get().current_workspace.last_session_name = state.get().last_session.name
		state.get().current_workspace.current_session_name = state.get().current_session.name
		persist.source_nvim_session_file(state.get().current_workspace, target_session)
	else
		persist.source_nvim_session_file(target_workspace, target_session)
	end

	require("utils").toggle_special_buffers(target_session.toggled_types)
	bps.apply_breakpoints(target_session.breakpoints)
	M.set_session_metadata(target_session, {})

	if within_workspace then
		utils.setup_lualine()
		persist.persist_workspaces()
	end
end

--- Switch to a target workspace, does nothing if it is equal to current workspace
---@param target_workspace Workspace
function M.switch_workspace(target_workspace)
	if target_workspace == state.get().current_workspace then
		return
	end

	if #target_workspace.sessions == 0 then
		vim.notify(
			string.format("Cannot switch to '%s', it has no sessions", target_workspace.name),
			vim.log.levels.ERROR
		)

		return
	end

	local target_session = utils.find_session(target_workspace, target_workspace.current_session_name)

	if target_session == nil then
		vim.notify(
			string.format(
				"There was an error switching to workspace '%s' its current session '%s' was not found in workspaces.json",
				target_workspace.name,
				target_workspace.current_session_name
			),
			vim.log.levels.ERROR
		)
		return
	end

	M.switch_session(target_session, target_workspace)

	state.get().last_workspace = state.get().current_workspace
	state.get().current_workspace = target_workspace

	utils.setup_lualine()
	persist.persist_workspaces()
end

function M.rename_current_session(name)
	if not utils.verify_session_name(name) then
		return
	end

	if utils.find_session(state.get().current_workspace, name) ~= nil then
		vim.notify("A session with that name already exists in this workspace", vim.log.levels.ERROR)
		return
	end

	state.get().current_session.name = name
	state.get().current_workspace.current_session_name = name

	utils.setup_lualine()
	persist.persist_workspaces()
end

function M.create_session(name, dir)
	if not utils.verify_session_name(name) then
		return
	end

	if not Path:new(vim.fn.expand(dir)):exists() then
		vim.notify("That directory does not exist", vim.log.levels.ERROR)
		return
	end

	if utils.find_session(state.get().current_workspace, name) ~= nil then
		vim.notify("An session with that name already exists in this workspace", vim.log.levels.ERROR)
		return
	end

	---@type Session
	local session = {
		name = name,
		dir = dir,
		toggled_types = {},
		breakpoints = {},
	}

	table.insert(state.get().current_workspace.sessions, session)

	M.switch_session(session, state.get().current_workspace)
end

function M.delete_session(name)
	local session = utils.find_session(state.get().current_workspace, name)
	if session == nil then
		vim.notify("That session does not exist", vim.log.levels.ERROR)
		return
	end

	local workspace = state.get().current_workspace

	if #workspace.sessions == 1 then
		M.delete_workspace(workspace.name)
	else
		for i, v in ipairs(workspace.sessions) do
			if v.name == name then
				table.remove(workspace.sessions, i)
				break
			end
		end
		if name == workspace.current_session_name then
			M.switch_session(workspace.sessions[1], workspace)
		end
	end

	local session_filename = persist.get_nvim_session_filename(workspace, session)
	local session_file = Path:new(persist.sessions_path):joinpath(session_filename .. ".vim")

	if session_file:exists() then
		session_file:rm()
	end

	utils.setup_lualine()
	persist.persist_workspaces()
end

---@param name string
---@param session_name string
---@param dir string
function M.create_workspace(name, session_name, dir)
	if utils.find_workspace(name) ~= nil then
		vim.notify("An workspace with that name already exists", vim.log.levels.ERROR)
		return
	end

	---@type Workspace
	local workspace = {
		name = name,
		current_session_name = session_name,
		sessions = {
			{
				name = session_name,
				dir = dir,
				toggled_types = {},
				breakpoints = {},
			},
		},
	}

	table.insert(state.get().workspaces, workspace)

	persist.persist_workspaces()
end

function M.rename_current_workspace(name)
	if not utils.verify_workspace_name(name) then
		return
	end

	if utils.find_workspace(name) ~= nil then
		vim.notify("A session with that name already exists", vim.log.levels.ERROR)
		return
	end

	state.get().current_workspace.name = name

	utils.setup_lualine()
	persist.persist_workspaces()
end

function M.delete_workspace(name)
	if utils.find_workspace(name) == nil then
		vim.notify("A workspace with that name does not exist", vim.log.levels.ERROR)
		return
	end

	for i, v in ipairs(state.get().workspaces) do
		if v.name == name then
			table.remove(state.get().workspaces, i)
			break
		end
	end

	if name == state.get().current_workspace.name then
		-- If the current session is the last one delete the local file and recreate it
		if #state.get().workspaces == 0 then
			M.purge_workspaces()
			M.load_workspaces()
		end

		M.switch_workspace(state.get().workspaces[1])
	end

	persist.persist_workspaces()
end

---@param idx number
function M.switch_session_by_index(idx)
	local current_workspace = state.get().current_workspace
	if idx < 1 or idx > #current_workspace.sessions then
		vim.notify("Could not find a session with that index", vim.log.levels.ERROR)
		return
	end

	M.switch_session(current_workspace.sessions[idx], current_workspace)
end

function M.alternate_session()
	local current_state = state.get()
	if current_state.last_session == nil then
		vim.notify("No alternate session", vim.log.levels.ERROR)
		return
	end

	M.switch_session(current_state.last_session, current_state.current_workspace)
end

function M.next_session()
	local current_workspace = state.get().current_workspace
	local current_session = state.get().current_session
	if current_session == nil then
		vim.notify("No current session", vim.log.levels.ERROR)
		return
	end

	local current_session_index = utils.find_session_index(current_workspace, current_session)

	if current_session_index == nil then
		vim.notify("Could not find index of current session", vim.log.levels.ERROR)
		return
	end

	local target_session_index = current_session_index % #current_workspace.sessions + 1

	M.switch_session(current_workspace.sessions[target_session_index], current_workspace)
end

function M.previous_session()
	local current_workspace = state.get().current_workspace
	local current_session = state.get().current_session
	if current_session == nil then
		vim.notify("No current session", vim.log.levels.ERROR)
		return
	end

	local current_session_index = utils.find_session_index(current_workspace, current_session)

	if current_session_index == nil then
		vim.notify("Could not find index of current session", vim.log.levels.ERROR)
		return
	end

	if current_session_index == 1 then
		current_session_index = #current_workspace.sessions
	else
		current_session_index = (current_session_index - 1) % #current_workspace.sessions
	end

	M.switch_session(current_workspace.sessions[current_session_index], current_workspace)
end

---@param name string
function M.switch_workspace_by_name(name)
	local target_workspace = utils.find_workspace(name)

	if target_workspace == nil then
		vim.notify("Could not find a workspace with that name", vim.log.levels.ERROR)
		return
	end

	M.switch_workspace(target_workspace)
end

function M.alternate_workspace()
	local last_workspace = state.get().last_workspace
	if last_workspace == nil then
		vim.notify("No alternate workspace", vim.log.levels.ERROR)
		return
	end

	M.switch_workspace(last_workspace)
end

function M.list_session_names()
	local sessions = state.get().current_workspace.sessions
	local session_names = {}

	for _, value in ipairs(sessions) do
		table.insert(session_names, value.name)
	end
	return session_names
end

return M
