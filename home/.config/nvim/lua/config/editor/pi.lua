local M = {}

local EXCERPT_RADIUS = 20
local MAX_BUFFER_BYTES = 50000
local TMUX_SCAN_CACHE_TTL_MS = 1000
local WORKTREE_LIST_CACHE_TTL_MS = 2000

local state = {
	manual_cwd = nil,
	selected_target = nil,
	git_roots = {},
	tmux_scan = nil,
	worktree_lists = {},
}

local function cache_is_fresh(entry, ttl_ms)
	return entry ~= nil and (vim.uv.now() - entry.ts) < ttl_ms
end

local function notify(message, level)
	vim.notify(message, level or vim.log.levels.INFO, { title = "Pi" })
end

local function trim(text)
	return vim.trim(text or "")
end

local function split_lines(text)
	if text == nil or text == "" then
		return { "" }
	end
	return vim.split(text:gsub("\r\n", "\n"), "\n", { plain = true })
end

local function dotfiles_root()
	local source = debug.getinfo(1, "S").source:sub(2)
	local resolved_source = vim.uv.fs_realpath(source) or source
	local root_marker =
		vim.fs.find("scripts/manifest.tsv", { upward = true, path = vim.fs.dirname(resolved_source), limit = 1 })[1]
	if root_marker == nil then
		error("Unable to locate dotfiles root from config.editor.pi")
	end
	return vim.fs.dirname(vim.fs.dirname(root_marker))
end

local function tmux_helper_path()
	return vim.fs.joinpath(dotfiles_root(), "home", ".config", "tmux", "ensure_pi_tmux_session.sh")
end

local function normalize_path(path)
	local value = path
	if value == nil or value == "" then
		value = vim.fn.getcwd()
	end
	return vim.uv.fs_realpath(value) or vim.fn.fnamemodify(value, ":p")
end

local function git_root_for(cwd)
	cwd = normalize_path(cwd)
	local cached = state.git_roots[cwd]
	if cached ~= nil then
		return cached ~= false and cached or nil
	end

	local root = vim.fn.systemlist({ "git", "-C", cwd, "rev-parse", "--show-toplevel" })
	if vim.v.shell_error == 0 and root[1] ~= nil and root[1] ~= "" then
		local normalized = normalize_path(root[1])
		state.git_roots[cwd] = normalized
		state.git_roots[normalized] = normalized
		return normalized
	end

	state.git_roots[cwd] = false
	return nil
end

local function same_worktree(left, right)
	left = normalize_path(left)
	right = normalize_path(right)
	if left == right then
		return true
	end
	local left_root = git_root_for(left)
	local right_root = git_root_for(right)
	return left_root ~= nil and right_root ~= nil and left_root == right_root
end

local function current_target_cwd(opts)
	if opts and opts.cwd then
		return normalize_path(opts.cwd)
	end
	return normalize_path(state.manual_cwd or vim.fn.getcwd())
end

local function current_buffer_path(bufnr)
	bufnr = bufnr or 0
	local name = vim.api.nvim_buf_get_name(bufnr)
	if name == "" then
		return "[No Name]"
	end
	return normalize_path(name)
end

local function context_filetype(bufnr)
	bufnr = bufnr or 0
	local filetype = trim(vim.bo[bufnr].filetype)
	return filetype ~= "" and filetype or "text"
end

local function buffer_byte_size(bufnr)
	bufnr = bufnr or 0
	local line_count = vim.api.nvim_buf_line_count(bufnr)
	local ok, offset = pcall(vim.api.nvim_buf_get_offset, bufnr, line_count)
	if ok and type(offset) == "number" then
		return offset
	end
	return nil
end

local function buffer_text_if_small(bufnr, max_bytes)
	bufnr = bufnr or 0
	if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
		return nil, "unavailable"
	end

	local size = buffer_byte_size(bufnr)
	if size ~= nil and size > max_bytes then
		return nil, "too_large"
	end

	local ok, lines = pcall(vim.api.nvim_buf_get_lines, bufnr, 0, -1, false)
	if not ok then
		return nil, "unavailable"
	end

	local text = table.concat(lines, "\n")
	if #text > max_bytes then
		return nil, "too_large"
	end
	return text, "ok"
