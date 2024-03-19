local M = {}

--TODO there is a bug on session restore for .tex files for autocmd group "syntaxenabled", I am
--pretty sure this is to do with the way vimtex does its configuration, and these global vars
--are run on plugin setup, so it should probably just not be persisted into the session files

---@class Workspace
---@field name string
---@field sessions Session[]
---@field current_session string
---@field last_session string | nil

---@class Session
---@field name string
---@field dir string
---@field last_file string | nil
---@field last_file_line number | nil

local Path = require("plenary.path")

---@type Workspace[]
local workspaces = {}

---@type table
local toggleterms = {}

---@type number
M.term_count = 0

---@type Workspace
local current_workspace = {
	current_session = "nvim",
	last_session = nil,
	name = "dotfiles",
	sessions = {
		{
			name = "nvim",
			dir = "~/dotfiles/.config/nvim",
		},
	},
}

---@type Workspace | nil
local last_workspace = nil

---@type Session
local current_session = current_workspace.sessions[0]

---@type Session | nil
local last_session = nil

---@type string
local workspaces_path = vim.fn.stdpath("data") .. Path.path.sep .. "workspaces"

---@type string
local sessions_path = workspaces_path .. Path.path.sep .. "sessions"

---@type string
local sessions_bak_path = sessions_path .. Path.path.sep .. "backups"

local lualine = require("lualine")

local icons = {
	last = "",
	cur = "",
}

local ok, colors = pcall(require("catppuccin.palettes").get_palette, "mocha")

if not ok or vim.g.colors_name == "moonfly" then
	colors = {
		blue = "#80a0ff",
		text = "#9e9e9e",
	}
end

---@param workspace Workspace
---@param session Session
---@return string
local function get_nvim_session_filename(workspace, session)
	local workspace_name = workspace.name:gsub(" ", "-")
	local session_name = session.name:gsub(" ", "-")

	return workspace_name .. "_" .. session_name
end

---@param workspace Workspace
---@param session Session
local function write_nvim_session_file(workspace, session)
	vim.cmd.cd(session.dir) -- Always persist defined session dir

	local sessions_dir = Path:new(sessions_path)

	if not sessions_dir:is_dir() then
		sessions_dir:mkdir()
	end

	local file = sessions_dir:joinpath(Path:new(get_nvim_session_filename(workspace, session)) .. ".vim")

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
---@param session Session
local function source_nvim_session_file(workspace, session)
	local session_filename = get_nvim_session_filename(workspace, session)
	local session_file = Path:new(sessions_path):joinpath(session_filename .. ".vim")

	if not session_file:exists() then
		vim.cmd.cd(session.dir)
		vim.cmd.enew()
		return
	end

	local source_ok, source_res = pcall(vim.api.nvim_command, "silent source " .. session_file.filename)

	if not source_ok then
		local corrupt_bak_file = Path:new(sessions_bak_path):joinpath(session_filename .. ".corrupt-bak.vim")

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
		local working_bak_file = Path:new(sessions_bak_path):joinpath(session_filename .. ".bak.vim")
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
		local bak_folder = Path:new(sessions_bak_path)

		if not bak_folder:is_dir() then
			bak_folder:mkdir()
		end

		-- If the source was successful, attempt to backup it. We will soft fail on backup fails
		pcall(Path.copy, session_file, {
			destination = Path:new(sessions_bak_path):joinpath(session_filename .. ".bak.vim"),
		})
	end
end

