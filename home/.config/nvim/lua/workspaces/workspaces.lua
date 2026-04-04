local M = {}

local Path = require("plenary.path")
local state = require("workspaces.state")
local utils = require("workspaces.utils")
local bps = require("workspaces.breakpoints")
local persist = require("workspaces.persistence")
local toggleterms = require("workspaces.toggleterms")

local _, colors = pcall(require("catppuccin.palettes").get_palette, "mocha")

local function save_named_buffers()
	local buflist = vim.api.nvim_list_bufs()
	for _, bufnr in ipairs(buflist) do
		if vim.api.nvim_buf_get_name(bufnr) == nil then
			pcall(vim.diagnostic.hide, nil, bufnr)
			pcall(vim.cmd, "bd! " .. tostring(bufnr))
		end
	end
	vim.cmd.wa()
end

local function exit_hydras()
	if _G.Hydra ~= {} then
		require("config.hydra").dap_hydra:exit()
		require("config.hydra").git_hydra:exit()
		require("config.hydra").trouble_hydra:exit()
		require("config.hydra").treewalker_hydra:exit()
	end
end

local function stop_lsp_clients()
	local clients = vim.lsp.get_clients()
	if #clients == 0 then
		return
	end

	for _, client in ipairs(clients) do
		if client.name ~= "copilot" then
			client:stop(true)
		end
	end
end

---@param target WorkspaceTarget
---@return Path
local function expanded_target_dir(target)
	return Path:new(vim.fn.expand(target.dir))
end

---@param workspace Workspace
---@param session WorkspaceSession
---@return WorkspaceTarget
---@return WorkspaceTarget[]
---@return boolean
---@return boolean
local function sync_session_targets(session, workspace)
	local discovered_targets = utils.list_git_targets(session.dir)
	local removed_targets, current_target_removed, changed = utils.merge_session_targets(session, discovered_targets)

	for _, target in ipairs(removed_targets) do
		persist.delete_nvim_session_file(workspace, session, target)
	end

	return utils.get_current_target(session), removed_targets, current_target_removed, changed
end

---@param workspace Workspace
---@return boolean
local function sync_workspace_targets(workspace)
	local changed = false

	for _, session in ipairs(workspace.sessions) do
		local _, _, _, session_changed = sync_session_targets(session, workspace)
		changed = changed or session_changed
	end

	if utils.find_session(workspace, workspace.current_session_name) == nil and #workspace.sessions > 0 then
		workspace.current_session_name = workspace.sessions[1].name
		changed = true
	end

	if utils.find_session(workspace, workspace.last_session_name) == nil then
		workspace.last_session_name = nil
		changed = true
	end

	return changed
end

local function ensure_target_dir(target)
	local target_dir = expanded_target_dir(target)
	if target_dir:is_dir() then
		return true
	end

	if target.kind == "directory" then
		target_dir:mkdir({ parents = true })
		vim.notify("Created missing directory: " .. target_dir.filename)
		return true
	end

	return false
end

local function persist_current_state(skip_session_file)
	local current_workspace = state.get().current_workspace
	local current_session = state.get().current_session
	if current_workspace == nil or current_session == nil then
		return
	end

	local current_target = state.get().current_target or utils.get_current_target(current_session)

	pcall(save_named_buffers)
	toggleterms.close_visible_terms(true)
	require("user.utils").close_terminal_buffers()

	local toggled_types = require("user.utils").toggle_special_buffers({})
	if not skip_session_file and ensure_target_dir(current_target) then
		persist.write_nvim_session_file(current_workspace, current_session, current_target)
	end

	M.set_session_metadata(current_session, current_target, toggled_types)
	require("user.utils").close_non_terminal_buffers()
end

---@param workspace Workspace
---@param session WorkspaceSession
---@param target WorkspaceTarget
local function restore_target_state(workspace, session, target)
	state.get().current_workspace = workspace
	state.get().current_session = session
	state.get().current_target = target
	state.get().last_target = utils.find_target(session, session.last_target_name)
	workspace.current_session_name = session.name
	session.current_target_name = target.name
	vim.cmd.cd(vim.fn.fnameescape(target.dir))

	stop_lsp_clients()
	persist.source_nvim_session_file(workspace, session, target)

	local win = vim.api.nvim_get_current_win()
	local pos = vim.api.nvim_win_get_cursor(win)

	require("user.utils").toggle_special_buffers(target.toggled_types)
	bps.apply_breakpoints(target.breakpoints)
	M.set_session_metadata(session, target, {})
	toggleterms.toggle_active_terms(true)

	vim.api.nvim_set_current_win(win)
	vim.api.nvim_win_set_cursor(win, pos)
	vim.cmd.stopinsert()
	M.setup_lualine()