end

local function get_visual_selection()
	local mode = vim.fn.mode()
	if not vim.tbl_contains({ "v", "V", "\22" }, mode) then
		return nil
	end

	pcall(vim.cmd, [[normal! vv]])

	local bufnr = vim.api.nvim_get_current_buf()
	local start_pos = vim.api.nvim_buf_get_mark(bufnr, "<")
	local end_pos = vim.api.nvim_buf_get_mark(bufnr, ">")
	local start_row, start_col = start_pos[1], start_pos[2]
	local end_row, end_col = end_pos[1], end_pos[2]
	if start_row == 0 or end_row == 0 then
		return nil
	end
	if end_row < start_row or (end_row == start_row and end_col < start_col) then
		start_row, end_row = end_row, start_row
		start_col, end_col = end_col, start_col
	end

	local lines = vim.api.nvim_buf_get_lines(bufnr, start_row - 1, end_row, false)
	if #lines == 0 then
		return nil
	end

	if mode == "v" or mode == "\22" then
		lines[1] = string.sub(lines[1], start_col + 1)
		lines[#lines] = string.sub(lines[#lines], 1, end_col + 1)
	end

	return {
		bufnr = bufnr,
		kind = "selection",
		path = current_buffer_path(bufnr),
		start_row = start_row,
		end_row = end_row,
		cursor_row = start_row,
		text = table.concat(lines, "\n"),
		filetype = context_filetype(bufnr),
	}
end

local function excerpt_context(bufnr, row)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local line_count = vim.api.nvim_buf_line_count(bufnr)
	row = math.max(1, math.min(row or vim.api.nvim_win_get_cursor(0)[1], line_count))
	local start_row = math.max(1, row - EXCERPT_RADIUS)
	local end_row = math.min(line_count, row + EXCERPT_RADIUS)
	return {
		bufnr = bufnr,
		kind = "excerpt",
		path = current_buffer_path(bufnr),
		start_row = start_row,
		end_row = end_row,
		cursor_row = row,
		text = table.concat(vim.api.nvim_buf_get_lines(bufnr, start_row - 1, end_row, false), "\n"),
		filetype = context_filetype(bufnr),
	}
end

local function current_context()
	local selection = get_visual_selection()
	if selection ~= nil and trim(selection.text) ~= "" then
		return selection
	end

	local bufnr = vim.api.nvim_get_current_buf()
	local line_count = vim.api.nvim_buf_line_count(bufnr)
	local cursor_row = vim.api.nvim_win_get_cursor(0)[1]
	if line_count <= 300 then
		local text, status = buffer_text_if_small(bufnr, MAX_BUFFER_BYTES)
		if status == "ok" then
			return {
				bufnr = bufnr,
				kind = "buffer",
				path = current_buffer_path(bufnr),
				start_row = 1,
				end_row = line_count,
				cursor_row = cursor_row,
				text = text,
				filetype = context_filetype(bufnr),
			}
		end
	end
	return excerpt_context(bufnr, cursor_row)
end

local function buffer_context()
	local bufnr = vim.api.nvim_get_current_buf()
	return {
		bufnr = bufnr,
		kind = "buffer",
		path = current_buffer_path(bufnr),
		start_row = 1,
		end_row = vim.api.nvim_buf_line_count(bufnr),
		cursor_row = vim.api.nvim_win_get_cursor(0)[1],
		filetype = context_filetype(bufnr),
	}
end

local function leave_visual_mode_if_needed()
	local mode = vim.fn.mode()
	if not vim.tbl_contains({ "v", "V", "\22" }, mode) then
		return
	end
	local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
	vim.schedule(function()
		vim.api.nvim_feedkeys(esc, "nx", false)
	end)
end

local function format_reference(context, path_only)
	if context == nil then
		return nil
	end
	if context.bufnr ~= nil and vim.bo[context.bufnr].buftype ~= "" then
		return nil
	end
	if context.path == nil or context.path == "" or context.path == "[No Name]" then
		return nil
	end
	if vim.uv.fs_stat(context.path) == nil then
		return nil
	end
	if path_only then
		return context.path
	end
	if context.start_row ~= nil and context.end_row ~= nil then
		if context.start_row == context.end_row then
			return string.format("%s:%d", context.path, context.start_row)
		end
		return string.format("%s:%d-%d", context.path, context.start_row, context.end_row)
	end
	return context.path
end

local function compose_reference_message(question, reference)
	if reference == nil or reference == "" then
		return nil
	end
	question = trim(question)
	if question == "" then
		return reference
	end
	return string.format("Question:\n%s\n\nReference:\n%s", question, reference)
end

local function is_pi_tmux_command(command, start_command)
	if command == "pi" then
		return true
	end
	if command == "node" or command == "bun" then
		local value = start_command or ""
		return value:match('^pi(?:[%s"]|$)') ~= nil
			or value:match('^"pi"(?:[%s"]|$)') ~= nil
			or value:match('[/]pi(?:[%s"]|$)') ~= nil
	end
	return false
end

local function target_info_is_alive(info, callback)
	if info == nil or info.paneId == nil or info.paneId == "" then
		callback(false)
		return
	end
	vim.system(
		{ "tmux", "display-message", "-p", "-t", info.paneId, "#{pane_dead}\t#{pane_current_command}\t#{pane_start_command}" },
		{ text = true },
		function(result)
			vim.schedule(function()
				if result.code ~= 0 then
					callback(false)
					return
				end
				local parts = vim.split(trim(result.stdout), "\t", { plain = true })
				callback(parts[1] == "0" and is_pi_tmux_command(parts[2], parts[3]))
			end)
		end
	)
end

local function tmux_run(args, opts, callback)
	vim.system(args, opts or {}, function(result)
		vim.schedule(function()
			if result.code ~= 0 then
				local message = trim(result.stderr)
				if message == "" then
					message = trim(result.stdout)
				end
				notify(message ~= "" and message or "tmux command failed", vim.log.levels.ERROR)
				if callback then
					callback(false, result)
				end
				return
			end
			if callback then
				callback(true, result)
			end
		end)
	end)
end

local function system_json(args, callback)
	vim.system(args, { text = true }, function(result)
		vim.schedule(function()
			if result.code ~= 0 then
				local message = trim(result.stderr)
				if message == "" then
					message = trim(result.stdout)
				end
				callback(false, message)
				return
			end
			local stdout = trim(result.stdout)
			local ok, decoded = pcall(vim.json.decode, stdout)
			if ok then
				callback(true, decoded)
			else
				callback(false, "Failed to decode command output")
			end
		end)
	end)
end

local function resolve_tmux_client(callback)
	local function fallback_to_attached_client()
		vim.system({ "tmux", "list-clients", "-F", "#{client_tty}\t#{client_activity}" }, { text = true }, function(result)
			vim.schedule(function()
				if result.code ~= 0 then
					callback(nil)
					return
				end
				local best_tty = nil
				local best_activity = -1
				for _, line in ipairs(split_lines(result.stdout)) do
					local tty, activity = line:match("^(.-)\t(%d+)$")
					local score = tonumber(activity)
					if tty ~= nil and tty ~= "" and score ~= nil and score > best_activity then
						best_tty = tty
						best_activity = score
					end
				end
				callback(best_tty)
			end)
		end)
	end

	if vim.env.TMUX_PANE ~= nil and vim.env.TMUX_PANE ~= "" then
		vim.system({ "tmux", "display-message", "-p", "-t", vim.env.TMUX_PANE, "#{client_tty}" }, { text = true }, function(result)
			vim.schedule(function()
				if result.code == 0 then
					local tty = trim(result.stdout)
					if tty ~= "" then
						callback(tty)
						return
					end
				end
				fallback_to_attached_client()
			end)
		end)
		return
	end

	fallback_to_attached_client()
end

local function focus_tmux_target(info, callback)
	if info == nil or info.tmuxTarget == nil or info.tmuxTarget == "" then
		if callback then
			callback(false)
		end
		return
	end

	local function finish_window_focus()
		tmux_run({ "tmux", "select-window", "-t", info.tmuxTarget }, {}, function(window_ok)
			if not window_ok then
				if callback then
					callback(false)
				end
				return
			end
			if info.paneId == nil or info.paneId == "" then
				if callback then
					callback(true)
				end
				return
			end
			tmux_run({ "tmux", "select-pane", "-t", info.paneId }, {}, function(pane_ok)
				if callback then
					callback(pane_ok)
				end
			end)
		end)
	end

	resolve_tmux_client(function(client_tty)
		if client_tty == nil or client_tty == "" or info.tmuxSession == nil or info.tmuxSession == "" then
			finish_window_focus()
			return
		end
		vim.system({ "tmux", "switch-client", "-c", client_tty, "-t", info.tmuxSession }, { text = true }, function(_)
			vim.schedule(function()
				finish_window_focus()
			end)
		end)
	end)
end

local list_active_tmux_targets

list_active_tmux_targets = function(callback)
	if cache_is_fresh(state.tmux_scan, TMUX_SCAN_CACHE_TTL_MS) then
		callback(vim.deepcopy(state.tmux_scan.items))
		return
	end

	vim.system(
		{
			"tmux",
			"list-panes",
			"-a",
			"-F",
			"#{session_name}\t#{window_id}\t#{window_name}\t#{pane_id}\t#{pane_dead}\t#{pane_current_command}\t#{pane_start_command}\t#{pane_current_path}",
		},
		{ text = true },
		function(result)
			vim.schedule(function()
				if result.code ~= 0 then
					callback({})
					return
				end
				local items = {}
				local seen = {}
				for _, line in ipairs(split_lines(result.stdout)) do
					local parts = vim.split(line, "\t", { plain = true })
					if #parts >= 8 and parts[5] == "0" and is_pi_tmux_command(parts[6], parts[7]) then
						local cwd = normalize_path(parts[8])
						local key = table.concat({ parts[1], parts[2], parts[4] }, "\t")
						if not seen[key] then
							seen[key] = true
							table.insert(items, {
								cwd = cwd,
								paneId = parts[4],
								tmuxSession = parts[1],
								tmuxTarget = parts[2],
								label = string.format("Active Pi — %s (%s:%s %s)", cwd, parts[1], parts[3], parts[4]),
							})
						end
					end
				end
				state.tmux_scan = { ts = vim.uv.now(), items = items }
				callback(vim.deepcopy(items))
			end)
		end
	)
end

local function list_worktrees(cwd, callback)
	local repo_root = git_root_for(cwd)
	if repo_root == nil then
		callback({})
		return
	end

	local cached = state.worktree_lists[repo_root]
	if cache_is_fresh(cached, WORKTREE_LIST_CACHE_TTL_MS) then
		callback(vim.deepcopy(cached.items))
		return
	end

	vim.system({ "git", "-C", repo_root, "worktree", "list", "--porcelain" }, { text = true }, function(result)
		vim.schedule(function()
			if result.code ~= 0 then
				callback({})
				return
			end
			local items = {}
			local current = nil
			for _, line in ipairs(split_lines(result.stdout)) do
				if vim.startswith(line, "worktree ") then
					if current ~= nil then
						table.insert(items, current)
					end
					current = { cwd = normalize_path(line:sub(#"worktree " + 1)) }
				elseif current ~= nil and vim.startswith(line, "branch ") then
					current.branch = line:sub(#"branch " + 1)
				end
			end
			if current ~= nil then
				table.insert(items, current)
			end
			state.worktree_lists[repo_root] = { ts = vim.uv.now(), items = items }
			callback(vim.deepcopy(items))
		end)
	end)
end

local function resolve_existing_target(cwd, callback, missing_message)
	if state.selected_target ~= nil and same_worktree(state.selected_target.cwd or cwd, cwd) then
		target_info_is_alive(state.selected_target, function(alive)
			if alive then
				callback(state.selected_target)
				return
			end
			state.selected_target = nil
			resolve_existing_target(cwd, callback, missing_message)
		end)
		return
	end

	list_active_tmux_targets(function(items)
		local matches = {}
		for _, item in ipairs(items) do
			if same_worktree(item.cwd, cwd) then
				table.insert(matches, item)
			end
		end
		if #matches == 1 then
			state.selected_target = matches[1]
			callback(matches[1])
			return
		end
		if #matches > 1 then
			notify("Multiple Pi targets match this repo. Use <leader>cc to choose one.", vim.log.levels.WARN)
			return
		end
		notify(missing_message or "No existing Pi target. Use <leader>cc first.", vim.log.levels.WARN)
	end)
end

local function ensure_tmux_target(cwd, opts, callback)
	opts = opts or {}
	cwd = normalize_path(cwd)

	local function finish(info)
		local stored = vim.tbl_extend("force", info, { cwd = normalize_path(info.cwd or cwd) })
		state.selected_target = stored
		state.tmux_scan = nil
		if opts.focus then
			focus_tmux_target(stored, function(focus_ok)
				if focus_ok and opts.notify_success then
					notify(opts.notify_success)
				end
				if callback then
					callback(stored)
				end
			end)
		else
			if opts.notify_success then
				notify(opts.notify_success)
			end
			if callback then
				callback(stored)
			end
		end
	end

	local function ensure_via_helper()
		system_json({ tmux_helper_path(), "--cwd", cwd, "--json" }, function(ok, decoded)
			if not ok or decoded == nil then
				notify((type(decoded) == "string" and trim(decoded)) ~= "" and decoded or string.format("Failed to ensure Pi target for %s", cwd), vim.log.levels.ERROR)
				return
			end
			finish(decoded)
		end)
	end

	if state.selected_target ~= nil and same_worktree(state.selected_target.cwd or cwd, cwd) then
		target_info_is_alive(state.selected_target, function(alive)
			if alive then
				finish(state.selected_target)
				return
			end
			state.selected_target = nil
			ensure_tmux_target(cwd, opts, callback)
		end)
		return
	end

	list_active_tmux_targets(function(items)
		local matches = {}
		for _, item in ipairs(items) do
			if same_worktree(item.cwd, cwd) then
				table.insert(matches, item)
			end
		end
		if #matches > 1 then
			notify("Multiple Pi targets match this repo. Use <leader>cc to choose one.", vim.log.levels.WARN)
			return
		end
		if #matches == 1 then
			finish(matches[1])
			return
		end
		ensure_via_helper()
	end)
end

local function paste_text_to_target(text, opts)
	opts = opts or {}
	ensure_tmux_target(current_target_cwd(opts), { focus = false }, function(info)
		local buffer_name = string.format("pi.nvim.%d", vim.uv.hrtime())
		tmux_run({ "tmux", "load-buffer", "-b", buffer_name, "-" }, { stdin = text }, function(load_ok)
			if not load_ok then
				return
			end
			tmux_run({ "tmux", "paste-buffer", "-d", "-p", "-b", buffer_name, "-t", info.paneId }, {}, function(paste_ok)
				if not paste_ok then
					return
				end
				local function finish_success()
					if opts.notify_success then
						notify(opts.notify_success)
					end
				end
				if opts.focus_after_send == false then
					finish_success()
					return
				end
				focus_tmux_target(info, function(focus_ok)
					if focus_ok then
						finish_success()
					end
				end)
			end)
		end)
	end)
end

function M.select_target()
	leave_visual_mode_if_needed()
	local cwd = normalize_path(vim.fn.getcwd())
	list_active_tmux_targets(function(active_targets)
		list_worktrees(cwd, function(worktrees)
			local items = {}
			local seen_spawn = {}

			for _, item in ipairs(active_targets) do
				table.insert(items, vim.tbl_extend("force", item, { kind = "active" }))
			end

			local function add_spawn(label, target_cwd)
				target_cwd = normalize_path(target_cwd)
				if seen_spawn[target_cwd] then
					return
				end
				seen_spawn[target_cwd] = true
				table.insert(items, { kind = "spawn", cwd = target_cwd, label = label })
			end

			add_spawn(string.format("Spawn/select current repo — %s", cwd), cwd)
			for _, item in ipairs(worktrees) do
				add_spawn(string.format("Spawn/select repo target — %s (%s)", item.cwd, item.branch or "worktree"), item.cwd)
			end

			vim.ui.select(items, {
				prompt = "Select Pi target",
				format_item = function(item)
					return item.label
				end,
			}, function(choice)
				if choice == nil then
					return
				end
				state.manual_cwd = choice.cwd
				if choice.kind == "active" then
					state.selected_target = choice
					focus_tmux_target(choice, function(focus_ok)
						if focus_ok then
							notify(string.format("Selected Pi target %s", choice.label))
						end
					end)
					return
				end
				state.selected_target = nil
				ensure_tmux_target(choice.cwd, {
					focus = true,
					notify_success = string.format("Selected Pi target %s", choice.cwd),
				})
			end)
		end)
	end)
end

function M.disconnect()
	state.manual_cwd = nil
	state.selected_target = nil
	state.tmux_scan = nil
	notify("Cleared the Pi target override")
end

function M.focus_target(opts)
	leave_visual_mode_if_needed()
	local cwd = current_target_cwd(opts)
	resolve_existing_target(cwd, function(info)
		focus_tmux_target(info, function(focus_ok)
			if focus_ok then
				notify(string.format("Focused Pi target %s", info.tmuxTarget or info.cwd or cwd))
			end
		end)
	end, "No existing Pi target to focus. Use <leader>cc first.")
end

function M.send_current_reference()
	local context = current_context()
	leave_visual_mode_if_needed()
	local reference = format_reference(context, false)
	if reference == nil then
		notify("No file reference available to send to Pi", vim.log.levels.WARN)
		return
	end
	paste_text_to_target(reference .. " ", { notify_success = "Pasted current context reference into Pi target" })
end

function M.send_buffer_reference()
	local context = buffer_context()
	leave_visual_mode_if_needed()
	local reference = format_reference(context, true)
	if reference == nil then
		notify("No file reference available to send to Pi", vim.log.levels.WARN)
		return
	end
	paste_text_to_target(reference .. " ", { notify_success = "Pasted current buffer reference into Pi target" })
end

function M.ask_about_current()
	local context = current_context()
	leave_visual_mode_if_needed()
	local reference = format_reference(context, false)
	if reference == nil then
		notify("No file reference available to send to Pi", vim.log.levels.WARN)
		return
	end
	vim.ui.input({ prompt = "Ask Pi about current context: " }, function(input)
		if input == nil or trim(input) == "" then
			return
		end
		local message = compose_reference_message(input, reference)
		if message == nil then
			return
		end
		paste_text_to_target(message .. " ", { notify_success = "Pasted Pi question into target" })
	end)
end

function M.send_verbatim()
	local context = current_context()
	leave_visual_mode_if_needed()
	if context == nil or trim(context.text or "") == "" then
		notify("No selection or context available to paste verbatim", vim.log.levels.WARN)
		return
	end
	local text = context.text
	if context.kind == "buffer" and trim(text) == "" and context.bufnr ~= nil then
		local live_text, status = buffer_text_if_small(context.bufnr, MAX_BUFFER_BYTES)
		if status == "ok" then
			text = live_text
		else
			text = excerpt_context(context.bufnr, context.cursor_row).text
		end
		if trim(text) == "" then
			notify("No selection or context available to paste verbatim", vim.log.levels.WARN)
			return
		end
	end
	paste_text_to_target(text .. " ", { notify_success = "Pasted raw content into Pi target" })
end

return M
