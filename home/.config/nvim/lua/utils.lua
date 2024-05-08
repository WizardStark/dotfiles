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

-- Cache for git status
local gitStatusCache = {}
local cacheTimeout = 2000 -- Cache timeout in milliseconds

function M.toggle_minifiles()
	local MiniFiles = require("mini.files")
	local function open_and_center(path)
		local git_root = vim.trim(vim.fn.system("git rev-parse --show-toplevel"))

		MiniFiles.open(path)
		-- local bufnr = vim.api.nvim_get_current_buf()
		-- if gitStatusCache[git_root] then
		-- 	M.updateMiniWithGit(bufnr, gitStatusCache[git_root].statusMap)
		-- end

		MiniFiles.go_out()
		-- bufnr = vim.api.nvim_get_current_buf()
		-- if gitStatusCache[git_root] then
		-- 	M.updateMiniWithGit(bufnr, gitStatusCache[git_root].statusMap)
		-- end

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

local nsMiniFiles = vim.api.nvim_create_namespace("mini_files_git")

function M.getStatusCache()
	return gitStatusCache
end

local function mapSymbols(status)
	local statusMap = {
		[" M"] = { symbol = "┃", hlGroup = "GitSignsChange" }, -- Modified in the working directory
		["M "] = { symbol = "┃", hlGroup = "GitSignsChange" }, -- modified in index
		["MM"] = { symbol = "┃", hlGroup = "GitSignsChange" }, -- modified in both working tree and index
		["A "] = { symbol = "┃", hlGroup = "GitSignsAdd" }, -- Added to the staging area, new file
		["AA"] = { symbol = "┃", hlGroup = "GitSignsAdd" }, -- file is added in both working tree and index
		["D "] = { symbol = "▁", hlGroup = "GitSignsDelete" }, -- Deleted from the staging area
		["AM"] = { symbol = "┃", hlGroup = "GitSignsChange" }, -- added in working tree, modified in index
		["AD"] = { symbol = "┃", hlGroup = "GitSignsChange" }, -- Added in the index and deleted in the working directory
		["R "] = { symbol = "┃", hlGroup = "GitSignsChange" }, -- Renamed in the index
		["U "] = { symbol = "┃", hlGroup = "GitSignsChange" }, -- Unmerged path
		["UU"] = { symbol = "┃", hlGroup = "GitSignsAdd" }, -- file is unmerged
		["UA"] = { symbol = "┃", hlGroup = "GitSignsAdd" }, -- file is unmerged and added in working tree
		["??"] = { symbol = "▁", hlGroup = "GitSignsUntracked" }, -- Untracked files
		["!!"] = { symbol = "", hlGroup = "GitSignsUntracked" }, -- Ignored files
	}

	local result = statusMap[status] or { symbol = "?", hlGroup = "NonText" }
	return result.symbol, result.hlGroup
end

local function fetchGitStatus(cwd, callback)
	local stdout = (vim.uv or vim.loop).new_pipe(false)
	local handle, pid
	handle, pid = (vim.uv or vim.loop).spawn("git", {
		args = { "status", "--ignored", "--porcelain" },
		cwd = cwd,
		stdio = { nil, stdout, nil },
	}, function(code, signal)
		if code == 0 then
			stdout:read_start(function(err, content)
				if content then
					callback(content)
					vim.g.content = content
				end
				stdout:close()
			end)
		else
			vim.notify("Git command failed with exit code: " .. code, vim.log.levels.ERROR)
			stdout:close()
		end
	end)
end

local function escapePattern(str)
	return str:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end

function M.updateMiniWithGit(buf_id, gitStatusMap)
	local MiniFiles = require("mini.files")
	vim.schedule(function()
		local nlines = vim.api.nvim_buf_line_count(buf_id)
		local git_root = vim.trim(vim.fn.system("git rev-parse --show-toplevel"))
		local escaped_root = escapePattern(git_root)
		if vim.fn.has("win32") == 1 then
			escaped_root = escaped_root:gsub("\\", "/")
		end

		for i = 1, nlines do
			local entry = MiniFiles.get_fs_entry(buf_id, i)
			if not entry then
				break
			end
			local relativePath = entry.path:gsub("^" .. escaped_root .. "/", "")
			local status = gitStatusMap[relativePath]

			if status then
				local symbol, hlGroup = mapSymbols(status)
				vim.api.nvim_buf_set_extmark(buf_id, nsMiniFiles, i - 1, 0, {
					-- NOTE: if you want the signs on the right uncomment those and comment
					-- the 3 lines after
					-- virt_text = { { symbol, hlGroup } },
					-- virt_text_pos = "right_align",
					sign_text = symbol,
					sign_hl_group = hlGroup,
					priority = 2,
				})
			else
			end
		end
	end)
end

-- Thanks for the idea of gettings https://github.com/refractalize/oil-git-status.nvim signs for dirs
local function parseGitStatus(content)
	local gitStatusMap = {}
	-- lua match is faster than vim.split (in my experience )
	for line in content:gmatch("[^\r\n]+") do
		local status, filePath = string.match(line, "^(..)%s+(.*)")
		-- Split the file path into parts
		local parts = {}
		for part in filePath:gmatch("[^/]+") do
			table.insert(parts, part)
		end
		-- Start with the root directory
		local currentKey = ""
		for i, part in ipairs(parts) do
			if i > 1 then
				-- Concatenate parts with a separator to create a unique key
				currentKey = currentKey .. "/" .. part
			else
				currentKey = part
			end
			-- If it's the last part, it's a file, so add it with its status
			if i == #parts then
				gitStatusMap[currentKey] = status
			else
				-- If it's not the last part, it's a directory. Check if it exists, if not, add it.
				if not gitStatusMap[currentKey] then
					gitStatusMap[currentKey] = status
				end
			end
		end
	end

	return gitStatusMap
end

function M.updateGitStatus(buf_id)
	if vim.fn.system("git rev-parse --show-toplevel 2> /dev/null") == "" then
		return
	end
	local git_root = vim.trim(vim.fn.system("git rev-parse --show-toplevel"))
	local currentTime = os.time()
	if gitStatusCache[git_root] and currentTime - gitStatusCache[git_root].time < cacheTimeout then
		M.updateMiniWithGit(buf_id, gitStatusCache[git_root].statusMap)
	else
		fetchGitStatus(git_root, function(content)
			local gitStatusMap = parseGitStatus(content)
			gitStatusCache[git_root] = {
				time = currentTime,
				statusMap = gitStatusMap,
			}
			M.updateMiniWithGit(buf_id, gitStatusMap)
		end)
	end
end

function M.clearCache()
	gitStatusCache = {}
end

function M.wo(win, k, v)
	if vim.api.nvim_set_option_value then
		vim.api.nvim_set_option_value(k, v, { scope = "local", win = win })
	else
		vim.wo[win][k] = v
	end
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
	vim.api.nvim_set_option_value("winblend", 60, { scope = "local", win = vim.g.backdrop_win })
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
