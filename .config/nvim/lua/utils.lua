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

return M
