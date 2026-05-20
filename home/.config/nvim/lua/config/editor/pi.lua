local M = {}

local state = {
	manual_cwd = nil,
	tmux = {},
}

M.opts = {
	prompts = {
		commit = {
			prompt = "Please update the WIP commit with a more descriptive message, use git log -n 5 to see recent commits for message format. DO NOT use conventional commit format, just a descriptive message is enough. If required add multiline details in the body of the commit message. If there is no WIP commit but there are unstaged changes then create a new commit with a descriptive message. If there are no WIP commits and no unstaged changes then do nothing.",
			submit = false,
			skip_input = true,
			capture = "none",
		},
		review_this = {
			prompt = "Review the following editor context for correctness and readability.",
			submit = false,
			skip_input = true,
			capture = "current",
		},
		ask_this = {
			submit = false,
			capture = "current",
			ui_prompt = "Ask Pi about current context: ",
		},
		send_this = {
			submit = false,
			capture = "current",
			label = "current context",
		},
		send_buffer = {
			submit = false,
			capture = "buffer",
			reference_mode = "path",
			label = "current buffer",
		},
		verbatim = {
			submit = false,
			skip_input = true,
			capture = "current",
			raw = true,
			label = "raw selection",
		},
	},
}

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
	local root_marker = vim.fs.find("scripts/manifest.tsv", { upward = true, path = vim.fs.dirname(resolved_source), limit = 1 })[1]
	if root_marker == nil then
		error("Unable to locate dotfiles root from config.editor.pi")
	end
	return vim.fs.dirname(vim.fs.dirname(root_marker))
end

local function tmux_helper_path()
	return vim.fs.joinpath(dotfiles_root(), "home", ".config", "tmux", "ensure_pi_tmux_session.sh")
end

local function normalize_cwd(path)
	local cwd = path
	if cwd == nil or cwd == "" then
		cwd = vim.fn.getcwd()
	end

	cwd = vim.uv.fs_realpath(cwd) or vim.fn.fnamemodify(cwd, ":p")
	local root = vim.fn.systemlist({ "git", "-C", cwd, "rev-parse", "--show-toplevel" })
	if vim.v.shell_error == 0 and root[1] ~= nil and root[1] ~= "" then
		return root[1]
	end
	return cwd
end

local function current_target_cwd(opts)
	if opts and opts.cwd then
		return normalize_cwd(opts.cwd)
	end
	return normalize_cwd(state.manual_cwd or vim.fn.getcwd())
end

local function current_buffer_path(bufnr)
	bufnr = bufnr or 0
	local name = vim.api.nvim_buf_get_name(bufnr)
	if name == "" then
		return "[No Name]"
	end
	return vim.uv.fs_realpath(name) or name
end

local function buffer_text(bufnr)
	bufnr = bufnr or 0
	return table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
end

local function get_visual_selection()
	local mode = vim.fn.mode()
	if not vim.tbl_contains({ "v", "V", "\22" }, mode) then
		return nil
	end

	local bufnr = 0
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
		kind = "selection",
		path = current_buffer_path(bufnr),
		start_row = start_row,
		end_row = end_row,
		text = table.concat(lines, "\n"),
		filetype = vim.bo[bufnr].filetype,
	}
end

local function surrounding_excerpt(bufnr)
	bufnr = bufnr or 0
	local line_count = vim.api.nvim_buf_line_count(bufnr)
	local row = vim.api.nvim_win_get_cursor(0)[1]
	local start_row = math.max(1, row - 20)
	local end_row = math.min(line_count, row + 20)
	return {
		kind = "excerpt",
		path = current_buffer_path(bufnr),
		start_row = start_row,
		end_row = end_row,
		cursor_row = row,
		text = table.concat(vim.api.nvim_buf_get_lines(bufnr, start_row - 1, end_row, false), "\n"),
		filetype = vim.bo[bufnr].filetype,
	}
end

local function capture_current_context()
	local selection = get_visual_selection()
	if selection ~= nil and trim(selection.text) ~= "" then
		return selection
	end

	local bufnr = 0
	local modified = vim.bo[bufnr].modified
	local line_count = vim.api.nvim_buf_line_count(bufnr)
	if modified or line_count <= 300 then
		return {
			kind = "buffer",
			path = current_buffer_path(bufnr),
			modified = modified,
			start_row = 1,
			end_row = line_count,
			text = buffer_text(bufnr),
			filetype = vim.bo[bufnr].filetype,
		}
	end

	return surrounding_excerpt(bufnr)
