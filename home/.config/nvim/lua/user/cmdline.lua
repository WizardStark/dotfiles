local M = {}

local ns = vim.api.nvim_create_namespace("user.cmdline")

local state = {
	cmd = {
		buf = nil,
		win = nil,
		level = 0,
		text = "",
		cursor = 0,
		firstc = "",
		prompt = "",
		indent = 0,
		special = nil,
	},
	msg = {
		buf = nil,
		win = nil,
		lines = {},
		history = {},
		timer = nil,
	},
}

local function ensure_buf(kind)
	local buf = state[kind].buf
	if buf and vim.api.nvim_buf_is_valid(buf) then
		return buf
	end

	buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = kind == "cmd" and "cmdline" or "user_cmdline_pum"
	state[kind].buf = buf
	return buf
end

local function close_win(kind)
	local win = state[kind].win
	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_close(win, true)
	end
	state[kind].win = nil
	if kind == "cmd" then
		state[kind].level = 0
		state[kind].special = nil
	end
end

local function chunks_to_text(content)
	local text = ""
	for _, chunk in ipairs(content or {}) do
		text = text .. chunk[2]
	end
	return text
end

local function cmdline_text()
	local cmd = state.cmd
	local special = cmd.special or ""
	return cmd.firstc .. cmd.prompt .. string.rep(" ", cmd.indent) .. cmd.text .. special
end

local function cmdline_width()
	local columns = vim.o.columns
	local min_width = math.max(math.floor(columns * 0.2), 20)
	local max_width = math.max(math.floor(columns * 0.5), 40)
	local width = vim.fn.strdisplaywidth(cmdline_text()) + 2
	return math.min(math.max(width, min_width), max_width)
end

local function cmdline_row()
	return math.max(math.floor(vim.o.lines * 0.35), 1)
end

local function cmdline_col(width)
	return math.max(math.floor((vim.o.columns - width) / 2), 0)
end

local function ensure_cmdline_win()
	local buf = ensure_buf("cmd")
	local width = cmdline_width()
	local height = 1
	local text = cmdline_text()
	for line in (text .. "\n"):gmatch("(.-)\n") do
		height = math.max(height, 1)
		if line ~= text then
			height = height + 1
		end
	end
	local config = {
		relative = "editor",
		anchor = "NW",
		row = cmdline_row(),
		col = cmdline_col(width),
		width = width,
		height = height,
		border = "rounded",
		style = "minimal",
		focusable = false,
		zindex = 200,
	}

	if state.cmd.win and vim.api.nvim_win_is_valid(state.cmd.win) then
		vim.api.nvim_win_set_config(state.cmd.win, config)
	else
		state.cmd.win = vim.api.nvim_open_win(buf, false, config)
		vim.wo[state.cmd.win].winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder"
		vim.wo[state.cmd.win].wrap = false
	end

	if vim.api.nvim_win_get_buf(state.cmd.win) ~= buf then
		vim.api.nvim_win_set_buf(state.cmd.win, buf)
	end

	return state.cmd.win, buf
end

