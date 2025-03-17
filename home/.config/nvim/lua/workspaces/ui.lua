local M = {}
local utils = require("workspaces.utils")
local state = require("workspaces.state")
local marks = require("workspaces.marks")
local ws = require("workspaces.workspaces")
local Path = require("plenary.path")
local Snacks = require("snacks")

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
		width = 80,
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
					if not Path:new(vim.fn.expand(session_dir.value:get_value())):is_dir() then
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
		width = 80,
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

function M.change_current_session_directory_input()
	local nui = require("nui-components")

	local renderer = nui.create_renderer({
		width = 80,
		height = 1,
	})

	local session_dir = nui.create_signal({ value = state.get().current_session.dir })

	local body = nui.form(
		{
			id = "form",
			submit_key = "<CR>",
			on_submit = function(is_valid)
				if is_valid then
					if not Path:new(vim.fn.expand(session_dir.value:get_value())):is_dir() then
						vim.notify("Not a valid directory")
						return
					end

					state.get().current_session.dir = session_dir.value:get_value()
					renderer:close()
				else
					vim.notify("Please fill in all fields")
				end
			end,
		},
		nui.paragraph({
			lines = "Change current session directory",
			align = "center",
		}),
		nui.text_input({
			border_label = "New session directory",
			id = "session_directory",
			autofocus = true,
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

function M.delete_session_input()
	local nui = require("nui-components")

	local renderer = nui.create_renderer({
		width = 80,
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
		width = 80,
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
					if not Path:new(vim.fn.expand(session_dir.value:get_value())):is_dir() then
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
		width = 80,
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
		width = 80,
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

local mark_picker = function()
	Snacks.picker.pick(
		---@type snacks.picker.Config
		{
			source = "mark",
			finder = function()
				local items = {} ---@type snacks.picker.finder.Item
				for _, mark in ipairs(state.get().marks) do
					local pos_text = tostring(mark.pos[1]) .. "," .. tostring(mark.pos[2])
					local truncated_elements = truncate_path(mark.path)
					local display_name = mark.display_name and mark.display_name .. " " or "..." .. " "
					local text = mark.workspace_name
						.. "-"
						.. mark.session_name
						.. " "
						.. display_name
						.. truncated_elements.file
						.. " "
						.. truncated_elements.parents
					table.insert(items, {
						["data"] = {
							mark = mark,
							pos_text = pos_text,
							truncated_elements = truncated_elements,
						},
						text = text,
						file = mark.path,
						pos = mark.pos,
					})
				end

				return items
			end,
			confirm = function(picker, item)
				picker:close()
				if item then
					marks.goto_mark(item.data.mark.name)
				end
			end,
			format = function(item, _)
				local ret = {}
				ret[#ret + 1] = {
					item.data.mark.workspace_name .. "-" .. item.data.mark.session_name .. " ",
					"SnacksPickerSpecial",
				}
				ret[#ret + 1] =
					{ item.data.mark.display_name and item.data.mark.display_name .. " " or "..." .. " ", "Type" }
				ret[#ret + 1] = { item.data.truncated_elements.file .. " " }
				ret[#ret + 1] = { item.data.truncated_elements.parents, "SnacksPickerComment" }

				return ret
			end,
			preview = function(ctx)
				if ctx.item.file then
					Snacks.picker.preview.file(ctx)
				else
					ctx.preview:reset()
					ctx.preview:set_title("No preview")
				end
			end,
			layout = {
				layout = {
					backdrop = {
						blend = 40,
					},
				},
			},
			actions = {
				delete = function(picker, item)
					marks.delete_mark(item.data.mark.name)
					picker:find()
				end,
				rename = function(picker, item)
					picker:close()
					marks.rename_mark(item.data.mark.name)
				end,
			},
			win = {
				input = {
					keys = {
						["<Del>"] = { "delete", mode = { "n" } },
						["r"] = { "rename", mode = { "n" } },
					},
				},
			},
		}
	)
end

local workspace_picker = function()
	Snacks.picker.pick(
		---@type snacks.picker.Config
		{
			source = "workspace",
			finder = function()
				local items = {} ---@type snacks.picker.finder.Item

				for _, workspace in ipairs(state.get().workspaces) do
					local text = workspace.name
					if workspace == state.get().current_workspace then
						text = utils.icons.cur .. " " .. text
					elseif workspace == state.get().last_workspace then
						text = utils.icons.last .. " " .. text
					end
					table.insert(items, {
						["data"] = { workspace = workspace },
						text = text,
					})
				end

				return items
			end,
			confirm = function(picker, item)
				picker:close()
				if item then
					ws.switch_session(nil, item.data.workspace)
				end
			end,
			format = function(item, _)
				local ret = {}
				ret[#ret + 1] = { item.text }
				return ret
			end,
			layout = {
				preview = false,
				layout = {
					backdrop = {
						blend = 40,
					},
					width = 0.3,
					min_width = 80,
					height = 0.2,
					min_height = 10,
					box = "vertical",
					border = "rounded",
					title = " Workspace ",
					title_pos = "center",
					{ win = "list", border = "none" },
					{ win = "input", height = 1, border = "top" },
				},
			},
		}
	)
end

local session_picker = function()
	Snacks.picker.pick(
		---@type snacks.picker.Config
		{
			source = "session",
			finder = function()
				local items = {} ---@type snacks.picker.finder.Item

				-- Update current session metadata so it displays correctly
				if state.get().current_session ~= nil then
					ws.set_session_metadata(state.get().current_session, {})
				end

				for _, workspace in ipairs(state.get().workspaces) do
					for _, session in ipairs(workspace.sessions) do
						table.insert(items, {
							["data"] = { workspace = workspace, session = session },
							text = workspace.name .. ": " .. session.name,
							file = session.last_file and session.last_file or nil,
							pos = { session.last_file_line, 1 },
						})
					end
				end

				if state.get().current_session ~= nil then
					ws.set_session_metadata(state.get().current_session, {})
				end

				return items
			end,
			confirm = function(picker, item)
				picker:close()
				if item then
					ws.switch_session(item.data.session, item.data.workspace)
				end
			end,
			format = function(item, _)
				local ret = {}
				ret[#ret + 1] = { item.data.workspace.name .. ": ", "SnacksPickerSpecial" }
				ret[#ret + 1] = { item.data.session.name, "Type" }
				return ret
			end,
			preview = function(ctx)
				if ctx.item.file then
					Snacks.picker.preview.file(ctx)
				else
					ctx.preview:reset()
					ctx.preview:set_title("No last file")
				end
			end,
			layout = {
				layout = {
					backdrop = {
						blend = 40,
					},
				},
			},
		}
	)
end

function M.pick_workspace()
	workspace_picker()
end

function M.pick_session()
	session_picker()
end

function M.pick_mark()
	mark_picker()
end

return M