end

---@param name string
---@param dir string
---@return WorkspaceTarget
local function make_main_target(name, dir)
	return {
		name = name,
		kind = "directory",
		dir = utils.normalize_dir(dir),
		branch = nil,
		last_file = nil,
		last_file_line = nil,
		toggled_types = {},
		breakpoints = {},
		toggleterms = {},
	}
end

---@param session WorkspaceSession
---@param workspace Workspace
---@param target WorkspaceTarget
---@param persist_state boolean | nil
local function switch_to_target(session, workspace, target, persist_state)
	persist_current_state(false)

	local previous_workspace = state.get().current_workspace
	local previous_session = state.get().current_session
	local previous_target = state.get().current_target
	local workspace_changed = workspace ~= previous_workspace
	local session_changed = workspace_changed or session ~= previous_session
	local target_changed = session_changed or target ~= previous_target

	if workspace_changed then
		state.get().last_workspace = previous_workspace
		state.get().last_session = utils.find_session(workspace, workspace.last_session_name)
	elseif session_changed then
		state.get().last_session = previous_session
	end

	if not session_changed and target_changed and previous_session ~= nil and previous_target ~= nil then
		previous_session.last_target_name = previous_target.name
	end

	if not workspace_changed and session_changed and previous_workspace ~= nil and previous_session ~= nil then
		previous_workspace.last_session_name = previous_session.name
	end

	if not workspace_changed and session_changed then
		workspace.last_session_name = state.get().last_session and state.get().last_session.name or nil
	end
	state.get().current_workspace = workspace
	state.get().current_session = session
	state.get().current_target = target
	state.get().last_target = nil
	if not session_changed and previous_target ~= target then
		state.get().last_target = previous_target
	end

	restore_target_state(workspace, session, target)

	if persist_state ~= false then
		persist.persist_workspaces()
	end
end

---@param session WorkspaceSession
---@param target WorkspaceTarget | nil
---@return WorkspaceTarget | nil
local function resolve_synced_target(session, target)
	if target == nil then
		return nil
	end

	local matched_target = utils.find_target(session, target.name)
	if matched_target ~= nil then
		return matched_target
	end

	local normalized_dir = utils.normalize_dir(target.dir)
	for _, value in ipairs(session.targets or {}) do
		if utils.normalize_dir(value.dir) == normalized_dir then
			return value
		end
	end

	return nil
end

-- This function needs to be called whenever the tabs change
function M.setup_lualine()
	local tabs = {}
	local targets = {}
	local current_workspace = state.get().current_workspace
	local current_session = state.get().current_session

	for i, session in ipairs(current_workspace.sessions) do
		local is_selected = session.name == current_workspace.current_session_name
		local is_last_session = session.name == current_workspace.last_session_name

		tabs[i] = {
			mode = 2,
			color = function()
				return { fg = is_selected and colors.blue or colors.text }
			end,
			on_click = function()
				M.switch_session(session, current_workspace)
			end,
			function()
				local res = tostring(i) .. " " .. session.name
				if is_selected then
					return utils.icons.cur .. " " .. res
				elseif is_last_session then
					return utils.icons.last .. " " .. res
				end
				return res
			end,
		}
	end

	for i, target in ipairs((current_session and current_session.targets) or {}) do
		local is_selected = current_session.current_target_name == target.name
		local is_last_target = current_session.last_target_name == target.name

		targets[i] = {
			mode = 2,
			color = function()
				return { fg = is_selected and colors.green or colors.subtext1 }
			end,
			on_click = function()
				M.switch_target(target, current_session, current_workspace)
			end,
			function()
				local res = target.name
				if is_selected then
					return utils.icons.cur .. " " .. res
				elseif is_last_target then
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
			lualine_y = targets,
		},
	})
end

---@param session WorkspaceSession
---@param target WorkspaceTarget | nil
---@param toggled_types string[]
function M.set_session_metadata(session, target, toggled_types)
	target = target or utils.get_current_target(session)
	local buf_path = vim.fn.expand("%:p")
	---@cast buf_path string

	if buf_path ~= "" and Path:new(buf_path):exists() then
		target.last_file_line = unpack(vim.fn.getcurpos(), 2, 2)
		target.last_file = buf_path
	else
		target.last_file_line = nil
		target.last_file = nil
	end

	target.toggled_types = toggled_types
	target.breakpoints = bps.get_breakpoints()
end

