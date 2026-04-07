local M = {}

local Path = require("plenary.path")
local state = require("workspaces.state")
local utils = require("workspaces.utils")

---@type string
M.workspaces_path = vim.fn.stdpath("data") .. Path.path.sep .. "workspaces"

---@type string
M.sessions_path = M.workspaces_path .. Path.path.sep .. "sessions"

---@type string
M.sessions_bak_path = M.sessions_path .. Path.path.sep .. "backups"

---@param workspace Workspace
---@param session WorkspaceSession
---@param target WorkspaceTarget
---@return string
function M.get_nvim_session_filename(workspace, session, target)
	local workspace_name = utils.sanitize_name(workspace.name)
	local session_name = utils.sanitize_name(session.name)
	local target_name = utils.sanitize_name(target.name)

	return workspace_name .. "_" .. session_name .. "__" .. target_name
end

function M.purge_session_files()
	local sessions_dir = Path:new(M.sessions_path)
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
---@param target WorkspaceTarget
function M.write_nvim_session_file(workspace, session, target)
	vim.cmd.cd(target.dir)

	local sessions_dir = Path:new(M.sessions_path)

	if not sessions_dir:is_dir() then
		sessions_dir:mkdir()
	end

	local file = sessions_dir:joinpath(Path:new(M.get_nvim_session_filename(workspace, session, target)) .. ".vim")

	local ok, res = pcall(vim.api.nvim_command, "mksession! " .. file.filename)

	if not ok then
		vim.notify(
			string.format(
				"Could not create session file for %s: %s [%s], the following error was thrown:\n %s",
				workspace.name,
				session.name,
				target.name,
				tostring(res)
			),
			vim.log.levels.ERROR
		)
	end
end

---@param workspace Workspace
---@param session WorkspaceSession
---@param target WorkspaceTarget
function M.source_nvim_session_file(workspace, session, target)
	local session_filename = M.get_nvim_session_filename(workspace, session, target)
	local session_file = Path:new(M.sessions_path):joinpath(session_filename .. ".vim")

	if not session_file:exists() then
		vim.cmd.cd(target.dir)
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
					"Could not source session file for %s: %s [%s]\nThe following error was thrown while trying to source the session file:\n%s\nBut while trying to backup the corrupted session file another error was thrown:\n%s\n!!! IMPORTANT: If you want to attemp to manually restore the session make a manual backup of it ('%s') now, any session switching or even exiting neovim can potentially overwrite the corrupted session file premanently.",
					workspace.name,
					session.name,
					target.name,
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
						"Could not source session file for %s: %s [%s]\nLast known good backup was restored. The corrupted session has been moved to '%s'\nThe following error was thrown while trying to source the session file:\n%s",
						workspace.name,
						session.name,
						target.name,
						corrupt_bak_file.filename,
						tostring(source_res)
					),
					vim.log.levels.WARN
				)
			else
				vim.notify(
					string.format(
						"Could not source session file for %s: %s [%s]\nLast known good backup was found but could not be restored. The corrupted session has been moved to '%s'\nThe following error was thrown while trying to source the session file:\n%s\nWhile trying to source the backup session the following error was thrown:\n%s",
						workspace.name,
						session.name,
						target.name,
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
					"Could not source session file for %s: %s [%s]\nNo backup was found. The corrupted session has been moved to '%s'\nThe following error was thrown while trying to source the session file:\n %s",
					workspace.name,
					session.name,
					target.name,
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

---@param workspace Workspace
---@param session WorkspaceSession
---@param target WorkspaceTarget
function M.delete_nvim_session_file(workspace, session, target)
	local session_filename = M.get_nvim_session_filename(workspace, session, target)
	local session_file = Path:new(M.sessions_path):joinpath(session_filename .. ".vim")
	if session_file:exists() then
		session_file:rm()
	end

	local backup_file = Path:new(M.sessions_bak_path):joinpath(session_filename .. ".bak.vim")
	if backup_file:exists() then
		backup_file:rm()
	end

	local corrupt_backup_file = Path:new(M.sessions_bak_path):joinpath(session_filename .. ".corrupt-bak.vim")
	if corrupt_backup_file:exists() then
		corrupt_backup_file:rm()
	end
end

function M.persist_workspaces()
	local workspaces_dir = Path:new(M.workspaces_path)

	if not workspaces_dir:is_dir() then
		workspaces_dir:mkdir()
	end

	local workspaces_file = Path:new(M.workspaces_path .. Path.path.sep .. "workspaces.json")
	workspaces_file:touch()

	local current_state = state.get()
	local workspace_data = {
		current_workspace_name = current_state.current_workspace.name,
		last_workspace_name = current_state.last_workspace and current_state.last_workspace.name or nil,
		workspaces = current_state.workspaces,
	}

	workspaces_file:write(vim.fn.json_encode(workspace_data), "w")
end

local function normalize_session_targets(session)
	if not session.targets then
		local target = {
			name = session.current_target_name or "main",
			kind = "directory",
			dir = utils.normalize_dir(session.dir),
			branch = nil,
			last_file = session.last_file,
			last_file_line = session.last_file_line,
			toggled_types = session.toggled_types or {},
			breakpoints = session.breakpoints or {},
			toggleterms = session.toggleterms or {},
		}
		session.targets = { target }
		session.current_target_name = target.name
		session.last_target_name = session.last_target_name or nil
	end

	for _, target in ipairs(session.targets) do
		target.dir = utils.normalize_dir(target.dir)
		target.kind = target.kind or (target.name == "main" and "directory" or "git_worktree")
		target.toggled_types = target.toggled_types or {}
		target.breakpoints = target.breakpoints or {}
		target.toggleterms = target.toggleterms or {}
		for _, term in ipairs(target.toggleterms) do
			state.get().term_count = state.get().term_count + 1
			term.global_id = state.get().term_count
		end
	end

	session.dir = utils.get_main_target(session).dir
	session.current_target_name = utils.get_current_target(session).name
	if utils.find_target(session, session.last_target_name) == nil then
		session.last_target_name = nil
	end

	session.toggled_types = nil
	session.breakpoints = nil
	session.toggleterms = nil
	session.last_file = nil
	session.last_file_line = nil
end

function M.load_workspaces()
	state.get().term_count = 0
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
			normalize_session_targets(session)
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
	state.get().current_target = utils.get_current_target(session)
	state.get().last_target = utils.find_target(session, session.last_target_name)

	if should_persist then
		M.persist_workspaces()
	end

	M.source_nvim_session_file(state.get().current_workspace, state.get().current_session, state.get().current_target)
	require("user.utils").toggle_special_buffers(state.get().current_target.toggled_types)
	if vim.list_contains(state.get().current_target.toggled_types, "pr-review") then
		local ok, reviewer = pcall(require, "github-pr-reviewer")
		if ok then
			reviewer.resume_review_session()
		end
	end
	require("workspaces.breakpoints").apply_breakpoints(state.get().current_target.breakpoints)
	require("workspaces.toggleterms").toggle_active_terms(true)
	require("workspaces.keymaps").setup_keymaps()
	vim.schedule(function()
		require("workspaces.workspaces").sync_all_workspaces_targets()
	end)
end

function M.purge_workspaces()
	local workspaces_file = Path:new(M.workspaces_path .. Path.path.sep .. "workspaces.json")

	if workspaces_file:exists() then
		workspaces_file:rm()
	end
end

return M
