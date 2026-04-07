local M = {}
local utils = require("workspaces.utils")
local state = require("workspaces.state")
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

					local utils = require("workspaces.utils")
					local normalized_dir = utils.normalize_dir(session_dir.value:get_value())
					state.get().current_session.dir = normalized_dir
					local main_target = utils.get_main_target(state.get().current_session)
					main_target.dir = normalized_dir
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
					ws.set_session_metadata(state.get().current_session, ws.get_current_target(), {})
				end

				for _, workspace in ipairs(state.get().workspaces) do
					for _, session in ipairs(workspace.sessions) do
						local target = require("workspaces.utils").get_current_target(session)
						table.insert(items, {
							data = { workspace = workspace, session = session, target = target },
							text = workspace.name .. ": " .. session.name,
							file = target.last_file,
							pos = target.last_file_line and { target.last_file_line, 1 } or nil,
						})
					end
				end

				if state.get().current_session ~= nil then
					ws.set_session_metadata(state.get().current_session, ws.get_current_target(), {})
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
				local target = item.data.target
				if target.name ~= "main" then
					ret[#ret + 1] = { " [" .. target.name .. "]", "SnacksPickerComment" }
				end
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

local target_picker = function()
	ws.refresh_current_session_targets(false)
	local session = state.get().current_session
	local current_target = ws.get_current_target()
	if session == nil then
		vim.notify("No current session", vim.log.levels.ERROR)
		return
	end

	Snacks.picker.pick(
		---@type snacks.picker.Config
		{
			source = "target",
			finder = function()
				local items = {} ---@type snacks.picker.finder.Item
				for _, target in ipairs(session.targets or {}) do
					local text = target.name
					if target == current_target then
						text = utils.icons.cur .. " " .. text
					elseif session.last_target_name ~= nil and target.name == session.last_target_name then
						text = utils.icons.last .. " " .. text
					end

					items[#items + 1] = {
						data = { target = target },
						text = text,
						file = target.dir,
					}
				end

				return items
			end,
			confirm = function(picker, item)
				picker:close()
				if item then
					ws.switch_target(item.data.target)
				end
			end,
			format = function(item, _)
				local ret = {}
				ret[#ret + 1] = { item.text }
				return ret
			end,
			preview = function(ctx)
				ctx.preview:set_title(ctx.item.file)
			end,
			layout = {
				preview = false,
				layout = {
					backdrop = {
						blend = 40,
					},
					width = 0.3,
					min_width = 60,
					height = 0.2,
					min_height = 8,
					box = "vertical",
					border = "rounded",
					title = " Target ",
					title_pos = "center",
					{ win = "list", border = "none" },
					{ win = "input", height = 1, border = "top" },
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

function M.pick_target()
	target_picker()
end

return M
