local M = {}

---@enum Prefix
M.PREFIXES = {
	auto = "AutoCmds",
	code = "Code utils",
	debug = "Debugging",
	diag = "Diagnostics",
	find = "Find",
	fold = "Folds",
	git = "Git",
	latex = "Latex",
	lsp = "Language server",
	misc = "Misc",
	move = "Movement",
	nav = "Navigation",
	notes = "Notes",
	task = "Tasks",
	term = "Terminal",
	test = "Test",
	text = "Text object",
	nogroup = "Ungrouped",
	window = "Window",
	work = "Workspaces",
}

M.special_windows = {
	["OverseerList"] = function()
		vim.cmd(":CompilerToggleResults")
	end,
	["Trouble"] = function()
		require("trouble").toggle()
	end,
	["dapui"] = function()
		require("dapui").toggle()
	end,
	["DiffviewFiles"] = function()
		vim.cmd(":DiffviewClose")
	end,
}

local special_characters = {
	"^",
	".",
	"*",
	"\\",
	"!",
	"-",
	"+",
	"=",
	"%",
	"<",
	">",
	"$",
	"/",
	"#",
	"|",
	"&",
	",",
	"[",
	"]",
	"'",
	":",
	"(",
	")",
	"?",
	"`",
	'"',
	"{",
	"}",
	"@",
}

function M.is_big_file(buf)
	local max_filesize = 500 * 1024 -- 500 KB
	local filename = vim.api.nvim_buf_get_name(buf)
	local ok, stats = pcall(vim.loop.fs_stat, filename)
	if ok and stats then
		return (stats.size > max_filesize) or (vim.fn.line("$") < 2 and stats.size > max_filesize / 10)
	end

	return false
end

function M.toggle_minifiles()
	local MiniFiles = require("mini.files")
	local function open_and_center(path)
		MiniFiles.open(path)
		MiniFiles.go_out()
		MiniFiles.go_in({ close_on_file = false })
	end
	if not MiniFiles.close() then
		if not pcall(open_and_center, vim.fn.expand("%:p")) then
			open_and_center()
		end
	end
end

local function get_longest_prefix_length()
	local maxlen = 0
	for _, prefix in pairs(M.PREFIXES) do
		maxlen = math.max(#prefix, maxlen)
	end
	return maxlen
end

local maxlen = get_longest_prefix_length()

function M.get_visual_selection_lines()
	return { vim.fn.getpos("'<")[2], vim.fn.getpos("'>")[2] }
end

function M.region_to_text(region)
	local text = ""
	local maxcol = vim.v.maxcol
	for line, cols in vim.spairs(region) do
		local endcol = cols[2] == maxcol and -1 or cols[2]
		local chunk = vim.api.nvim_buf_get_text(0, line, cols[1], line, endcol, {})[1]
		text = ("%s%s\n"):format(text, chunk)
	end
	return text
end

---@param element any
---@param table any
---@return boolean
function M.contains(element, table)
	for _, value in pairs(table) do
		if value == element then
			return true
		end
	end
	return false
end

---@param text string
---@return string
function M.escape_special_chars(text)
	local res = ""
	for char in text:gmatch(".") do
		if M.contains(char, special_characters) then
			res = res .. "\\" .. char
		else
			res = res .. char
		end
	end

	return res
end

---Applies prefix to given description
---@param prefix Prefix | nil
---@param description string | nil
function M.prefix_description(prefix, description)
	if description == nil then
		description = "No description"
	end
	if prefix == nil then
		return M.PREFIXES.nogroup .. string.rep(" ", maxlen - #M.PREFIXES.nogroup) .. " │ " .. description
	end
	return prefix .. string.rep(" ", maxlen - #prefix) .. " │ " .. description
end

---Wraps a mapping function with a function that calls prefix_description
---@param func fun(map: table)
---@return fun(map: table)
function M.prefixifier(func)
	return function(map)
		for _, entry in pairs(map) do
			entry.description = M.prefix_description(entry.prefix, entry.description)
		end
		func(map)
	end
end

--- Force closes all non terminal buffers
---@param close_current boolean | nil -- Defaults to true if nil
function M.close_non_terminal_buffers(close_current)
	if close_current == nil then
		close_current = true
	end

	local current_buffer = vim.api.nvim_get_current_buf()
	for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
		local should_delete = vim.api.nvim_buf_is_valid(buffer)
			and buffer ~= current_buffer
			and vim.bo[buffer].bt ~= "terminal"
		if should_delete then
			pcall(vim.api.nvim_buf_delete, buffer, { force = true })
		end
	end

	if close_current and vim.bo[current_buffer].bt ~= "terminal" then
		pcall(vim.api.nvim_buf_delete, current_buffer, { force = true })
	end
end

function M.get_visible_windows()
	local visible_windows = {}
	local current_windows = vim.api.nvim_list_wins()

	for _, winid in ipairs(current_windows) do
		local win_config = vim.api.nvim_win_get_config(winid)
		if win_config["relative"] == "" then
			table.insert(visible_windows, winid)
		end
	end

	return visible_windows
end

function M.get_visible_window_filetypes()
	local filetypes = {}
	for _, winid in ipairs(M.get_visible_windows()) do
		local buffer = vim.api.nvim_win_get_buf(winid)
		table.insert(filetypes, vim.bo[buffer].ft)
	end
	return filetypes
end

---@param toggled_types string[]
---@return string[]
function M.toggle_special_buffers(toggled_types)
	if #toggled_types ~= 0 then
		for _, type in ipairs(toggled_types) do
			M.special_windows[type]()
		end
	else
		local visible_window_filetypes = M.get_visible_window_filetypes()
		for _, filetype in ipairs(visible_window_filetypes) do
			if filetype:find("dapui") then
				filetype = "dapui"
			end
			for type, func in pairs(M.special_windows) do
				if filetype == type then
					table.insert(toggled_types, type)
					func()
				end
			end
		end
	end

	return toggled_types
end

function M.create_backdrop_window()
	vim.g.backdrop_buf = vim.api.nvim_create_buf(false, true)
	vim.g.backdrop_win = vim.api.nvim_open_win(vim.g.backdrop_buf, false, {
		relative = "editor",
		width = vim.o.columns,
		height = vim.o.lines,
		row = 0,
		col = 0,
		style = "minimal",
		focusable = false,
		zindex = 1,
	})
	vim.api.nvim_set_hl(0, "LazyBackdrop", { bg = "#000000", default = true })
	vim.api.nvim_set_option_value("winhighlight", "Normal:LazyBackdrop", { scope = "local", win = vim.g.backdrop_win })
	vim.api.nvim_set_option_value("winblend", 40, { scope = "local", win = vim.g.backdrop_win })
	vim.bo[vim.g.backdrop_buf].buftype = "nofile"
	vim.bo[vim.g.backdrop_buf].filetype = "backdrop"
end

function M.close_backdrop_window()
	local backdrop_buf = vim.g.backdrop_buf
	local backdrop_win = vim.g.backdrop_win
	vim.g.backdrop_buf = nil
	vim.g.backdrop_win = nil
	if backdrop_win and vim.api.nvim_win_is_valid(backdrop_win) then
		vim.api.nvim_win_close(backdrop_win, true)
	end
	if backdrop_buf and vim.api.nvim_buf_is_valid(backdrop_buf) then
		vim.api.nvim_buf_delete(backdrop_buf, { force = true })
	end
end

return M
