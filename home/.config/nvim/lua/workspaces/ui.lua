local M = {}
local utils = require("workspaces.utils")
local state = require("workspaces.state")
local marks = require("workspaces.marks")
local ws = require("workspaces.workspaces")
local Path = require("plenary.path")

local function directory_completion()
	return {
		{
			mode = { "i" },
			key = "<Tab>",
			handler = function()
				local action = vim.api.nvim_replace_termcodes("<C-x><C-f>", true, false, true)
				vim.api.nvim_feedkeys(action, "i", false)
			end,
		},
		{
			mode = { "i" },
			key = "<S-Tab>",
			handler = function()
				local action = vim.api.nvim_replace_termcodes("<C-x><C-p>", true, false, true)
				vim.api.nvim_feedkeys(action, "i", false)
			end,
		},
	}
end

local function truncate_path(path)
	local parts = {}

	for part in string.gmatch(path, "([^\\/]+)") do
		table.insert(parts, part)
	end

	local len = #parts
	local file = parts[len]
	local parents = ""

	for i = 1, math.min(len - 1, 2) do
		parents = parts[len - i] .. "/" .. parents
	end

	return { file = file, parents = parents:sub(1, -2) }
end

function M.create_session_input()
	local nui = require("nui-components")

	local renderer = nui.create_renderer({
		width = 60,
		height = 1,
	})

	local session_name = nui.create_signal({ value = "" })
	local session_dir = nui.create_signal({ value = "~/" })

	local body = nui.form(
		{
			id = "form",
			submit_key = "<CR>",
			on_submit = function(is_valid)
				if is_valid then
					local sessions_dir = Path:new(session_dir.value:get_value())

					if not sessions_dir:is_dir() then
						vim.notify("Not a valid directory")
						return
					end

					ws.create_session(session_name.value:get_value(), session_dir.value:get_value())
					renderer:close()
				else
					vim.notify("Please fill in all fields")
				end
			end,
		},
		nui.paragraph({
			lines = "Create session",
			align = "center",
		}),
		nui.text_input({
			border_label = "Session name",
			id = "session_name",
			autofocus = true,
			flex = 1,
			max_lines = 1,
			value = session_name.value,
			validate = nui.validator.min_length(1),
			on_change = function(value, _)
				session_name.value = value
			end,
		}),
		nui.text_input({
			border_label = "Session directory",
			id = "session_directory",
			autofocus = false,
			flex = 1,
			max_lines = 1,
			value = session_dir.value,
			validate = nui.validator.min_length(1),
			mappings = directory_completion,
			on_change = function(value, _)
				session_dir.value = value
			end,
		})
	)

	renderer:render(body)
end

function M.rename_current_session_input()
	local nui = require("nui-components")

	local renderer = nui.create_renderer({
		width = 60,
		height = 1,
	})

	local session_name = nui.create_signal({ value = state.get().current_workspace.current_session_name })

	local body = nui.form(
		{
			id = "form",
			submit_key = "<CR>",
			on_submit = function(is_valid)
				if is_valid then
					ws.rename_current_session(session_name.value:get_value())
					renderer:close()
				else
					vim.notify("Please fill in all fields")
				end
			end,
		},
		nui.paragraph({
			lines = "Rename current session",
			align = "center",
		}),
		nui.text_input({
			border_label = "New session name",
			id = "session_name",
			autofocus = true,
			flex = 1,
			max_lines = 1,
			value = session_name.value,
			validate = nui.validator.min_length(1),
			on_change = function(value, _)
				session_name.value = value
			end,
		})
	)

	renderer:render(body)
end

function M.delete_session_input()
	local nui = require("nui-components")

	local renderer = nui.create_renderer({
		width = 60,
		height = 1,
	})

	local session_name = nui.create_signal({ value = state.get().current_workspace.current_session_name })

	local body = nui.form(
		{
			id = "form",
			submit_key = "<CR>",
			on_submit = function(is_valid)
				if is_valid then
					ws.delete_session(session_name.value:get_value())
					renderer:close()
				else
					vim.notify("Please fill in all fields")
				end
			end,
		},
		nui.paragraph({
			lines = "Delete session",
			align = "center",
		}),
		nui.text_input({
			border_label = "Session name",
			id = "session_name",
			autofocus = true,
			flex = 1,
			max_lines = 1,
			value = session_name.value,
			validate = nui.validator.min_length(1),
			on_change = function(value, _)
				session_name.value = value
			end,
		})
	)

	renderer:render(body)
end

function M.create_workspace_input()
	local nui = require("nui-components")

	local renderer = nui.create_renderer({
		width = 60,
		height = 1,
	})

	local workspace_name = nui.create_signal({ value = "" })
	local session_name = nui.create_signal({ value = "" })
	local session_dir = nui.create_signal({ value = "~/" })

	local body = nui.form(
		{
			id = "form",
			submit_key = "<CR>",
			on_submit = function(is_valid)
				if is_valid then
					local sessions_dir = Path:new(session_dir.value:get_value())

					if not sessions_dir:is_dir() then
						vim.notify("Not a valid directory")
						return
					end

					ws.create_workspace(
						workspace_name.value:get_value(),
						session_name.value:get_value(),
						session_dir.value:get_value()
					)
					renderer:close()
				else
					vim.notify("Please fill in all fields")
				end
			end,
		},
		nui.paragraph({
			lines = "Create workspace",
			align = "center",
		}),
		nui.text_input({
			border_label = "Workspace name",
			id = "workspace_name",
			autofocus = true,
			flex = 1,
			max_lines = 1,
			value = workspace_name.value,
			validate = nui.validator.min_length(1),
			on_change = function(value, _)
				workspace_name.value = value
			end,
		}),
		nui.text_input({
			border_label = "Session name",
			id = "session_name",
			autofocus = false,
			flex = 1,
			max_lines = 1,
			value = session_name.value,
			validate = nui.validator.min_length(1),
			on_change = function(value, _)
				session_name.value = value
			end,
		}),
		nui.text_input({
			border_label = "Session directory",
			id = "session_directory",
			autofocus = false,
			flex = 1,
			max_lines = 1,
			value = session_dir.value,
			validate = nui.validator.min_length(1),
			mappings = directory_completion,
			on_change = function(value, _)
				session_dir.value = value
			end,
		})
	)

	renderer:render(body)
