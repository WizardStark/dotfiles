local M = {}

local separator = string.char(31)

local function resolve_script_path()
	local candidates = {
		vim.fs.joinpath(vim.fn.stdpath("config"), "..", "tmux", "pi_sessions_status.sh"),
		vim.fn.expand("~/.config/tmux/pi_sessions_status.sh"),
	}

	for _, path in ipairs(candidates) do
		if vim.fn.filereadable(path) == 1 then
			return vim.fn.fnamemodify(path, ":p")
		end
	end

	return nil, candidates[1]
end

local function parse_records(output)
	local items = {}
	for _, line in ipairs(vim.split(vim.trim(output or ""), "\n", { plain = true, trimempty = true })) do
		local parts = vim.split(line, separator, { plain = true })
		if #parts >= 7 then
			items[#items + 1] = {
				session_name = parts[1],
				window_index = parts[2],
				pane_id = parts[3],
				pane_index = parts[4],
				status = parts[5],
				name = parts[6],
				path = parts[7],
			}
		end
	end
	return items
end

local function load_items()
	local script_path, missing_path = resolve_script_path()
	if not script_path then
		vim.notify("Missing script: " .. missing_path, vim.log.levels.ERROR)
		return nil
	end

	local result = vim.system({ "bash", script_path, "--records" }, { text = true }):wait()
	if result.code ~= 0 then
		local message = vim.trim(result.stderr or "")
		if message == "" then
			message = "Failed to load Pi sessions"
		end
		vim.notify(message, vim.log.levels.ERROR)
		return nil
	end

	return parse_records(result.stdout), script_path
end

local function switch_to_item(script_path, item)
	local result = vim.system({ "bash", script_path, "--switch-pane", item.pane_id }, { text = true }):wait()
	if result.code == 0 then
		return
	end

	local message = vim.trim(result.stderr or "")
	if message == "" then
		message = "Failed to switch tmux client"
	end
	vim.notify(message, vim.log.levels.ERROR)
end

local function status_icon(status)
	if status == "working" then
		return "●"
	end
	return "○"
end

function M.show()
	local items, script_path = load_items()
	if not items then
		return
	end

	if vim.tbl_isempty(items) then
		vim.notify("No active pi sessions", vim.log.levels.INFO)
		return
	end

	Snacks.picker.pick({
		source = "pi_sessions",
		finder = function()
			local picker_items = {}
			for _, item in ipairs(items) do
				picker_items[#picker_items + 1] = {
					data = item,
					text = table.concat(
						{ status_icon(item.status), item.name, item.session_name .. ":" .. item.window_index .. "." .. item.pane_index, item.path },
						" "
					),
				}
			end
			return picker_items
		end,
		confirm = function(picker, item)
			picker:close()
			if item then
				switch_to_item(script_path, item.data)
			end
		end,
		format = function(item, _)
			local status_hl = item.data.status == "working" and "SnacksPickerSpecial" or "SnacksPickerComment"
			return {
				{ status_icon(item.data.status) .. "  ", status_hl },
				{ item.data.name, "Type" },
				{ "  " .. item.data.session_name .. ":" .. item.data.window_index .. "." .. item.data.pane_index, "SnacksPickerSpecial" },
				{ "  " .. item.data.path, "SnacksPickerComment" },
			}
		end,
		layout = {
			preview = false,
			layout = {
				backdrop = {
					blend = 40,
				},
				width = 0.5,
				min_width = 80,
				height = 0.3,
				min_height = 10,
				box = "vertical",
				border = "rounded",
				title = " Pi sessions ",
				title_pos = "center",
				{ win = "list", border = "none" },
				{ win = "input", height = 1, border = "top" },
			},
		},
	})
end

return M