-- This function needs to be called whenever the tabs change
local function setup_lualine()
	local tabs = {}

	for i, v in ipairs(current_workspace.sessions) do
		local is_selected = v.name == current_workspace.current_session
		local is_last_session = v.name == current_workspace.last_session

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
					return icons.cur .. " " .. res
				elseif is_last_session then
					return icons.last .. " " .. res
				end
				return res
			end,
		}
	end

	lualine.setup({
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
local function find_session(workspace, session_name)
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
local function find_session_index(workspace, session)
	for i, v in ipairs(workspace.sessions) do
		if v.name == session.name then
			return i
		end
	end

	return nil
end

---@param workspace_name string
---@return Workspace | nil
local function find_workspace(workspace_name)
	for _, v in ipairs(workspaces) do
		if v.name == workspace_name then
			return v
		end
	end

	return nil
end

---Verifies is a given session name is valid
---@param name string
---@return boolean
local function verify_session_name(name)
	if name == nil or name == "" then
		vim.notify("Session names cannot be nil or empty", vim.log.levels.ERROR)
		return false
	end

	return true
end

---Verifies is a given workspace name is valid
---@param name string
---@return boolean
local function verify_workspace_name(name)
	if name == nil or name == "" then
		vim.notify("Workspace names cannot be nil or empty", vim.log.levels.ERROR)
		return false
	end

	return true
end

---Sets session metadata such as last file and line num
---@param session Session
local function set_session_metadata(session)
	local buf_path = vim.fn.expand("%:p")
	---@cast buf_path string:

	if buf_path ~= "" and Path:new(buf_path):exists() then
		session.last_file_line = unpack(vim.fn.getcurpos(), 2, 2)
		session.last_file = buf_path
	else
		session.last_file_line = nil
		session.last_file = nil
	end
end

--- Switch to target session, does nothing if it is equal to current session
---@param target_session Session
local function switch_session(target_session)
	if target_session == current_session then
		return
	end

	vim.cmd.wa()

	set_session_metadata(current_session)
	write_nvim_session_file(current_workspace, current_session)
	require("utils").close_non_terminal_buffers()

	last_session = current_session
	current_session = target_session

	current_workspace.last_session = last_session and last_session.name or nil
	current_workspace.current_session = target_session and target_session.name or nil

	source_nvim_session_file(current_workspace, target_session)
	set_session_metadata(target_session)
	setup_lualine()

	M.persist_workspaces()
end

--- Switch to a target workspace, does nothing if it is equal to current workspace
---@param target_workspace Workspace
local function switch_workspace(target_workspace)
	if target_workspace == current_workspace then
		return
	end

	if #target_workspace.sessions == 0 then
		vim.notify(
			string.format("Cannot switch to '%s', it has no sessions", target_workspace.name),
			vim.log.levels.ERROR
		)

		return
	end

	vim.cmd.wa()

	local target_session = find_session(target_workspace, target_workspace.current_session)

	if target_session == nil then
		vim.notify(
			string.format(
				"There was an error switching to workspace '%s' its current session '%s' was not found in workspaces.json",
				target_workspace.name,
				target_workspace.current_session
			),
			vim.log.levels.ERROR
		)
		return
	end

	write_nvim_session_file(current_workspace, current_session)
	set_session_metadata(current_session)

	last_session = find_session(target_workspace, target_workspace.last_session)
	current_session = target_session

	source_nvim_session_file(target_workspace, target_session)
	set_session_metadata(target_session)

	last_workspace = current_workspace
	current_workspace = target_workspace

	setup_lualine()
end

---@param on_success fun(name: string, dir: string)
---@param on_cancel fun()
local function input_new_session(on_success, on_cancel)
	vim.ui.input({
		prompt = "Create: New session name",
		default = "",
		kind = "tabline",
	}, function(name_input)
		if name_input then
			vim.ui.input({
				prompt = "New session directory",
				default = "",
				completion = "dir",
				kind = "tabline",
			}, function(dir_input)
				if dir_input then
					on_success(name_input, dir_input)
				else
					on_cancel()
				end
			end)
		else
			on_cancel()
		end
	end)
end

function M.rename_current_session_input()
	vim.ui.input({
		prompt = "Rename: New session name",
		default = current_workspace.current_session,
		kind = "tabline",
	}, function(input)
		if input then
			M.rename_current_session(input)
		else
			vim.notify("Rename cancelled")
		end
	end)
end

function M.rename_current_session(name)
	if not verify_session_name(name) then
		return
	end

	if find_session(current_workspace, name) ~= nil then
		vim.notify("A session with that name already exists in this workspace", vim.log.levels.ERROR)
		return
	end

	current_session.name = name
	current_workspace.current_session = name

	setup_lualine()
	M.persist_workspaces()
end

function M.create_session_input()
	input_new_session(function(name, dir)
		M.create_session(name, dir)
	end, function()
		vim.notify("Creation cancelled")
	end)
end

function M.create_session(name, dir)
	if not verify_session_name(name) then
		return
	end

	if not Path:new(vim.fn.expand(dir)):exists() then
		vim.notify("That directory does not exist", vim.log.levels.ERROR)
		return
	end

	if find_session(current_workspace, name) ~= nil then
		vim.notify("An session with that name already exists in this workspace", vim.log.levels.ERROR)
		return
	end

	---@type Session
	local session = {
		name = name,
		dir = dir,
	}

	table.insert(current_workspace.sessions, session)

	switch_session(session)
end

function M.delete_session_input()
	vim.ui.input({
		prompt = "Delete session",
		default = current_workspace.current_session,
		kind = "tabline",
	}, function(input)
		if input then
			M.delete_session(input)
		else
			vim.notify("Deletion cancelled")
		end
	end)
end

function M.delete_session(name)
	local session = find_session(current_workspace, name)
	if session == nil then
		vim.notify("That session does not exist", vim.log.levels.ERROR)
		return
	end

	local workspace = current_workspace

	if #workspace.sessions == 1 then
		M.delete_workspace(workspace.name)
	else
		for i, v in ipairs(workspace.sessions) do
			if v.name == name then
				table.remove(workspace.sessions, i)
				break
			end
		end
		if name == workspace.current_session then
			switch_session(workspace.sessions[1])
		end
	end

	local session_filename = get_nvim_session_filename(workspace, session)
	local session_file = Path:new(sessions_path):joinpath(session_filename .. ".vim")

	if session_file:exists() then
		session_file:rm()
	end

	setup_lualine()
	M.persist_workspaces()
end

function M.create_workspace_input()
	vim.ui.input({
		prompt = "Create: New workspace name",
		default = "",
		kind = "tabline",
	}, function(input)
		local on_cancel = function()
			vim.notify("Creation cancelled")
		end
		if input then
			input_new_session(function(session_name, dir)
				M.create_workspace(input, session_name, dir)
			end, on_cancel)
		else
			on_cancel()
		end
	end)
end

---@param name string
---@param session_name string
---@param dir string
function M.create_workspace(name, session_name, dir)
	if find_workspace(name) ~= nil then
		vim.notify("An workspace with that name already exists", vim.log.levels.ERROR)
		return
	end

	---@type Workspace
	local workspace = {
		name = name,
		current_session = session_name,
		sessions = {
			{
				name = session_name,
				dir = dir,
			},
		},
	}

	table.insert(workspaces, workspace)

	M.persist_workspaces()
end

function M.rename_current_workspace_input()
	vim.ui.input({
		prompt = "Rename: New workspace name",
		default = require("workspaces").get_current_workspace().name,
		kind = "tabline",
	}, function(input)
		if input then
			require("workspaces").rename_current_workspace(input)
		else
			vim.notify("Rename cancelled")
		end
	end)
end

function M.rename_current_workspace(name)
	if not verify_workspace_name(name) then
		return
	end

	if find_workspace(name) ~= nil then
		vim.notify("A session with that name already exists", vim.log.levels.ERROR)
		return
	end

	current_workspace.name = name

	setup_lualine()

	M.persist_workspaces()
end

function M.delete_workspace_input()
	vim.ui.input({
		prompt = "Delete workspace",
		default = current_workspace.name,
		kind = "tabline",
	}, function(input)
		if input then
			M.delete_workspace(input)
		else
			vim.notify("Deletion cancelled")
		end
	end)
end

function M.delete_workspace(name)
	if find_workspace(name) == nil then
		vim.notify("A workspace with that name does not exist", vim.log.levels.ERROR)
		return
	end

	for i, v in ipairs(workspaces) do
		if v.name == name then
			table.remove(workspaces, i)
			break
		end
	end

	if name == current_workspace.name then
		-- If the current session is the last one delete the local file and recreate it
		if #workspaces == 0 then
			M.purge_workspaces()
			M.load_workspaces()
		end

		switch_workspace(workspaces[1])
	end

	M.persist_workspaces()
end

---@param idx number
function M.switch_session_by_index(idx)
	if idx < 1 or idx > #current_workspace.sessions then
		vim.notify("Could not find a session with that index", vim.log.levels.ERROR)
		return
	end

	switch_session(current_workspace.sessions[idx])
end

function M.switch_session(name)
	local target_session = find_session(current_workspace, name)

	if target_session == nil then
		vim.notify("Could not find a session with that name", vim.log.levels.ERROR)
		return
	end

	switch_session(target_session)
end

function M.alternate_session()
	if last_session == nil then
		vim.notify("No alternate session", vim.log.levels.ERROR)
		return
	end

	switch_session(last_session)
end

function M.next_session()
	if current_session == nil then
		vim.notify("No current session", vim.log.levels.ERROR)
		return
	end

	local current_session_index = find_session_index(current_workspace, current_session)

	if current_session_index == nil then
		vim.notify("Could not find index of current session", vim.log.levels.ERROR)
		return
	end

	current_session_index = current_session_index % #current_workspace.sessions + 1

	switch_session(current_workspace.sessions[current_session_index])
end

function M.previous_session()
	if current_session == nil then
		vim.notify("No current session", vim.log.levels.ERROR)
		return
	end

	local current_session_index = find_session_index(current_workspace, current_session)

	if current_session_index == nil then
		vim.notify("Could not find index of current session", vim.log.levels.ERROR)
		return
	end

	if current_session_index == 1 then
		current_session_index = #current_workspace.sessions
	else
		current_session_index = (current_session_index - 1) % #current_workspace.sessions
	end

	switch_session(current_workspace.sessions[current_session_index])
end

---@param name string
function M.switch_workspace(name)
	local target_workspace = find_workspace(name)

	if target_workspace == nil then
		vim.notify("Could not find an workspace with that name", vim.log.levels.ERROR)
		return
	end

	switch_workspace(target_workspace)
end

function M.alternate_workspace()
	if last_workspace == nil then
		vim.notify("No alternate workspace", vim.log.levels.ERROR)
		return
	end

	switch_workspace(last_workspace)
end

function M.persist_workspaces()
	local workspaces_dir = Path:new(workspaces_path)

	if not workspaces_dir:is_dir() then
		workspaces_dir:mkdir()
	end

	local workspaces_file = Path:new(workspaces_path .. Path.path.sep .. "workspaces.json")
	workspaces_file:touch()

	local workspace_data = {
		current_workspace = current_workspace.name,
		last_workspace = last_workspace and last_workspace.name or nil,
		workspaces = workspaces,
	}

	workspaces_file:write(vim.fn.json_encode(workspace_data), "w")
end

function M.load_workspaces()
	local workspaces_file = Path:new(workspaces_path .. Path.path.sep .. "workspaces.json")

	local workspace_data = nil

	local should_persist = false

	if workspaces_file:exists() then
		workspace_data = vim.fn.json_decode(workspaces_file:read())
	end

	if not workspace_data then
		workspace_data = {
			current_workspace = "dotfiles",
			last_workspace = nil,
			workspaces = {
				{
					current_session = "nvim",
					last_session = nil,
					name = "dotfiles",
					sessions = {
						{
							name = "nvim",
							dir = "~/dotfiles/.config/nvim",
						},
					},
				},
			},
		}

		should_persist = true
	end

	workspaces = workspace_data.workspaces
	local workspace = find_workspace(workspace_data.current_workspace)

	if workspace == nil then
		vim.notify(
			string.format(
				"There was an error loading the current workspace '%s' it was not found in workspaces.json",
				workspace_data.current_workspace
			),
			vim.log.levels.ERROR
		)
		return
	end

	last_workspace = find_workspace(workspace_data.last_workspace)

	current_workspace = workspace

	local session = find_session(current_workspace, current_workspace.current_session)

	if session == nil then
		vim.notify(
			string.format(
				"There was an error loading the current workspace '%s' its current session '%s' was not found in workspaces.json",
				workspace_data.current_workspace,
				current_workspace.current_session
			),
			vim.log.levels.ERROR
		)
		return
	end

	current_session = session

	last_session = find_session(current_workspace, current_workspace.last_session)

	if should_persist then
		M.persist_workspaces()
	end

	source_nvim_session_file(current_workspace, current_session)

	setup_lualine()
end

function M.purge_workspaces()
	local workspaces_file = Path:new(workspaces_path .. Path.path.sep .. "workspaces.json")

	if workspaces_file:exists() then
		workspaces_file:rm()
	end
end

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local workspace_picker = function(opts)
	opts = opts or {}

	pickers
		.new(opts, {
			prompt_title = "Workspaces",
			finder = finders.new_table({
				results = workspaces,
				entry_maker = function(entry)
					---@cast entry Workspace
					local display = entry.name

					if entry == current_workspace then
						display = icons.cur .. " " .. display
					elseif entry == last_workspace then
						display = icons.last .. " " .. display
					end

					return {
						value = entry,
						display = display,
						ordinal = entry.name,
					}
				end,
			}),
			sorter = conf.generic_sorter(opts),
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					switch_workspace(selection.value)
				end)
				return true
			end,
		})
		:find()
end

local session_picker = function(opts)
	opts = opts or {}

	local results = {}

	local previewer = conf.grep_previewer(opts)

	for _, workspace in ipairs(workspaces) do
		for _, session in ipairs(workspace.sessions) do
			table.insert(results, {
				display = workspace.name .. ": " .. session.name,
				value = {
					workspace = workspace,
					session = session,
				},
			})
		end
	end

	-- Update current session metadata so it displays correctly
	if current_session ~= nil then
		set_session_metadata(current_session)
	end

	pickers
		.new(opts, {
			prompt_title = "Workspaces",
			finder = finders.new_table({
				results = results,
				entry_maker = function(entry)
					return {
						value = entry.value,
						display = entry.display,
						ordinal = entry.display,
						path = entry.value.session.last_file or "No last file",
						lnum = entry.value.session.last_file_line or nil,
					}
				end,
			}),
			previewer = previewer,
			sorter = conf.generic_sorter(opts),
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()

					switch_workspace(selection.value.workspace)
					switch_session(selection.value.session)
				end)
				return true
			end,
		})
		:find()
