local M = {}
local known_servers_by_cwd = {}
local manual_server_override = false
local manual_override_server = nil

M.opts = {
	server = {
		start = false,
		stop = false,
		toggle = false,
	},
	prompts = {
		commit = {
			prompt = "Please update the WIP commit with a more descriptive message, use git log -n 5 to see recent commits for message format. DO NOT use conventional commit format, just a descriptive message is enough. If required add multiline details in the body of the commit message. If there is no WIP commit but there are unstaged changes then create a new commit with a descriptive message. If there are no WIP commits and no unstaged changes then do nothing.",
			submit = true,
		},
		review_this = {
			prompt = "Review @this for correctness and readability",
			submit = true,
		},
		ask_this = {
			prompt = "@this: ",
			ask = true,
			submit = true,
		},
		send_this = {
			prompt = "@this ",
			submit = false,
		},
		send_buffer = {
			prompt = "@buffer ",
			submit = false,
		},
	},
	events = {
		enabled = true,
		reload = true,
	},
	select = {
		sections = {
			commands = {
				["session.new"] = "Start a new session",
				["session.select"] = "Select a session",
				["session.interrupt"] = "Interrupt the current session",
				["session.compact"] = "Compact the current session",
				["agent.cycle"] = "Cycle the selected agent",
				["prompt.submit"] = "Submit the current prompt",
				["prompt.clear"] = "Clear the current prompt",
			},
		},
	},
}

local function format_server(server)
	return string.format("%s (%s, :%d)", server.title or "<No sessions>", server.cwd, server.port)
end

local function notify(message, level)
	vim.notify(message, level, { title = "opencode" })
end

local function trim_output(result)
	if result == nil then
		return ""
	end

	return vim.trim(result.stderr ~= "" and result.stderr or result.stdout or "")
end

local function run_system(cmd, opts)
	local result = vim.system(cmd, opts or { text = true }):wait()
	return result, trim_output(result)
end

local function sanitize_tmux_name(name)
	return (name or ""):gsub("[/:.]", "-")
end

local function connect_server(server)
	require("opencode.events").connect(server)
	-- `opencode.nvim` only sets this after the first SSE arrives, which is too late
	-- for immediate prompt/action usage after switching servers.
	require("opencode.events").connected_server = server
	known_servers_by_cwd[server.cwd] = server
end

local function clear_manual_server_override()
	manual_server_override = false
	manual_override_server = nil
end

local function clear_cached_server(cwd, server)
	if cwd ~= nil then
		known_servers_by_cwd[cwd] = nil
	end

	if manual_override_server ~= nil and server ~= nil and manual_override_server.port == server.port then
		clear_manual_server_override()
	end

	local connected_server = require("opencode.events").connected_server
	if connected_server ~= nil and server ~= nil and connected_server.port == server.port then
		require("opencode.events").disconnect()
	end
end

local function find_running_server(servers, server)
	if server == nil then
		return nil
	end

	return vim.iter(servers):find(function(candidate)
		return candidate.port == server.port
	end)
end