---@param target_session WorkspaceSession | nil
---@param target_workspace Workspace
function M.switch_session(target_session, target_workspace)
	sync_workspace_targets(target_workspace)

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

	local target_target = utils.get_current_target(target_session)
	if target_session == state.get().current_session and target_target == state.get().current_target then
		return
	end

	exit_hydras()
	switch_to_target(target_session, target_workspace, target_target)
end

---@param target WorkspaceTarget | nil
---@param target_session WorkspaceSession | nil
---@param target_workspace Workspace | nil
function M.switch_target(target, target_session, target_workspace)
	target_workspace = target_workspace or state.get().current_workspace
	target_session = target_session or state.get().current_session
	if target_workspace == nil or target_session == nil then
		vim.notify("No current session", vim.log.levels.ERROR)
		return
	end

	local previous_target = target
	local current_target, _, current_target_removed = sync_session_targets(target_session, target_workspace)
	target = resolve_synced_target(target_session, previous_target)
		or current_target
		or utils.get_current_target(target_session)
	if current_target_removed and target.kind == "directory" then
		vim.notify("Current worktree target was removed, switched back to main", vim.log.levels.WARN)
	end

	if target_session == state.get().current_session and target == state.get().current_target then
		return
	end

	exit_hydras()
	switch_to_target(target_session, target_workspace, target)
end

function M.sync_current_session_targets()
	return M.refresh_current_session_targets(true)
end

---@param persist_current boolean | nil
function M.refresh_current_session_targets(persist_current)
	local workspace = state.get().current_workspace
	local session = state.get().current_session
	if workspace == nil or session == nil then
		return
	end

	local current_target = state.get().current_target or utils.get_current_target(session)
	if persist_current == true and current_target ~= nil and current_target.kind == "git_worktree" then
		persist_current_state(true)
	end
	local fallback_target, removed_targets, current_target_removed, changed = sync_session_targets(session, workspace)

	if current_target_removed then
		switch_to_target(session, workspace, fallback_target, false)
		persist.persist_workspaces()
		vim.notify("Current worktree target was removed, switched back to main", vim.log.levels.WARN)
		return
	end

	if changed or #removed_targets > 0 or current_target ~= fallback_target then
		state.get().current_target = fallback_target
		M.setup_lualine()
		persist.persist_workspaces()
	end
end

function M.sync_all_workspaces_targets()
	local changed = false
	for _, workspace in ipairs(state.get().workspaces) do
		changed = sync_workspace_targets(workspace) or changed
	end

	local current_session = state.get().current_session
	if current_session ~= nil then
		state.get().current_target = utils.get_current_target(current_session)
		state.get().last_target = utils.find_target(current_session, current_session.last_target_name)
	end

	if changed then
		M.setup_lualine()
		persist.persist_workspaces()
	end
end

function M.get_current_target()
	local current_session = state.get().current_session
	if current_session == nil then
		return nil
	end

	state.get().current_target = state.get().current_target or utils.get_current_target(current_session)
	return state.get().current_target
end

function M.get_current_target_display_name()
	local target = M.get_current_target()
	if target == nil or target.name == "main" then
		return nil
	end

	return target.name
end

function M.alternate_target()
	local session = state.get().current_session
	if session == nil then
		vim.notify("No current session", vim.log.levels.ERROR)
		return
	end

	local last_target = utils.find_target(session, session.last_target_name)
	if last_target == nil then
		vim.notify("No alternate target", vim.log.levels.ERROR)
		return
	end

	M.switch_target(last_target, session, state.get().current_workspace)
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
		dir = utils.normalize_dir(dir),
		current_target_name = "main",
		last_target_name = nil,
		targets = { make_main_target("main", dir) },
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
		return
	end

	for i, value in ipairs(workspace.sessions) do
		if value.name == name then
			table.remove(workspace.sessions, i)
			break
		end
	end

	for _, target in ipairs(session.targets or {}) do
		persist.delete_nvim_session_file(workspace, session, target)
	end

	if name == workspace.current_session_name then
		M.switch_session(workspace.sessions[1], workspace)
	else
		M.setup_lualine()
		persist.persist_workspaces()
	end
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
		last_session_name = nil,
		sessions = {
			{
				name = session_name,
				dir = utils.normalize_dir(dir),
				current_target_name = "main",
				last_target_name = nil,
				targets = { make_main_target("main", dir) },
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

	for i, workspace in ipairs(state.get().workspaces) do
		if workspace.name == name then
			table.remove(state.get().workspaces, i)
			break
		end
	end

	if name == state.get().current_workspace.name then
		if #state.get().workspaces == 0 then
			persist.purge_workspaces()
			persist.load_workspaces()
			return
		end

		M.switch_session(nil, state.get().workspaces[1])
	end

	if state.get().last_workspace and name == state.get().last_workspace.name then
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
