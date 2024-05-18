local M = {}

local Path = require("plenary.path")
local state = require("workspaces.state")
local bps = require("workspaces.breakpoints")
local utils = require("workspaces.utils")
local toggleterms = require("workspaces.toggleterms")

---@type string
M.workspaces_path = vim.fn.stdpath("data") .. Path.path.sep .. "workspaces"

---@type string
local sessions_path = M.workspaces_path .. Path.path.sep .. "sessions"

---@type string
M.sessions_bak_path = sessions_path .. Path.path.sep .. "backups"

---@param workspace Workspace
---@param session WorkspaceSession
---@return string
function M.get_nvim_session_filename(workspace, session)
	local workspace_name = workspace.name:gsub(" ", "-")
	local session_name = session.name:gsub(" ", "-")

	return workspace_name .. "_" .. session_name
end

function M.purge_session_files()
	local sessions_dir = Path:new(sessions_path)
	vim.ui.input({
		prompt = "Are you sure you want to delete all sessions (yes/no)",
		default = "",
		kind = "tabline",
	}, function(input)
		if input == "yes" then
			sessions_dir:rm({ recursive = true })
		elseif not input or input == "no" then
			vim.notify("Session files deletion cancelled")
		else
			vim.notify('Confirmation failure, please type "yes" or "no"')
		end
	end)
end

---@param workspace Workspace
---@param session WorkspaceSession
function M.write_nvim_session_file(workspace, session)
	vim.cmd.cd(session.dir) -- Always persist defined session dir

	local sessions_dir = Path:new(sessions_path)

	if not sessions_dir:is_dir() then
		sessions_dir:mkdir()
	end

	local file = sessions_dir:joinpath(Path:new(M.get_nvim_session_filename(workspace, session)) .. ".vim")

	local ok, res = pcall(vim.api.nvim_command, "mksession! " .. file.filename)

	if not ok then
		vim.notify(
			string.format(
				"Could not create session file for %s: %s, the following error was thrown:\n %s",
				workspace.name,
				session.name,
				tostring(res)
			),
			vim.log.levels.ERROR
		)
	end
end

---@param workspace Workspace
---@param session WorkspaceSession
function M.source_nvim_session_file(workspace, session)
	local session_filename = M.get_nvim_session_filename(workspace, session)
	local session_file = Path:new(sessions_path):joinpath(session_filename .. ".vim")

	if not session_file:exists() then
		vim.cmd.cd(session.dir)
		vim.cmd.enew()
		return
	end

	local source_ok, source_res = pcall(vim.api.nvim_command, "silent source " .. session_file.filename)

	if not source_ok then
		local corrupt_bak_file = Path:new(M.sessions_bak_path):joinpath(session_filename .. ".corrupt-bak.vim")

		if corrupt_bak_file:exists() then
			corrupt_bak_file:rm()
		end

		-- Make backup in case the user wants to manually fix the session file
		local corrupt_bak_save_ok, corrupt_bak_save_res = pcall(Path.rename, session_file, {
			new_name = corrupt_bak_file.filename,
		})

		if not corrupt_bak_save_ok then
			vim.notify(
				string.format(
					"Could not source session file for %s: %s\nThe following error was thrown while trying to source the session file:\n%s\nBut while trying to backup the corrupted session file another error was thrown:\n%s\n!!! IMPORTANT: If you want to attemp to manually restore the session make a manual backup of it ('%s') now, any session switching or even exiting neovim can potentially overwrite the corrupted session file premanently.",
					workspace.name,
					session.name,
					tostring(source_res),
					tostring(corrupt_bak_save_res),
					session_file.filename
				),
				vim.log.levels.ERROR
			)
		end

		-- Try to load a previous good version
		local working_bak_file = Path:new(M.sessions_bak_path):joinpath(session_filename .. ".bak.vim")
		if working_bak_file:exists() then
			local bak_source_ok, bak_source_res =
				pcall(vim.api.nvim_command, "silent source " .. working_bak_file.filename)

			if bak_source_ok then
				vim.notify(
					string.format(
						"Could not source session file for %s: %s\nLast known good backup was restored. The corrupted session has been moved to '%s'\nThe following error was thrown while trying to source the session file:\n%s",
						workspace.name,
						session.name,
						corrupt_bak_file.filename,
						tostring(source_res)
					),
					vim.log.levels.WARN
				)
			else
				vim.notify(
					string.format(
						"Could not source session file for %s: %s\nLast known good backup was found but could not be restored. The corrupted session has been moved to '%s'\nThe following error was thrown while trying to source the session file:\n%s\nWhile trying to source the backup session the following error was thrown:\n%s",
						workspace.name,
						session.name,
						corrupt_bak_file.filename,
						tostring(source_res),
						tostring(bak_source_res)
					),
					vim.log.levels.ERROR
				)
			end
		else
			vim.notify(
				string.format(
					"Could not source session file for %s: %s\nNo backup was found. The corrupted session has been moved to '%s'\nThe following error was thrown while trying to source the session file:\n %s",
					workspace.name,
					session.name,
					corrupt_bak_file.filename,
					tostring(source_res)
				),
				vim.log.levels.ERROR
			)
		end
	else
		local bak_folder = Path:new(M.sessions_bak_path)

		if not bak_folder:is_dir() then
			bak_folder:mkdir()
		end

		-- If the source was successful, attempt to backup it. We will soft fail on backup fails
		pcall(Path.copy, session_file, {
			destination = Path:new(M.sessions_bak_path):joinpath(session_filename .. ".bak.vim"),
		})
	end
