local M = {}

local Path = require("plenary.path")
local state = require("workspaces.state")
local utils = require("workspaces.utils")
local bps = require("workspaces.breakpoints")
local persist = require("workspaces.persistence")
local toggleterms = require("workspaces.toggleterms")

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
				M.switch_session(v, current_workspace)
			end,
			function()
				local res = tostring(i) .. " " .. v.name
				if is_selected then
					return utils.icons.cur .. " " .. res
				elseif is_last_session then
					return utils.icons.last .. " " .. res
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

---Sets session metadata such as last file and line num
---@param session WorkspaceSession
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
---@param target_session WorkspaceSession | nil
---@param target_workspace Workspace
function M.switch_session(target_session, target_workspace)
	-- No target session passed in, we will default to the target workspace current values
	if target_session == nil then
		if #target_workspace.sessions == 0 then
			vim.notify(
				string.format("Cannot switch to '%s', it has no sessions", target_workspace.name),
				vim.log.levels.ERROR
			)

			return
		end

		target_session = utils.find_session(target_workspace, target_workspace.current_session_name)

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
	end

	-- After defaulting nil sessions stop execution if no change is needed
	if target_session == state.get().current_session then
		return
	end

	-- Save current session before switching
	vim.cmd.wa()
	-- hide all toggleterms
	toggleterms.close_visible_terms(true)

	-- Stop lsp for current session, excluding jdtls
	local toggled_types = require("user.utils").toggle_special_buffers({})

	persist.write_nvim_session_file(state.get().current_workspace, state.get().current_session)
	M.set_session_metadata(state.get().current_session, toggled_types)
	require("user.utils").close_non_terminal_buffers()

	-- Switch to new session and workspace
	if target_workspace ~= state.get().current_workspace then
		state.get().last_workspace = state.get().current_workspace
		state.get().current_workspace = target_workspace

		-- When swapping workspaces we need to load the last session instead of setting it to current session
		-- otherwise alternate session will not be within the same workspace
		state.get().last_session = utils.find_session(target_workspace, target_workspace.last_session_name)
	else
		state.get().last_session = state.get().current_session
	end

	state.get().current_session = target_session
	state.get().current_workspace.last_session_name = state.get().last_session and state.get().last_session.name
	state.get().current_workspace.current_session_name = state.get().current_session.name

	persist.source_nvim_session_file(state.get().current_workspace, target_session)

	local win = vim.api.nvim_get_current_win()
	local pos = vim.api.nvim_win_get_cursor(win)

	require("user.utils").toggle_special_buffers(target_session.toggled_types)
	bps.apply_breakpoints(target_session.breakpoints)
	M.set_session_metadata(target_session, {})
	toggleterms.toggle_active_terms(true)

	vim.api.nvim_set_current_win(win)
	vim.api.nvim_win_set_cursor(win, pos)

	M.setup_lualine()
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

	M.setup_lualine()
	persist.persist_workspaces()
end

function M.create_session(name, dir)
	if not utils.verify_session_name(name) then
		return
	end

	local path = Path:new(vim.fn.expand(dir))

	if not path:exists() then
		vim.notify("That directory does not exist, creating it", vim.log.levels.INFO)
		path:mkdir({ parents = true })
	end

	if utils.find_session(state.get().current_workspace, name) ~= nil then
		vim.notify("An session with that name already exists in this workspace", vim.log.levels.ERROR)
		return
	end

	---@type WorkspaceSession
	local session = {
		name = name,
		dir = dir,
		toggled_types = {},
		breakpoints = {},
		toggleterms = {},
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

	M.setup_lualine()
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

	local path = Path:new(vim.fn.expand(dir))

	if not path:exists() then
		vim.notify("That directory does not exist, creating it", vim.log.levels.INFO)
		path:mkdir({ parents = true })
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
				toggleterms = {},
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

	M.setup_lualine()
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

		M.switch_session(nil, state.get().workspaces[1])
	end

	if name == state.get().last_workspace.name then
		state.get().last_workspace = nil
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

	M.switch_session(nil, target_workspace)
end

function M.alternate_workspace()
	local last_workspace = state.get().last_workspace
	if last_workspace == nil then
		vim.notify("No alternate workspace", vim.log.levels.ERROR)
		return
	end

	M.switch_session(nil, last_workspace)
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
