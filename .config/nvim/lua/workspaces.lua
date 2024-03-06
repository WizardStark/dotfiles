local M = {}

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

---@type Workspace[]
local workspaces = {}

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
local workspaces_path = vim.fn.stdpath("data") .. "/workspaces/"

---@type string
local sessions_path = workspaces_path .. "sessions/"

local lualine = require("lualine")
local Path = require("plenary.path")

local icons = {
	last = "",
	cur = "",
}

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

	local file = sessions_dir:joinpath(Path:new(get_nvim_session_filename(workspace, session)))

	vim.api.nvim_command("mksession! " .. file.filename)
end

---@param workspace Workspace
---@param session Session
local function source_nvim_session_file(workspace, session)
	local file = Path:new(sessions_path):joinpath(get_nvim_session_filename(workspace, session))

	if not file:exists() then
		vim.cmd.cd(session.dir)
		vim.cmd.enew()
		return
	end

	vim.api.nvim_command("silent source " .. file.filename)
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
				return { fg = is_selected and "#80a0ff" or "#9e9e9e" }
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
			lualine_a = { {
				mode = 2,
				function()
					return current_workspace.name
				end,
			} },
			lualine_b = tabs,
			lualine_c = {
				{
					mode = 2,
					color = { fg = "#303030" },
					function()
						return ""
					end,
				},
			},
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

local function clean_non_terminal_buffers()
	local current_buffer = vim.api.nvim_get_current_buf()
	for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(buffer) and buffer ~= current_buffer then
			vim.api.nvim_buf_delete(buffer, { force = true })
		end
	end
	vim.api.nvim_buf_delete(current_buffer, { force = true })
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
	clean_non_terminal_buffers()

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
			vim.log.levels.error
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
			vim.log.levels.error
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

function M.delete_session(name)
	if find_session(current_workspace, name) == nil then
		vim.notify("That session does not exist", vim.log.levels.ERROR)
		return
	end

	for i, v in ipairs(current_workspace.sessions) do
		if v.name == name then
			table.remove(current_workspace.sessions, i)
			break
		end
	end

	--TODO: swap sessions if delete current
	setup_lualine()
	M.persist_workspaces()
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

--TODO: maybe make these more generic, so you can rename any session instead of just the current one
function M.rename_current_workspace(name)
	if not verify_workspace_name(name) then
		return
	end

	if find_workspace(name) ~= nil then
		vim.notify("An workspace with that name already exists", vim.log.levels.ERROR)
		return
	end

	current_workspace.name = name

	setup_lualine()

	M.persist_workspaces()
end

function M.delete_workspace(name)
	if find_workspace(name) == nil then
		vim.notify("An workspace with that name does not exist", vim.log.levels.ERROR)
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

function M.switch_session_by_index(idx)
	idx = tonumber(idx)

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
		workspaces = workspaces,
	}

	workspaces_file:write(vim.fn.json_encode(workspace_data), "w")
end

function M.load_workspaces()
	local workspaces_file = Path:new(workspaces_path .. Path.path.sep .. "workspaces.json")

	local workspace_data = {}

	local should_persist = false

	if workspaces_file:exists() then
		workspace_data = vim.fn.json_decode(workspaces_file:read())
	else
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

	current_workspace = workspace

	local session = find_session(current_workspace, current_workspace.current_session)

	if session == nil then
		vim.notify(
			string.format(
				"There was an error loading the current workspace '%s' its current session '%s' was not found in workspaces.json",
				workspace_data.current_workspace,
				current_workspace.current_session
			),
			vim.log.levels.error
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

require("legendary").keymaps({
	-- tabline
	{
		mode = { "n" },
		"<leader>sn",
		M.next_session,
		description = "Next session",
	},
	{
		mode = { "n" },
		"<leader>sp",
		M.previous_session,
		description = "Previous session",
	},
	{
		mode = { "n" },
		"<leader>z",
		M.alternate_session,
		description = "Alternate session",
	},
	{
		mode = { "n" },
		"<leader>sz",
		M.alternate_workspace,
		description = "Alternate workspace",
	},
	{
		mode = { "n" },
		"<leader>sa",
		M.pick_session,
		description = "Pick session",
	},
	{
		mode = { "n" },
		"<leader>si",
		M.pick_workspace,
		description = "Pick workspace",
	},
})

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

---@param on_success fun(name: string, dir: string)
---@param on_cancel fun()
local function input_new_session(on_success, on_cancel)
	vim.ui.input({
		prompt = "New session name",
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

require("legendary").funcs({
	-- tabline
	{
		function()
			vim.ui.input({
				prompt = "Session number",
				default = "",
				kind = "tabline",
			}, function(idx_input)
				if idx_input then
					M.switch_session_by_index(idx_input)
				else
					vim.notify("Switch cancelled")
					return
				end
			end)
		end,
		description = "Switch session",
	},
	{
		function()
			input_new_session(function(name, dir)
				M.create_session(name, dir)
			end, function()
				vim.notify("Creation cancelled")
			end)
		end,
		description = "Create session",
	},
	{
		function()
			vim.ui.input({
				prompt = "New name",
				default = current_workspace.current_session,
				kind = "tabline",
			}, function(input)
				if input then
					M.rename_current_session(input)
				else
					vim.notify("Rename cancelled")
				end
			end)
		end,
		description = "Rename session",
	},
	{
		function()
			vim.ui.input({
				prompt = "New workspace name",
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
		end,
		description = "Create workspace",
	},
	{
		M.load_workspaces,
		description = "Load workspaces",
	},
	{
		function()
			vim.ui.input({
				prompt = "New name",
				default = current_workspace.name,
				kind = "tabline",
			}, function(input)
				if input then
					M.rename_current_workspace(input)
				else
					vim.notify("Rename cancelled")
				end
			end)
		end,
		description = "Rename workspace",
	},
})

return M
