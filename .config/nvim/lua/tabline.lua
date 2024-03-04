local M = {}

---@class Instance
---@field name string
---@field sessions Session[]
---@field current_session string
---@field last_session string | nil

---@class Session
---@field name string
---@field dir string
---@field last_file string | nil
---@field last_file_line number | nil

---@type Instance[]
local instances = {}

---@type Instance | nil
local current_instance = nil
---@type Instance | nil
local last_instance = nil

local current_session_index = -1

---@type string
local instances_path = vim.fn.stdpath("data") .. "/instances/"

local lualine = require("lualine")
local Path = require("plenary.path")

-- This function needs to be called whenever the tabs change
local function setup_lualine()
	if current_instance == nil then
		vim.notify("Instance is nil, cannot setup lualine", vim.log.levels.ERROR)
		return
	end

	local tabs = {}

	for i, v in ipairs(current_instance.sessions) do
		local is_selected = v.name == current_instance.current_session

		tabs[i] = {
			mode = 2,
			color = function(section)
				return { fg = is_selected and "#80a0ff" or "#9e9e9e" }
			end,
			on_click = function()
				M.switch_session(v.name)
			end,
			function()
				return tostring(i) .. " " .. v.name
			end,
		}
	end

	lualine.setup({
		tabline = {
			lualine_a = { {
				mode = 2,
				function()
					return current_instance.name
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

---@param instance Instance
---@param session_name string
---@return Session | nil, number
local function find_session(instance, session_name)
	for i, v in ipairs(instance.sessions) do
		if v.name == session_name then
			return v, i
		end
	end

	return nil, -1
end

---@param instance_name string
---@return Instance | nil
local function find_instance(instance_name)
	for _, v in ipairs(instances) do
		if v.name == instance_name then
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

---Verifies is a given instance name is valid
---@param name string
---@return boolean
local function verify_instance_name(name)
	if name == nil or name == "" then
		vim.notify("Instance names cannot be nil or empty", vim.log.levels.ERROR)
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

function M.rename_current_session(name)
	if current_instance == nil then
		vim.notify("Instance is nil, cannot rename session", vim.log.levels.ERROR)
		return
	end

	local current_session = find_session(current_instance, current_instance.current_session)

	if current_session == nil then
		vim.notify("No current session", vim.log.levels.ERROR)
		return
	end

	if not verify_session_name(name) then
		return
	end

	if find_session(current_instance, name) ~= nil then
		vim.notify("A session with that name already exists", vim.log.levels.ERROR)
		return
	end

	current_session.name = name
	current_instance.current_session = name

	setup_lualine()

	M.persist_instances()
end

function M.create_session(name, dir)
	if current_instance == nil then
		vim.notify("Instance is nil, cannot create session", vim.log.levels.ERROR)
		return
	end

	if not verify_session_name(name) then
		return
	end

	if not Path:new(vim.fn.expand(dir)):exists() then
		vim.notify("That directory does not exist", vim.log.levels.ERROR)
		return
	end

	if find_session(current_instance, name) ~= nil then
		vim.notify("An session with that name already exists", vim.log.levels.ERROR)
		return
	end

	table.insert(current_instance.sessions, {
		name = name,
		dir = dir,
	})

	-- If the new session is the first one, swap to it
	if #current_instance.sessions == 1 then
		M.switch_session(name)
	else
		setup_lualine()
		M.persist_instances()
	end
end

function M.delete_session(name)
	if current_instance == nil then
		vim.notify("Instance is nil, cannot delete session", vim.log.levels.ERROR)
		return
	end

	if find_session(current_instance, name) == nil then
		vim.notify("That session does not exist", vim.log.levels.ERROR)
		return
	end

	for i, v in ipairs(current_instance.sessions) do
		if v.name == name then
			table.remove(current_instance.sessions, i)
			break
		end
	end

	--TODO: swap sessions if delete current
	setup_lualine()

	M.persist_instances()
end

function M.create_instance(name)
	if find_instance(name) ~= nil then
		vim.notify("An instance with that name already exists", vim.log.levels.ERROR)
		return
	end

	table.insert(instances, {
		name = name,
		sessions = {},
	})

	M.persist_instances()
end

--TODO: maybe make these more generic, so you can rename any session instead of just the current one
function M.rename_current_instance(name)
	if current_instance == nil then
		vim.notify("Instance is nil, cannot rename it", vim.log.levels.ERROR)
		return
	end

	if not verify_instance_name(name) then
		return
	end

	if find_instance(name) ~= nil then
		vim.notify("An instance with that name already exists", vim.log.levels.ERROR)
		return
	end

	current_instance.name = name

	setup_lualine()

	M.persist_instances()
end

function M.delete_instance(name)
	if find_instance(name) == nil then
		vim.notify("An instance with that name does not exist", vim.log.levels.ERROR)
		return
	end

	for i, v in ipairs(instances) do
		if v.name == name then
			table.remove(instances, i)
			break
		end
	end

	if current_instance ~= nil and name == current_instance.name then
		-- If the current session is the last one delete the local file and recreate it
		if #instances == 0 then
			M.purge_instances()
			M.load_instances()
		end

		M.switch_instance(instances[1].name)
	end

	M.persist_instances()
end

function M.switch_session_by_index(idx)
	if current_instance == nil then
		vim.notify("Instance is nil, cannot switch session", vim.log.levels.ERROR)
		return
	end

	idx = tonumber(idx)

	if idx < 1 or idx > #current_instance.sessions then
		vim.notify("Could not find a session with that index", vim.log.levels.ERROR)
		return
	end

	M.switch_session(current_instance.sessions[idx].name)
end

function M.switch_session(name)
	if current_instance == nil then
		vim.notify("Instance is nil, cannot switch session", vim.log.levels.ERROR)
		return
	end

	local current_session, _ = find_session(current_instance, current_instance.current_session)

	if current_session ~= nil then
		set_session_metadata(current_session)
	end

	local target_session, i = find_session(current_instance, name)

	if target_session == nil then
		vim.notify("Could not find a session with that name", vim.log.levels.ERROR)
		return
	end

	current_session_index = i
	current_instance.last_session = current_instance.current_session
	current_instance.current_session = target_session.name

	require("session_manager").save_current_session()
	vim.cmd.wa()
	vim.cmd.cd(target_session.dir)
	require("session_manager").load_current_dir_session()

	set_session_metadata(target_session)

	setup_lualine()

	M.persist_instances()
end

function M.alternate_session()
	if current_instance == nil then
		vim.notify("Current instance is nil", vim.log.levels.ERROR)
		return
	end

	if current_instance.last_session == nil then
		vim.notify("No alternate session", vim.log.levels.ERROR)
		return
	end

	M.switch_session(current_instance.last_session)
end

function M.next_session()
	if current_instance == nil then
		vim.notify("Current instance is nil", vim.log.levels.ERROR)
		return
	end

	current_session_index = current_session_index % #current_instance.sessions + 1

	M.switch_session(current_instance.sessions[current_session_index].name)
end

function M.previous_session()
	if current_instance == nil then
		vim.notify("Current instance is nil", vim.log.levels.ERROR)
		return
	end

	if current_session_index == 1 then
		current_session_index = #current_instance.sessions
	else
		current_session_index = (current_session_index - 1) % #current_instance.sessions
	end

	M.switch_session(current_instance.sessions[current_session_index].name)
end

---@param name string
---@param session_name string | nil Session to switch to after switching instances. If nil it will use the current_session
function M.switch_instance(name, session_name)
	local switch_instance = find_instance(name)

	if switch_instance == nil then
		vim.notify("Could not find an instance with that name", vim.log.levels.ERROR)
		return
	end

	last_instance = current_instance
	current_instance = switch_instance

	require("session_manager").save_current_session()
	vim.cmd.wa()

	if session_name == nil then
		if #switch_instance.sessions > 0 and switch_instance.current_session ~= nil then
			local session = find_session(switch_instance, switch_instance.current_session)
			if session ~= nil then
				current_instance.last_session = current_instance.current_session
				current_instance.current_session = session.name
				vim.cmd.cd(session.dir)

				require("session_manager").load_current_dir_session()
				set_session_metadata(session)
			end
		else
			vim.cmd.cd("~")
		end
	else
		local session = find_session(switch_instance, session_name)
		if session ~= nil then
			current_instance.last_session = current_instance.current_session
			current_instance.current_session = session_name
			vim.cmd.cd(session.dir)

			require("session_manager").load_current_dir_session()
			set_session_metadata(session)
		end
	end

	setup_lualine()

	M.persist_instances()
end

function M.alternate_instance()
	if last_instance == nil then
		vim.notify("No alternate instance", vim.log.levels.ERROR)
		return
	end

	M.switch_instance(last_instance.name)
end

function M.persist_instances()
	if current_instance == nil then
		vim.notify("Cannot persist nil instance", vim.log.levels.ERROR)
		return
	end

	local instances_dir = Path:new(instances_path)

	if not instances_dir:is_dir() then
		instances_dir:mkdir()
	end

	local instances_file = Path:new(instances_path .. Path.path.sep .. "instances.json")
	instances_file:touch()

	local instance_data = {
		current_instance = current_instance.name,
		instances = instances,
	}

	instances_file:write(vim.fn.json_encode(instance_data), "w")
end

function M.load_instances()
	local instances_file = Path:new(instances_path .. Path.path.sep .. "instances.json")

	local instance_data = {}

	local should_persist = false

	if instances_file:exists() then
		instance_data = vim.fn.json_decode(instances_file:read())
	else
		instance_data = {
			current_instance = "dotfiles",
			last_instance = nil,
			instances = {
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

	instances = instance_data.instances
	current_instance = find_instance(instance_data.current_instance)

	if current_instance ~= nil then
		_, current_session_index = find_session(current_instance, current_instance.current_session)
	end

	if should_persist then
		M.persist_instances()
	end

	setup_lualine()
end

function M.purge_instances()
	local instances_file = Path:new(instances_path .. Path.path.sep .. "instances.json")

	if instances_file:exists() then
		instances_file:rm()
	end
end

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local previewers = require("telescope.previewers")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local instance_picker = function(opts)
	opts = opts or {}

	pickers
		.new(opts, {
			prompt_title = "Instances",
			finder = finders.new_table({
				results = instances,
				entry_maker = function(entry)
					return {
						value = entry.name,
						display = entry.name,
						ordinal = entry.name,
					}
				end,
			}),
			sorter = conf.generic_sorter(opts),
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					M.switch_instance(selection.value)
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

	for _, instance in ipairs(instances) do
		for _, session in ipairs(instance.sessions) do
			table.insert(results, {
				display = instance.name .. ": " .. session.name,
				value = {
					instance = instance.name,
					session = session,
				},
			})
		end
	end

	-- Update current session metadata so it displays correctly
	if current_instance ~= nil then
		local current_session = find_session(current_instance, current_instance.current_session)

		if current_session ~= nil then
			set_session_metadata(current_session)
		end
	end

	pickers
		.new(opts, {
			prompt_title = "Instances",
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
					M.switch_instance(selection.value.instance, selection.value.session.name)
				end)
				return true
			end,
		})
		:find()
end

function M.pick_instance()
	instance_picker(require("telescope.themes").get_dropdown({}))
end

function M.pick_session()
	session_picker()
end

function M.list_session_names()
	if current_instance == nil then
		vim.notify("Current instance is nil", vim.log.levels.ERROR)
		return
	end

	local sessions = current_instance.sessions
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
		M.alternate_instance,
		description = "Alternate instance",
	},
	{
		mode = { "n" },
		"<leader>ss",
		M.pick_session,
		description = "Pick session",
	},
	{
		mode = { "n" },
		"<leader>si",
		M.pick_instance,
		description = "Pick instance",
	},
})

require("session_manager")

require("legendary").autocmds({
	{
		"VimLeavePre",
		function()
			if current_instance ~= nil then
				local current_session = find_session(current_instance, current_instance.current_session)

				if current_session ~= nil then
					set_session_metadata(current_session)
				end
			end

			M.persist_instances()
		end,
	},
})

require("legendary").funcs({
	-- tabline
	{
		function()
			if current_instance == nil then
				vim.notify("Current instance is nil")
				return
			end
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
			if current_instance == nil then
				vim.notify("Cannot create a session if the current instance is nil")
				return
			end
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
							M.create_session(name_input, dir_input)
						else
							vim.notify("Creation cancelled")
							return
						end
					end)
				else
					vim.notify("Creation cancelled")
					return
				end
			end)
		end,
		description = "Create session",
	},
	{
		function()
			if current_instance == nil then
				vim.notify("Cannot rename if the current instance is nil")
				return
			end
			vim.ui.input({
				prompt = "New name",
				default = current_instance.current_session,
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
				prompt = "New instance name",
				default = "",
				kind = "tabline",
			}, function(input)
				if input then
					M.create_instance(input)
				else
					vim.notify("Creation cancelled")
				end
			end)
		end,
		description = "Create instance",
	},
	{
		M.load_instances,
		description = "Loads instances",
	},
	{
		function()
			if current_instance == nil then
				vim.notify("Cannot rename if the current instance is nil")
				return
			end
			vim.ui.input({
				prompt = "New name",
				default = current_instance.name,
				kind = "tabline",
			}, function(input)
				if input then
					M.rename_current_instance(input)
				else
					vim.notify("Rename cancelled")
				end
			end)
		end,
		description = "Rename instance",
	},
})

return M
