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

function M.toggle_minifiles()
	local MiniFiles = require("mini.files")
	local function open_and_center(path)
		MiniFiles.open(path)
		MiniFiles.go_out()
		MiniFiles.go_in()
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

local typed_letters = {}
local keys_buf, keys_win
local ns = vim.api.nvim_create_namespace("keys")
local plugin_loaded = false
local keys_config = {
	win_opts = {
		relative = "win",
		style = "minimal",
		border = "rounded",
		row = vim.fn.round(vim.o.lines * 1.25),
		col = vim.fn.round(vim.o.columns * 2),
		width = 75,
		height = 3,
	},
	enable_on_startup = false,
}
local win_loaded = false

local t = vim.keycode or function(str)
	return vim.api.nvim_replace_termcodes(str, true, true, true)
end

-- TODO: ⇧+ (for shift+), ⌥+ (for alt+) (also see: https://wincent.com/wiki/Unicode_representations_of_modifier_keys)
local spec_table = {
	[t("<tab>")] = "⇥",
	[t("<cr>")] = "⏎ ",
	[t("<esc>")] = "⎋",
	[" "] = "␣",
	[t("<S-Space>")] = "⇧󱁐",
	[t("<del>")] = "⌦",
	[t("<bs>")] = "⌫",
	[t("<up>")] = "↑",
	[t("<down>")] = "↓",
	[t("<left>")] = "←",
	[t("<right>")] = "→",
	[t("<home>")] = "⇱",
	[t("<end>")] = "⇲",
	[t("<PageUp>")] = "⇞",
	[t("<PageDown>")] = "⇟",
	[t("<insert>")] = "⎀",
	[t("<C-d>")] = "⌃d",
}

local spc = {
	["<t_\253g>"] = " ", -- lua function key
	-- Sometimes keytrans incorrectly translates keys to <C-D>.
	-- Ctrl-d is handled in spec_table instead
	["<C-D>"] = false,
	["<Cmd>"] = false,
}

local function create_keys_float()
	keys_buf = vim.api.nvim_create_buf(false, true)
	keys_win = vim.api.nvim_open_win(keys_buf, false, keys_config.win_opts)
	vim.api.nvim_buf_set_option(keys_buf, "filetype", "keys")
end

local function render_keys()
	local text = table.concat(typed_letters, " ")
	local pad = (" "):rep(math.floor((keys_config.win_opts.width - vim.api.nvim_strwidth(text)) / 2))
	local set_lines = pad .. table.concat(typed_letters, " ") .. pad
	vim.api.nvim_buf_set_lines(keys_buf, 1, 2, false, { set_lines })
end

local function sanitize_key(key)
	for k, v in pairs(spec_table) do
		if key == k then
			return v
		end
	end
	local b = key:byte()
	if b <= 126 and b >= 33 then
		return key
	end

	local translated = vim.fn.keytrans(key)
	local special = spc[translated]
	if special ~= nil then
		return special
	end
	local match = translated:match("^<C.-(.)>$")
	if match then
		local shift = translated:match("^<C[-]S[-].>$")
		if not shift then
			match = match:lower()
		end
		return "⌃" .. match
	end

	-- Mouse events
	if translated:match("Left") or translated:match("Mouse") or translated:match("Scroll") then
		return "󰍽 "
	end

	return translated
end

local function register_keys(key)
	key = sanitize_key(key)

	if key and plugin_loaded and vim.bo.bt ~= "terminal" then
		if #typed_letters >= 35 then
			table.remove(typed_letters, 1)
		end
		table.insert(typed_letters, key)
		if win_loaded then
			render_keys()
		end
	end
end

local function start_registering_keys()
	vim.on_key(register_keys, ns)
	plugin_loaded = true
end

function M.toggle_keys_window()
	if win_loaded then
		vim.api.nvim_win_close(keys_win, true)
		vim.api.nvim_buf_delete(keys_buf, { force = true })
		vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
	else
		create_keys_float()
		start_registering_keys()
	end
	win_loaded = not win_loaded
end

M.stop = function()
	vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
end

return M
