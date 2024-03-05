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

---@type Instance
local current_instance = {
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

---@type Instance | nil
local last_instance = nil

---@type Session
local current_session = current_instance.sessions[0]

---@type Session | nil
local last_session = nil

---@type string
local instances_path = vim.fn.stdpath("data") .. "/instances/"

---@type string
local sessions_path = instances_path .. "sessions/"

local lualine = require("lualine")
local Path = require("plenary.path")

local icons = {
	last = "",
	cur = "",
}

---@param instance Instance
---@param session Session
---@return string
local function get_nvim_session_filename(instance, session)
	local instance_name = instance.name:gsub(" ", "-")
	local session_name = session.name:gsub(" ", "-")

	return instance_name .. "_" .. session_name
end

---@param instance Instance
---@param session Session
local function write_nvim_session_file(instance, session)
	vim.cmd.cd(session.dir) -- Always persist defined session dir

	local sessions_dir = Path:new(sessions_path)

	if not sessions_dir:is_dir() then
		sessions_dir:mkdir()
	end

	local file = sessions_dir:joinpath(Path:new(get_nvim_session_filename(instance, session)))

	vim.api.nvim_command("mksession! " .. file.filename)
end

---@param instance Instance
---@param session Session
local function source_nvim_session_file(instance, session)
	local file = Path:new(sessions_path):joinpath(get_nvim_session_filename(instance, session))

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

	for i, v in ipairs(current_instance.sessions) do
		local is_selected = v.name == current_instance.current_session
		local is_last_session = v.name == current_instance.last_session

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
---@return Session | nil
local function find_session(instance, session_name)
	for _, v in ipairs(instance.sessions) do
		if v.name == session_name then
			return v
		end
	end

	return nil
end

---@param instance Instance
---@param session Session
---@return number | nil
local function find_session_index(instance, session)
	for i, v in ipairs(instance.sessions) do
		if v.name == session.name then
			return i
		end
	end

	return nil
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

--- Switch to target session, does nothing if it is equal to current session
---@param target_session Session
local function switch_session(target_session)
	if target_session == current_session then
		return
	end

	vim.cmd.wa()

	set_session_metadata(current_session)
	write_nvim_session_file(current_instance, current_session)

	last_session = current_session
	current_session = target_session

	current_instance.last_session = last_session and last_session.name or nil
	current_instance.current_session = target_session and target_session.name or nil

	source_nvim_session_file(current_instance, target_session)
	set_session_metadata(target_session)
	setup_lualine()

	M.persist_instances()
end

--- Switch to a target instance, does nothing if it is equal to current instance
---@param target_instance Instance
local function switch_instance(target_instance)
	if target_instance == current_instance then
		return
	end

	if #target_instance.sessions == 0 then
		vim.notify(
			string.format("Cannot switch to '%s', it has no sessions", target_instance.name),
			vim.log.levels.error
		)

		return
	end

	vim.cmd.wa()

	local target_session = find_session(target_instance, target_instance.current_session)

	if target_session == nil then
		vim.notify(
			string.format(
				"There was an error switching to instance '%s' its current session '%s' was not found in instances.json",
				target_instance.name,
				target_instance.current_session
			),
			vim.log.levels.error
		)
		return
	end

	write_nvim_session_file(current_instance, current_session)
	set_session_metadata(current_session)

	last_session = find_session(target_instance, target_instance.last_session)
	current_session = target_session

	source_nvim_session_file(target_instance, target_session)
	set_session_metadata(target_session)

	last_instance = current_instance
	current_instance = target_instance

	setup_lualine()
end

function M.rename_current_session(name)
	if not verify_session_name(name) then
		return
	end

	if find_session(current_instance, name) ~= nil then
		vim.notify("A session with that name already exists in this instance", vim.log.levels.ERROR)
		return
	end

	current_session.name = name
	current_instance.current_session = name

	setup_lualine()
	M.persist_instances()
end

function M.create_session(name, dir)
	if not verify_session_name(name) then
		return
	end

	if not Path:new(vim.fn.expand(dir)):exists() then
		vim.notify("That directory does not exist", vim.log.levels.ERROR)
		return
	end

	if find_session(current_instance, name) ~= nil then
		vim.notify("An session with that name already exists in this instance", vim.log.levels.ERROR)
		return
	end

	---@type Session
	local session = {
		name = name,
		dir = dir,
	}

	table.insert(current_instance.sessions, session)

	switch_session(session)
end

function M.delete_session(name)
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

---@param name string
---@param session_name string
---@param dir string
function M.create_instance(name, session_name, dir)
	if find_instance(name) ~= nil then
		vim.notify("An instance with that name already exists", vim.log.levels.ERROR)
		return
	end

	---@type Instance
	local instance = {
		name = name,
		current_session = session_name,
		sessions = {
			{
				name = session_name,
				dir = dir,
			},
		},
	}

	table.insert(instances, instance)

	M.persist_instances()
end

--TODO: maybe make these more generic, so you can rename any session instead of just the current one
function M.rename_current_instance(name)
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

	if name == current_instance.name then
		-- If the current session is the last one delete the local file and recreate it
		if #instances == 0 then
			M.purge_instances()
			M.load_instances()
		end

		switch_instance(instances[1])
	end

	M.persist_instances()
end

function M.switch_session_by_index(idx)
	idx = tonumber(idx)

	if idx < 1 or idx > #current_instance.sessions then
		vim.notify("Could not find a session with that index", vim.log.levels.ERROR)
		return
	end

	switch_session(current_instance.sessions[idx])
end

function M.switch_session(name)
	local target_session = find_session(current_instance, name)

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

	local current_session_index = find_session_index(current_instance, current_session)

	if current_session_index == nil then
		vim.notify("Could not find index of current session", vim.log.levels.ERROR)
		return
	end

	current_session_index = current_session_index % #current_instance.sessions + 1

	switch_session(current_instance.sessions[current_session_index])
end

function M.previous_session()
	if current_session == nil then
		vim.notify("No current session", vim.log.levels.ERROR)
		return
	end

	local current_session_index = find_session_index(current_instance, current_session)

	if current_session_index == nil then
		vim.notify("Could not find index of current session", vim.log.levels.ERROR)
		return
	end

	if current_session_index == 1 then
		current_session_index = #current_instance.sessions
	else
		current_session_index = (current_session_index - 1) % #current_instance.sessions
	end

	switch_session(current_instance.sessions[current_session_index])
end

---@param name string
function M.switch_instance(name)
	local target_instance = find_instance(name)

	if target_instance == nil then
		vim.notify("Could not find an instance with that name", vim.log.levels.ERROR)
		return
	end

	switch_instance(target_instance)
end

function M.alternate_instance()
	if last_instance == nil then
		vim.notify("No alternate instance", vim.log.levels.ERROR)
		return
	end

	switch_instance(last_instance)
end

function M.persist_instances()
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
	local instance = find_instance(instance_data.current_instance)

	if instance == nil then
		vim.notify(
			string.format(
				"There was an error loading the current instance '%s' it was not found in instances.json",
				instance_data.current_instance
			),
			vim.log.levels.ERROR
		)
		return
	end

	current_instance = instance

	local session = find_session(current_instance, current_instance.current_session)

	if session == nil then
		vim.notify(
			string.format(
				"There was an error loading the current instance '%s' its current session '%s' was not found in instances.json",
				instance_data.current_instance,
				current_instance.current_session
			),
			vim.log.levels.error
		)
		return
	end

	current_session = session

	last_session = find_session(current_instance, current_instance.last_session)

	if should_persist then
		M.persist_instances()
	end

	source_nvim_session_file(current_instance, current_session)

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
					---@cast entry Instance
					local display = entry.name

					if entry == current_instance then
						display = icons.cur .. " " .. display
					elseif entry == last_instance then
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
					switch_instance(selection.value)
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
					instance = instance,
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

					switch_instance(selection.value.instance)
					switch_session(selection.value.session)
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
		"<leader>sa",
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

require("legendary").autocmds({
	{
		"VimLeavePre",
		function()
			write_nvim_session_file(current_instance, current_session)
			set_session_metadata(current_session)
			M.persist_instances()
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
				local on_cancel = function()
					vim.notify("Creation cancelled")
				end

				if input then
					input_new_session(function(session_name, dir)
						M.create_instance(input, session_name, dir)
					end, on_cancel)
				else
					on_cancel()
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