end

local function capture_buffer_context()
	local bufnr = 0
	return {
		kind = "buffer",
		path = current_buffer_path(bufnr),
		modified = vim.bo[bufnr].modified,
		start_row = 1,
		end_row = vim.api.nvim_buf_line_count(bufnr),
		text = buffer_text(bufnr),
		filetype = vim.bo[bufnr].filetype,
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

local function collect_capture(mode)
	if mode == "buffer" then
		return capture_buffer_context()
	end
	if mode == "current" then
		return capture_current_context()
	end
	return nil
end

local function format_context_reference(context, mode)
	if context == nil or context.path == nil or context.path == "" or context.path == "[No Name]" then
		return nil
	end
	if mode == "path" then
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

local function compose_request_text(user_prompt, references)
	if references == nil or #references == 0 then
		return user_prompt or ""
	end
	if user_prompt == nil or user_prompt == "" then
		return table.concat(references, "\n")
	end
	return string.format("%s\n%s", user_prompt, table.concat(references, "\n"))
end

local function resolve_prompt(prompt, opts)
	opts = opts or {}
	if type(prompt) == "string" and M.opts.prompts[prompt] ~= nil then
		local resolved = vim.tbl_deep_extend("force", vim.deepcopy(M.opts.prompts[prompt]), opts)
		return resolved.prompt, resolved
	end
	if prompt == "@this: " or prompt == "@this:" then
		local resolved = vim.tbl_deep_extend("force", vim.deepcopy(M.opts.prompts.ask_this), opts)
		return resolved.prompt, resolved
	end
	return prompt, opts
end

local function store_tmux_info(cwd, info)
	state.tmux[cwd] = info
end

local function get_tmux_info(cwd)
	return state.tmux[cwd or current_target_cwd()]
end

local function system_json(args, opts, callback)
	opts = opts or {}
	vim.system(args, opts, function(result)
		vim.schedule(function()
			if result.code ~= 0 then
				local message = trim(result.stderr)
				if message == "" then
					message = trim(result.stdout)
				end
				callback(false, message, result)
				return
			end
			local stdout = trim(result.stdout)
			if stdout == "" then
				callback(true, nil, result)
				return
			end
			local ok, decoded = pcall(vim.json.decode, stdout)
			if ok then
				callback(true, decoded, result)
			else
				callback(false, "Failed to decode command output", result)
			end
		end)
	end)
end

local focus_tmux_target

local function ensure_tmux_agent(opts, callback)
	opts = opts or {}
	local cwd = current_target_cwd(opts)
	local args = { tmux_helper_path(), "--cwd", cwd, "--json" }
	if opts.session_file and opts.session_file ~= "" then
		vim.list_extend(args, { "--session-file", opts.session_file })
	end

	system_json(args, { text = true }, function(ok, decoded, result)
		if not ok then
			notify(decoded ~= "" and decoded or string.format("Failed to ensure Pi tmux agent for %s", cwd), vim.log.levels.ERROR)
			if callback then
				callback(false, result)
			end
			return
		end

		store_tmux_info(cwd, decoded)
		local function finish_success()
			if opts.notify_success then
				notify(opts.notify_success)
			elseif decoded and decoded.restartReason and decoded.restartReason ~= "" then
				notify(string.format("Synced Pi tmux agent (%s)", decoded.restartReason))
			end
			if callback then
				callback(true, decoded)
			end
		end

		if opts.focus_after_ensure == false then
			finish_success()
			return
		end

		focus_tmux_target(decoded, function()
			finish_success()
		end)
	end)
end

local function with_tmux_agent(opts, callback)
	opts = opts or {}
	ensure_tmux_agent(opts, function(ok, info)
		if ok and info ~= nil then
			callback(info)
		end
	end)
end

local function tmux_run(args, opts, callback)
	opts = opts or {}
	vim.system(args, opts, function(result)
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

focus_tmux_target = function(info, callback)
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

local function paste_text_to_tmux(text, opts)
	opts = opts or {}
	local cwd = current_target_cwd(opts)
	with_tmux_agent({ cwd = cwd }, function(info)
		local pane_id = info.paneId
		local buffer_name = string.format("pi.nvim.%d", vim.uv.hrtime())
		tmux_run({ "tmux", "load-buffer", "-b", buffer_name, "-" }, { stdin = text }, function(ok)
			if not ok then
				return
			end
			local function finish_success()
				if opts.focus_after_send == false then
					if opts.notify_success then
						notify(opts.notify_success)
					end
					return
				end
				focus_tmux_target(info, function(focus_ok)
					if focus_ok and opts.notify_success then
						notify(opts.notify_success)
					elseif opts.notify_success then
						notify(opts.notify_success)
					end
				end)
			end
			tmux_run({ "tmux", "paste-buffer", "-d", "-p", "-b", buffer_name, "-t", pane_id }, {}, function(paste_ok)
				if not paste_ok then
					return
				end
				if opts.submit then
					tmux_run({ "tmux", "send-keys", "-t", pane_id, "Enter" }, {}, function(send_ok)
						if send_ok then
							finish_success()
						end
					end)
				else
					finish_success()
				end
			end)
		end)
	end)
end

local function send_command_to_tmux(command, opts)
	opts = vim.tbl_extend("force", { submit = true }, opts or {})
	paste_text_to_tmux(command, opts)
end

local function list_worktrees(cwd, callback)
	local target = current_target_cwd({ cwd = cwd })
	vim.system({ "git", "-C", target, "worktree", "list", "--porcelain" }, { text = true }, function(result)
		vim.schedule(function()
			if result.code ~= 0 then
				local message = trim(result.stderr)
				if message == "" then
					message = trim(result.stdout)
				end
				notify(message ~= "" and message or "Failed to list git worktrees", vim.log.levels.ERROR)
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
					local path = line:sub(#"worktree " + 1)
					current = {
						cwd = normalize_cwd(path),
						path = path,
					}
				elseif current ~= nil and vim.startswith(line, "branch ") then
					current.branch = line:sub(#"branch " + 1)
				end
			end
			if current ~= nil then
				table.insert(items, current)
			end
			callback(items)
		end)
	end)
end

function M.ensure_current_server(opts)
	ensure_tmux_agent(opts)
end

function M.prompt(prompt, opts)
	local resolved_prompt, resolved_opts = resolve_prompt(prompt, opts)
	local cwd = current_target_cwd(resolved_opts)
	local context = collect_capture(resolved_opts.capture)
	leave_visual_mode_if_needed()
	local references = {}
	local reference = format_context_reference(context, resolved_opts.reference_mode)
	if reference ~= nil then
		table.insert(references, reference)
	end

	local function send_message(user_prompt)
		local message
		if resolved_opts.raw then
			if context == nil or trim(context.text or "") == "" then
				notify("No selection or context available to paste verbatim", vim.log.levels.WARN)
				return
			end
			message = context.text
		else
			message = compose_request_text(user_prompt, references)
			if trim(message) == "" then
				if context ~= nil and context.path == "[No Name]" then
					notify("Current buffer has no file path. Save it first or use <leader>cv for raw content.", vim.log.levels.WARN)
				else
					notify("No file reference available to send to Pi", vim.log.levels.WARN)
				end
				return
			end
		end

		paste_text_to_tmux(message .. " ", {
			cwd = cwd,
			submit = resolved_opts.submit == true,
			notify_success = resolved_opts.raw and "Pasted raw content into Pi tmux session"
				or (resolved_opts.submit == true and "Sent prompt to Pi tmux session" or "Pasted prompt into Pi tmux session"),
		})
	end

	if resolved_opts.skip_input then
		send_message(resolved_prompt or "")
		return
	end

	if resolved_prompt == nil and (#references > 0 or resolved_opts.raw) then
		send_message(nil)
		return
	end

	vim.ui.input({
		prompt = resolved_opts.ui_prompt or "Pi prompt: ",
		default = resolved_prompt or "",
	}, function(input)
		if input == nil then
			return
		end
		send_message(input)
	end)
end

function M.ask(prompt, opts)
	M.prompt(prompt, opts)
end

function M.select_session(opts)
	leave_visual_mode_if_needed()
	local cwd = current_target_cwd(opts)
	send_command_to_tmux("/resume", {
		cwd = cwd,
		notify_success = "Opened Pi session picker in tmux",
	})
end

function M.select_server()
	leave_visual_mode_if_needed()
	list_worktrees(current_target_cwd(), function(worktrees)
		local current_cwd = current_target_cwd({ cwd = vim.fn.getcwd() })
		local items = {
			{ label = string.format("Current working directory — %s", current_cwd), cwd = current_cwd },
		}
		local seen = { [current_cwd] = true }
		for _, item in ipairs(worktrees) do
			local cwd = normalize_cwd(item.cwd)
			if not seen[cwd] then
				seen[cwd] = true
				table.insert(items, {
					label = string.format("%s — %s", cwd, item.branch or "worktree"),
					cwd = cwd,
				})
			end
		end

		vim.ui.select(items, {
			prompt = "Select Pi target worktree",
			format_item = function(item)
				return item.label
			end,
		}, function(choice)
			if choice == nil then
				return
			end
			state.manual_cwd = choice.cwd
			ensure_tmux_agent({ cwd = choice.cwd, notify_success = string.format("Selected Pi target %s", choice.cwd) })
		end)
	end)
end

function M.reset_manual_server_override()
	state.manual_cwd = nil
	notify("Reset Pi target override")
end

function M.disconnect()
	state.manual_cwd = nil
	notify("Cleared the Pi manual target override")
end

function M.ensure_tmux_agent(opts)
	opts = opts or {}
	ensure_tmux_agent({
		cwd = current_target_cwd(opts),
		session_file = opts.session_file,
		notify_success = opts.notify_success or string.format("Pi tmux agent is ready for %s", current_target_cwd(opts)),
	})
end

function M.open_output()
	local cwd = current_target_cwd()
	local info = get_tmux_info(cwd)
	with_tmux_agent({ cwd = cwd }, function(active)
		local tmux_target = (active or info or {}).tmuxTarget or "Pi tmux window"
		notify(string.format("Pi output lives in tmux (%s)", tmux_target))
		tmux_run({ "tmux", "select-window", "-t", tmux_target }, {}, function() end)
	end)
end

function M.submit_tmux_prompt(opts)
	local cwd = current_target_cwd(opts)
	with_tmux_agent({ cwd = cwd }, function(info)
		tmux_run({ "tmux", "send-keys", "-t", info.paneId, "Enter" }, {}, function(ok)
			if ok then
				focus_tmux_target(info, function()
					notify("Submitted current Pi tmux prompt")
				end)
			end
		end)
	end)
end

function M.interrupt()
	local cwd = current_target_cwd()
	with_tmux_agent({ cwd = cwd }, function(info)
		tmux_run({ "tmux", "send-keys", "-t", info.paneId, "C-c" }, {}, function(ok)
			if ok then
				focus_tmux_target(info, function()
					notify("Interrupted Pi tmux session")
				end)
			end
		end)
	end)
end

function M.select()
	leave_visual_mode_if_needed()
	local actions = {
		{
			label = "Paste file/line reference",
			run = function()
				M.prompt("send_this")
			end,
		},
		{
			label = "Paste file reference",
			run = function()
				M.prompt("send_buffer")
			end,
		},
		{
			label = "Paste raw content",
			run = function()
				M.prompt("verbatim")
			end,
		},
		{
			label = "Ask about current context",
			run = function()
				M.ask("ask_this")
			end,
		},
		{
			label = "Review current context",
			run = function()
				M.prompt("review_this")
			end,
		},
		{
			label = "Ensure tmux agent",
			run = function()
				M.ensure_tmux_agent()
			end,
		},
		{
			label = "Focus Pi tmux",
			run = function()
				M.open_output()
			end,
		},
		{
			label = "Submit tmux prompt",
			run = function()
				M.submit_tmux_prompt()
			end,
		},
		{
			label = "Interrupt session",
			run = function()
				M.interrupt()
			end,
		},
		{
			label = "New session",
			run = function()
				send_command_to_tmux("/new", { notify_success = "Started a new Pi session in tmux" })
			end,
		},
		{
			label = "Select session",
			run = function()
				M.select_session()
			end,
		},
		{
			label = "Compact session",
			run = function()
				send_command_to_tmux("/compact", { notify_success = "Started Pi compaction in tmux" })
			end,
		},
		{
			label = "Select target",
			run = function()
				M.select_server()
			end,
		},
		{
			label = "Reset target override",
			run = function()
				M.reset_manual_server_override()
			end,
		},
	}

	vim.ui.select(actions, {
		prompt = "Pi action",
		format_item = function(item)
			return item.label
		end,
	}, function(choice)
		if choice then
			choice.run()
		end
	end)
end

return M