end

function M.pick_workspace()
	workspace_picker(require("telescope.themes").get_dropdown({}))
end

function M.pick_session()
	session_picker()
end

function M.list_session_names()
	local sessions = current_workspace.sessions
	local session_names = {}

	for _, value in ipairs(sessions) do
		table.insert(session_names, value.name)
	end
	return session_names
end

function M.get_current_workspace()
	return current_workspace
end

local function get_term_target()
	local target
	if next(vim.fn.argv()) ~= nil then
		target = "toggleterm"
	else
		target = current_workspace.name .. current_workspace.current_session
	end

	return target
end

function M.toggle_term(number, direction, size)
	local target = get_term_target()

	if not toggleterms[target] then
		toggleterms[target] = {}
	end

	if not toggleterms[target][number] then
		M.term_count = M.term_count + 1
		toggleterms[target][number] = M.term_count
	end

	local target_term = toggleterms[target][number]

	vim.cmd(":" .. target_term .. "ToggleTerm direction=" .. direction .. " size=" .. size)
end

function M.get_session_terms()
	return toggleterms[get_term_target()]
end

require("legendary").autocmds({
	{
		"VimLeavePre",
		function()
			write_nvim_session_file(current_workspace, current_session)
			set_session_metadata(current_session)
			M.persist_workspaces()
		end,
	},
})

return M