local function get_managed_worktree_branch(cwd)
	local top_level = vim.system({ "git", "rev-parse", "--show-toplevel" }, { text = true, cwd = cwd }):wait()
	if top_level.code ~= 0 then
		return nil
	end

	local common_dir = vim.system(
		{ "git", "rev-parse", "--path-format=absolute", "--git-common-dir" },
		{ text = true, cwd = cwd }
	):wait()
	if common_dir.code ~= 0 then
		return nil
	end

	local top_level_dir = vim.trim(top_level.stdout)
	local common_dir_path = vim.trim(common_dir.stdout)
	local worktree_root =
		vim.fs.joinpath(vim.env.HOME, "projects", "worktrees", vim.fs.basename(vim.fs.dirname(common_dir_path)))
	local prefix = worktree_root .. "/"
	if top_level_dir:find(prefix, 1, true) ~= 1 then
		return nil
	end

	return top_level_dir:sub(#prefix + 1)
end

local function get_repo_tmux_target(cwd)
	local common_dir = vim.system(
		{ "git", "rev-parse", "--path-format=absolute", "--git-common-dir" },
		{ text = true, cwd = cwd }
	):wait()
	if common_dir.code ~= 0 then
		return nil, "Not in a git repository"
	end

	local common_dir_path = vim.trim(common_dir.stdout)
	local session_name = vim.fs.basename(vim.fs.dirname(common_dir_path))
	local worktree_branch = get_managed_worktree_branch(cwd)
	local branch_result = vim.system({ "git", "rev-parse", "--abbrev-ref", "HEAD" }, { text = true, cwd = cwd }):wait()
	if branch_result.code ~= 0 then
		return nil, trim_output(branch_result)
	end

	local branch_name = worktree_branch or vim.trim(branch_result.stdout)
	if branch_name == "" then
		return nil, "Unable to determine git branch"
	end

	return {
		session_name = session_name,
		window_name = sanitize_tmux_name(branch_name),
		branch_name = branch_name,
	}, nil
end

local function format_tmux_target(target)
	if target == nil then
		return "<unknown tmux target>"
	end

	return string.format("%s:%s", target.session_name, target.window_name)
end

local function diagnose_tmux_target(cwd)
	if vim.fn.executable("tmux") ~= 1 then
		return "tmux is not installed or not on PATH"
	end

	if vim.fn.executable("opencode") ~= 1 then
		return "opencode is not installed or not on PATH"
	end

	local bootstrap_script = vim.fs.joinpath(vim.env.HOME, ".config", "tmux", "create_worktree_session.sh")
	if vim.fn.executable(bootstrap_script) ~= 1 then
		return string.format("tmux bootstrap script is not executable: %s", bootstrap_script)
	end

	local target, target_err = get_repo_tmux_target(cwd)
	if target == nil then
		return target_err or "Unable to determine tmux target"
	end

	local session_check = vim.system({ "tmux", "has-session", "-t", target.session_name }, { text = true }):wait()
	if session_check.code ~= 0 then
		return string.format("tmux session %s was not created", target.session_name)
	end

	local windows, windows_output = run_system({ "tmux", "list-windows", "-t", target.session_name, "-F", "#W" }, { text = true })
	if windows.code ~= 0 then
		return string.format("unable to inspect tmux session %s: %s", target.session_name, windows_output)
	end

	local window_exists = vim.iter(vim.split(windows.stdout or "", "\n", { trimempty = true })):any(function(window)
		return window == target.window_name
	end)
	if not window_exists then
		return string.format("tmux target %s was not created", format_tmux_target(target))
	end

	local panes, panes_output = run_system(
		{ "tmux", "list-panes", "-t", format_tmux_target(target), "-F", "#{pane_dead} #{pane_current_command}" },
		{ text = true }
	)
	if panes.code ~= 0 then
		return string.format("unable to inspect tmux target %s: %s", format_tmux_target(target), panes_output)
	end

	local pane_lines = vim.split(panes.stdout or "", "\n", { trimempty = true })
	if #pane_lines == 0 then
		return string.format("tmux target %s has no panes", format_tmux_target(target))
	end

	for _, line in ipairs(pane_lines) do
		if line == "0 opencode" then
			return string.format("opencode is still starting in tmux target %s", format_tmux_target(target))
		end
	end

	for _, line in ipairs(pane_lines) do
		if vim.startswith(line, "1 ") then
			return string.format("opencode pane exited in tmux target %s", format_tmux_target(target))
		end
	end

	return string.format(
		"tmux target %s exists, but its active pane command is %s instead of opencode",
		format_tmux_target(target),
		pane_lines[1]
	)
end

local function ensure_worktree_opencode_session(cwd)
	local branch = get_managed_worktree_branch(cwd)
	if branch == nil or branch == "" then
		return false, "directory is not a managed worktree"
	end

	local result = vim.system({ "zsh", "-ic", "gwtcs " .. vim.fn.shellescape(branch) }, { text = true, cwd = cwd })
		:wait()
	if result.code ~= 0 then
		return false, trim_output(result)
	end

	local target, _ = get_repo_tmux_target(cwd)
	return true, {
		kind = "worktree",
		label = branch,
		tmux_target = target,
	}
end

local function ensure_repo_opencode_session(cwd)
	local result = vim.system({ vim.fs.joinpath(vim.env.HOME, ".config", "tmux", "create_worktree_session.sh") }, { text = true, cwd = cwd })
		:wait()
	if result.code ~= 0 then
		return false, trim_output(result)
	end

	local target, _ = get_repo_tmux_target(cwd)
	return true, {
		kind = "repo",
		label = target and target.branch_name or cwd,
		tmux_target = target,
	}
end

local function ensure_opencode_session(cwd)
	local worktree_branch = get_managed_worktree_branch(cwd)
	if worktree_branch ~= nil and worktree_branch ~= "" then
		return ensure_worktree_opencode_session(cwd)
	end

	return ensure_repo_opencode_session(cwd)
end

local function server_matches_cwd(server_cwd, cwd)
	return server_cwd == cwd
end

local function select_best_server_for_cwd(servers, cwd)
	return vim.iter(servers):find(function(server)
		return server_matches_cwd(server.cwd, cwd)
	end)
end

local function is_absence_error(err)
	if type(err) ~= "string" then
		return false
	end

	return err:find("No `opencode` processes found", 1, true) ~= nil
		or err:find("No `opencode` servers found", 1, true) ~= nil
		or err:find("No `opencode` responding on port:", 1, true) ~= nil
end

local function wait_for_server(cwd, startup, opts, attempt)
	attempt = attempt or 1
	local max_attempts = 8
	local retry_delay_ms = 1000

	require("opencode.server")
		.get_all()
		:next(function(servers)
			local target_server = select_best_server_for_cwd(servers, cwd)
			if target_server ~= nil then
				connect_server(target_server)
				notify(
					string.format(
						"Started opencode session for %s and connected to %s",
						startup.label,
						format_server(target_server)
					),
					vim.log.levels.INFO
				)
				if opts.on_ready then
					opts.on_ready(target_server)
				end
				return
			end

			if attempt < max_attempts then
				vim.defer_fn(function()
					wait_for_server(cwd, startup, opts, attempt + 1)
				end, retry_delay_ms)
				return
			end

			local diagnosis = diagnose_tmux_target(cwd)
			local waited_seconds = attempt * retry_delay_ms / 1000
			notify(
				string.format(
					"Started tmux target %s for %s, but no opencode server registered for %s after %ds. %s",
					format_tmux_target(startup.tmux_target),
					startup.label,
					cwd,
					waited_seconds,
					diagnosis
				),
				vim.log.levels.WARN
			)
		end)
		:catch(function(err)
			if is_absence_error(err) then
				if attempt < max_attempts then
					vim.defer_fn(function()
						wait_for_server(cwd, startup, opts, attempt + 1)
					end, retry_delay_ms)
					return
				end

				local diagnosis = diagnose_tmux_target(cwd)
				local waited_seconds = attempt * retry_delay_ms / 1000
				notify(
					string.format(
						"Started tmux target %s for %s, but no opencode server registered for %s after %ds. %s",
						format_tmux_target(startup.tmux_target),
						startup.label,
						cwd,
						waited_seconds,
						diagnosis
					),
					vim.log.levels.WARN
				)
				return
			end

			notify(
				string.format(
					"Failed to inspect opencode servers while waiting for %s: %s",
					startup.label,
					err or "unknown error"
				),
				vim.log.levels.WARN
			)
		end)
end

function M.ensure_current_server(opts)
	opts = opts or {}
	local cwd = vim.fn.getcwd()
	local ensure_session = opts.ensure_session ~= false

	require("opencode.server")
		.get_all()
		:next(function(servers)
			local connected_server = require("opencode.events").connected_server
			local cached_server = known_servers_by_cwd[cwd]
			local override_server = connected_server or manual_override_server

			if manual_server_override and override_server ~= nil then
				local live_override_server = find_running_server(servers, override_server)
				if live_override_server ~= nil then
					if connected_server == nil or connected_server.port ~= live_override_server.port then
						connect_server(live_override_server)
					end
					if opts.on_ready then
						opts.on_ready(live_override_server)
					end
					return
				end

				clear_cached_server(cwd, override_server)
				override_server = nil
				connected_server = require("opencode.events").connected_server
			elseif manual_server_override then
				clear_manual_server_override()
			end

			if connected_server ~= nil and connected_server.cwd == cwd then
				local live_connected_server = find_running_server(servers, connected_server)
				if live_connected_server ~= nil then
					known_servers_by_cwd[cwd] = live_connected_server
					if opts.on_ready then
						opts.on_ready(live_connected_server)
					end
					return
				end

				clear_cached_server(cwd, connected_server)
				connected_server = nil
			end

			if cached_server ~= nil then
				local live_cached_server = find_running_server(servers, cached_server)
				if live_cached_server ~= nil then
					connect_server(live_cached_server)
					notify(string.format("Switched opencode connection to %s", format_server(live_cached_server)), vim.log.levels.INFO)
					if opts.on_ready then
						opts.on_ready(live_cached_server)
					end
					return
				end

				clear_cached_server(cwd, cached_server)
			end

			local target_server = select_best_server_for_cwd(servers, cwd)
			if target_server ~= nil then
				if connected_server == nil or connected_server.port ~= target_server.port then
					connect_server(target_server)
					notify(
						string.format("Switched opencode connection to %s", format_server(target_server)),
						vim.log.levels.INFO
					)
				end
				if opts.on_ready then
					opts.on_ready(target_server)
				end
				return
			end

			if not ensure_session then
				notify(string.format("No running opencode server matches %s", cwd), vim.log.levels.WARN)
				return
			end

			notify(string.format("No opencode server matches %s; starting a tmux-backed opencode session", cwd), vim.log.levels.INFO)

			local started, detail = ensure_opencode_session(cwd)
			if not started then
				notify(string.format("Unable to start tmux-backed opencode session for %s: %s", cwd, detail), vim.log.levels.WARN)
				return
			end

			notify(
				string.format(
					"Started tmux target %s for %s; waiting for the opencode server to register",
					format_tmux_target(detail.tmux_target),
					detail.label
				),
				vim.log.levels.INFO
			)
			wait_for_server(cwd, detail, opts)
		end)
		:catch(function(err)
			if is_absence_error(err) then
				if not ensure_session then
					notify(string.format("No running opencode server matches %s", cwd), vim.log.levels.WARN)
					return
				end

				notify(string.format("No opencode server matches %s; starting a tmux-backed opencode session", cwd), vim.log.levels.INFO)

				local started, detail = ensure_opencode_session(cwd)
				if not started then
					notify(string.format("Unable to start tmux-backed opencode session for %s: %s", cwd, detail), vim.log.levels.WARN)
					return
				end

				notify(
					string.format(
						"Started tmux target %s for %s; waiting for the opencode server to register",
						format_tmux_target(detail.tmux_target),
						detail.label
					),
					vim.log.levels.INFO
				)
				wait_for_server(cwd, detail, opts)
				return
			end

			notify(string.format("Failed to inspect opencode servers: %s", err or "unknown error"), vim.log.levels.WARN)
		end)
end

function M.select_server()
	return require("opencode")
		.select_server()
		:next(function(server)
			manual_server_override = true
			manual_override_server = server
			require("opencode.events").connected_server = server
			known_servers_by_cwd[server.cwd] = server
		end)
end

function M.reset_manual_server_override()
	clear_manual_server_override()
end

return M