end

function M.rename_current_workspace_input()
	local nui = require("nui-components")

	local renderer = nui.create_renderer({
		width = 60,
		height = 1,
	})

	local workspace_name = nui.create_signal({ value = state.get().current_workspace.name })

	local body = nui.form(
		{
			id = "form",
			submit_key = "<CR>",
			on_submit = function(is_valid)
				if is_valid then
					ws.rename_current_workspace(workspace_name.value:get_value())
					renderer:close()
				else
					vim.notify("Please fill in all fields")
				end
			end,
		},
		nui.paragraph({
			lines = "Rename current workspace",
			align = "center",
		}),
		nui.text_input({
			border_label = "New workspace name",
			id = "workspace_name",
			autofocus = true,
			flex = 1,
			max_lines = 1,
			value = workspace_name.value,
			validate = nui.validator.min_length(1),
			on_change = function(value, _)
				workspace_name.value = value
			end,
		})
	)

	renderer:render(body)
end

function M.delete_workspace_input()
	local nui = require("nui-components")

	local renderer = nui.create_renderer({
		width = 60,
		height = 1,
	})

	local workspace_name = nui.create_signal({ value = state.get().current_workspace.name })

	local body = nui.form(
		{
			id = "form",
			submit_key = "<CR>",
			on_submit = function(is_valid)
				if is_valid then
					ws.delete_workspace(workspace_name.value:get_value())
					renderer:close()
				else
					vim.notify("Please fill in all fields")
				end
			end,
		},
		nui.paragraph({
			lines = "Delete workspace",
			align = "center",
		}),
		nui.text_input({
			border_label = "Workspace name",
			id = "workspace_name",
			autofocus = true,
			flex = 1,
			max_lines = 1,
			value = workspace_name.value,
			validate = nui.validator.min_length(1),
			on_change = function(value, _)
				workspace_name.value = value
			end,
		})
	)

	renderer:render(body)
end

local mark_picker = function(opts)
	opts = opts or {}
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")
	local entry_display = require("telescope.pickers.entry_display")
	local previewer = conf.grep_previewer(opts)

	pickers
		.new(opts, {
			prompt_title = "Marks",
			finder = finders.new_table({
				results = state.get().marks,
				entry_maker = function(entry)
					local pos_text = tostring(entry.pos[1]) .. "," .. tostring(entry.pos[2])
					local truncated_elements = truncate_path(entry.path)
					local file_with_pos = truncated_elements.file --.. ":" .. pos_text

					---@cast entry Mark
					local displayer = entry_display.create({
						separator = " ",
						items = {
							{ width = #(entry.workspace_name .. "-" .. entry.session_name) },
							{
								width = function()
									if entry.display_name then
										return #entry.display_name
									end
									return 0
								end,
							},
							{ width = #file_with_pos },
							{ remaining = true },
						},
					})

					local make_display = function(et)
						return displayer({
							{ entry.workspace_name .. "-" .. entry.session_name, "TelescopeResultsSpecialComment" },
							{ entry.display_name, "Type" },
							file_with_pos,
							{ truncated_elements.parents, "TelescopeResultsComment" },
						})
					end

					return {
						value = entry,
						display = make_display,
						ordinal = entry.workspace_name
							.. "-"
							.. entry.session_name
							.. " "
							.. (entry.display_name or "")
							.. " "
							.. file_with_pos
							.. truncated_elements.parents,
						path = entry.path,
						lnum = entry.pos[1],
					}
				end,
			}),
			previewer = previewer,
			sorter = conf.generic_sorter(opts),
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					marks.goto_mark(selection.value.name)
				end)
				map("n", "<Del>", function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					marks.delete_mark(selection.value.name)
					M.pick_mark()
				end)

				map("n", "r", function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					marks.rename_mark(selection.value.name)
				end)

				return true
			end,
		})
		:find()
end

local workspace_picker = function(opts)
	opts = opts or {}
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")

	pickers
		.new(opts, {
			prompt_title = "Workspaces",
			finder = finders.new_table({
				results = state.get().workspaces,
				entry_maker = function(entry)
					---@cast entry Workspace
					local display = entry.name

					if entry == state.get().current_workspace then
						display = utils.icons.cur .. " " .. display
					elseif entry == state.get().last_workspace then
						display = utils.icons.last .. " " .. display
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
					ws.switch_session(nil, selection.value)
				end)
				return true
			end,
		})
		:find()
end

local session_picker = function(opts)
	opts = opts or {}
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")

	local results = {}

	local previewer = conf.grep_previewer(opts)

	for _, workspace in ipairs(state.get().workspaces) do
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
	if state.get().current_session ~= nil then
		ws.set_session_metadata(state.get().current_session, {})
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

					ws.switch_session(selection.value.session, selection.value.workspace)
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

function M.pick_mark()
	mark_picker()
end

return M