end

function M.persist_workspaces()
	local workspaces_dir = Path:new(M.workspaces_path)

	if not workspaces_dir:is_dir() then
		workspaces_dir:mkdir()
	end

	local workspaces_file = Path:new(M.workspaces_path .. Path.path.sep .. "workspaces.json")
	workspaces_file:touch()

	local marks_file = Path:new(M.workspaces_path .. Path.path.sep .. "marks.json")
	marks_file:touch()

	local current_state = state.get()
	local workspace_data = {
		current_workspace_name = current_state.current_workspace.name,
		last_workspace_name = current_state.last_workspace and current_state.last_workspace.name or nil,
		workspaces = current_state.workspaces,
	}

	marks_file:write(vim.fn.json_encode(current_state.marks), "w")
	workspaces_file:write(vim.fn.json_encode(workspace_data), "w")
end

local function load_marks()
	local marks_file = Path:new(M.workspaces_path .. Path.path.sep .. "marks.json")
	local marks_data = nil
	if marks_file:exists() then
		marks_data = vim.fn.json_decode(marks_file:read())
	end

	if not marks_data then
		return
	end

	state.get().marks = marks_data
end

function M.load_workspaces()
	local workspaces_file = Path:new(M.workspaces_path .. Path.path.sep .. "workspaces.json")
	local workspace_data = nil
	local should_persist = false

	if workspaces_file:exists() then
		workspace_data = vim.fn.json_decode(workspaces_file:read())
	end

	if not workspace_data then
		workspace_data = state.default_workspace_data
		should_persist = true
	end

	if workspace_data["current_workspace"] then
		workspace_data["current_workspace_name"] = workspace_data["current_workspace"]
		workspace_data["current_workspace"] = nil
	end

	if workspace_data["last_workspace"] then
		workspace_data["last_workspace_name"] = workspace_data["last_workspace"]
		workspace_data["last_workspace"] = nil
	end

	for _, workspace in ipairs(workspace_data.workspaces) do
		if workspace["current_session"] then
			workspace["current_session_name"] = workspace["current_session"]
			workspace["current_session"] = nil
		end
		if workspace["last_session"] then
			workspace["last_session_name"] = workspace["last_session"]
			workspace["last_session"] = nil
		end
		for _, session in ipairs(workspace.sessions) do
			if not session.toggled_types then
				session.toggled_types = {}
			end
			if not session.breakpoints then
				session.breakpoints = {}
			end
			if not session.toggleterms then
				session.toggleterms = {}
			else
				for _, term in ipairs(session.toggleterms) do
					state.get().term_count = state.get().term_count + 1
					term.global_id = state.get().term_count
				end
			end
		end
	end

	state.get().workspaces = workspace_data.workspaces
	local workspace = utils.find_workspace(workspace_data.current_workspace_name)

	if workspace == nil then
		vim.notify(
			string.format(
				"There was an error loading the current workspace '%s' it was not found in workspaces.json",
				workspace_data.current_workspace_name
			),
			vim.log.levels.ERROR
		)
		return
	end

	state.get().last_workspace = utils.find_workspace(workspace_data.last_workspace_name)
	state.get().current_workspace = workspace
	local current_workspace = state.get().current_workspace

	local session = utils.find_session(current_workspace, current_workspace.current_session_name)

	if session == nil then
		vim.notify(
			string.format(
				"There was an error loading the current workspace '%s' its current session '%s' was not found in workspaces.json",
				workspace_data.current_workspace_name,
				current_workspace.current_session_name
			),
			vim.log.levels.ERROR
		)
		return
	end

	state.get().current_session = session
	state.get().last_session = utils.find_session(current_workspace, current_workspace.last_session_name)

	if should_persist then
		M.persist_workspaces()
	end

	M.source_nvim_session_file(state.get().current_workspace, state.get().current_session)
	require("utils").toggle_special_buffers(state.get().current_session.toggled_types)
	bps.apply_breakpoints(session.breakpoints)
	toggleterms.toggle_visible_terms(false)
	load_marks()
end

function M.purge_workspaces()
	local workspaces_file = Path:new(M.workspaces_path .. Path.path.sep .. "workspaces.json")

	if workspaces_file:exists() then
		workspaces_file:rm()
	end
end

return M