local function render_cmdline()
	if state.cmd.level == 0 then
		close_win("cmd")
		vim.g.ui_cmdline_pos = nil
		return
	end

	local win, buf = ensure_cmdline_win()
	local text = cmdline_text()
	local lines = {}
	for line in (text .. "\n"):gmatch("(.-)\n") do
		table.insert(lines, line)
	end
	if #lines == 0 then
		lines = { " " }
	else
		lines[#lines] = lines[#lines] .. " "
	end
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

	local cursor = vim.fn.strdisplaywidth(
		state.cmd.firstc
			.. state.cmd.prompt
			.. string.rep(" ", state.cmd.indent)
			.. state.cmd.text:sub(1, state.cmd.cursor)
	)
	local cfg = vim.api.nvim_win_get_config(win)
	local row = type(cfg.row) == "number" and cfg.row or 0
	local col = type(cfg.col) == "number" and cfg.col or 0
	local text_col = col
		+ 2
		+ vim.fn.strdisplaywidth(state.cmd.firstc .. state.cmd.prompt .. string.rep(" ", state.cmd.indent))
	vim.g.ui_cmdline_pos = { row + 2, text_col }
	vim.api.nvim_buf_add_highlight(buf, ns, "Cursor", #lines - 1, cursor, cursor + 1)
	pcall(vim.api.nvim_win_set_cursor, win, { #lines, cursor })
end

local function ensure_msg_win()
	local buf = ensure_buf("msg")
	local width = 20
	for _, line in ipairs(state.msg.lines) do
		width = math.max(width, vim.fn.strdisplaywidth(line) + 2)
	end
	width = math.min(width, math.max(math.floor(vim.o.columns * 0.45), 40))
	local max_height = math.max(math.floor(vim.o.lines * 0.2), 3)
	local height = math.min(math.max(#state.msg.lines, 1), max_height)
	local config = {
		relative = "editor",
		anchor = "NE",
		row = 1,
		col = vim.o.columns - 2,
		width = width,
		height = height,
		border = "rounded",
		style = "minimal",
		focusable = false,
		zindex = 180,
	}

	if state.msg.win and vim.api.nvim_win_is_valid(state.msg.win) then
		vim.api.nvim_win_set_config(state.msg.win, config)
	else
		state.msg.win = vim.api.nvim_open_win(buf, false, config)
		vim.wo[state.msg.win].winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder"
		vim.wo[state.msg.win].wrap = true
	end

	return state.msg.win, buf
end

local function show_message_history()
	if #state.msg.history == 0 then
		vim.notify("No message history", vim.log.levels.INFO, { title = "Messages" })
		return
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = "messages"
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, state.msg.history)
	vim.bo[buf].modifiable = false

	local width = math.min(math.max(math.floor(vim.o.columns * 0.7), 80), vim.o.columns - 4)
	local height = math.min(math.max(math.floor(vim.o.lines * 0.6), 12), vim.o.lines - 4)
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		anchor = "NW",
		row = 2,
		col = math.max(math.floor((vim.o.columns - width) / 2), 0),
		width = width,
		height = height,
		border = "rounded",
		style = "minimal",
		title = " Messages ",
		title_pos = "center",
	})
	vim.wo[win].wrap = false
end

local clear_messages

local function render_messages()
	if #state.msg.lines == 0 then
		close_win("msg")
		return
	end

	local _, buf = ensure_msg_win()
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, state.msg.lines)

	if state.msg.timer then
		state.msg.timer:stop()
	end
	state.msg.timer = vim.uv.new_timer()
	state.msg.timer:start(
		2000,
		0,
		vim.schedule_wrap(function()
			clear_messages()
		end)
	)
end

clear_messages = function()
	if state.msg.timer then
		state.msg.timer:stop()
		state.msg.timer:close()
		state.msg.timer = nil
	end
	state.msg.lines = {}
	vim.schedule(render_messages)
end

local function on_cmdline_show(content, pos, firstc, prompt, indent, level)
	local text = chunks_to_text(content)

	state.cmd.level = level
	state.cmd.text = text
	state.cmd.cursor = pos
	state.cmd.firstc = firstc or ""
	state.cmd.prompt = prompt or ""
	state.cmd.indent = indent or 0
	state.cmd.special = nil
	render_cmdline()
	vim.cmd("redraw")
end

local function on_cmdline_pos(pos, level)
	if level ~= state.cmd.level then
		return
	end
	state.cmd.cursor = pos
	render_cmdline()
end

local function on_cmdline_special_char(char, _, level)
	if level ~= state.cmd.level then
		return
	end
	state.cmd.special = char
	render_cmdline()
end

local function on_cmdline_hide(level)
	if level == state.cmd.level then
		state.cmd.level = 0
		state.cmd.special = nil
		vim.schedule(function()
			close_win("cmd")
			vim.g.ui_cmdline_pos = nil
		end)
	end
end

local function on_msg_show(kind, content, replace_last, _, append)
	local text = chunks_to_text(content)
	if kind == "progress" or kind == "search_cmd" or kind == "search_count" or kind == "completion" then
		return
	end
	if kind == "empty" and text == "" then
		clear_messages()
		return
	end
	vim.schedule(function()
		local lines = vim.split(text, "\n", { plain = true })
		if replace_last and #state.msg.lines > 0 then
			for _ = 1, math.min(#state.msg.lines, #lines) do
				table.remove(state.msg.lines)
			end
		end

		if append and #state.msg.lines > 0 then
			state.msg.lines[#state.msg.lines] = state.msg.lines[#state.msg.lines] .. table.remove(lines, 1)
		end

		for _, line in ipairs(lines) do
			table.insert(state.msg.lines, line)
			table.insert(state.msg.history, line)
		end

		while #state.msg.lines > math.max(math.floor(vim.o.lines * 0.2), 3) do
			table.remove(state.msg.lines, 1)
		end

		render_messages()
	end)
end

local function on_msg_showcmd(_) end

local function on_msg_ruler(_) end

function M.setup()
	vim.ui_attach(ns, { ext_messages = true, ext_popupmenu = true, set_cmdheight = false }, function(event, ...)
		if event == "cmdline_show" then
			on_cmdline_show(...)
			return true
		elseif event == "cmdline_pos" then
			on_cmdline_pos(...)
			return true
		elseif event == "cmdline_special_char" then
			on_cmdline_special_char(...)
			return true
		elseif event == "cmdline_hide" then
			on_cmdline_hide(...)
			return true
		elseif event == "popupmenu_show" then
			return true
		elseif event == "popupmenu_select" then
			return true
		elseif event == "popupmenu_hide" then
			return true
		elseif event == "msg_show" then
			on_msg_show(...)
			return true
		elseif event == "msg_clear" then
			clear_messages()
			return true
		elseif event == "msg_showcmd" then
			on_msg_showcmd(...)
			return true
		elseif event == "msg_ruler" then
			on_msg_ruler(...)
			return true
		end
	end)

	vim.api.nvim_create_autocmd("VimResized", {
		callback = function()
			vim.schedule(function()
				render_cmdline()
				vim.cmd("redraw")
			end)
		end,
	})
end

function M.show_messages()
	show_message_history()
end

function M.clear_messages()
	clear_messages()
end

return M
