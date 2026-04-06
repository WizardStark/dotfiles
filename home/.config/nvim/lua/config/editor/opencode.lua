local M = {}
local known_servers_by_cwd = {}

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

local function connect_server(server)
	require("opencode.events").connect(server)
	-- `opencode.nvim` only sets this after the first SSE arrives, which is too late
	-- for immediate prompt/action usage after switching servers.
	require("opencode.events").connected_server = server
	known_servers_by_cwd[server.cwd] = server
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
		local branch = vim.fs.basename(top_level_dir)
		if branch ~= nil and branch ~= "" then
			return branch
		end
		return nil
	end

	return top_level_dir:sub(#prefix + 1)
end

local function ensure_worktree_opencode_session(cwd)
	local branch = get_managed_worktree_branch(cwd)
	if branch == nil or branch == "" then
		return false, "directory is not a managed worktree"
	end

	local result = vim.system({ "zsh", "-ic", "gwtcs " .. vim.fn.shellescape(branch) }, { text = true, cwd = cwd })
		:wait()
	if result.code ~= 0 then
		return false, vim.trim(result.stderr ~= "" and result.stderr or result.stdout)
	end

	return true, branch
end

local function server_matches_cwd(server_cwd, cwd)
	return server_cwd == cwd
end

local function select_best_server_for_cwd(servers, cwd)
	return vim.iter(servers):find(function(server)
		return server_matches_cwd(server.cwd, cwd)
	end)
end

function M.ensure_current_server(opts)
	opts = opts or {}
	local cwd = vim.fn.getcwd()
	local connected_server = require("opencode.events").connected_server
	local ensure_session = opts.ensure_session ~= false
	local cached_server = known_servers_by_cwd[cwd]

	if connected_server ~= nil and connected_server.cwd == cwd then
		known_servers_by_cwd[cwd] = connected_server
		if opts.on_ready then
			opts.on_ready(connected_server)
		end
		return
	end

	if cached_server ~= nil then
		connect_server(cached_server)
		notify(string.format("Switched opencode connection to %s", format_server(cached_server)), vim.log.levels.INFO)
		if opts.on_ready then
			opts.on_ready(cached_server)
		end
		return
	end

	require("opencode.server")
		.get_all()
		:next(function(servers)
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
				notify(string.format("No opencode server matches %s", cwd), vim.log.levels.WARN)
				return
			end

			notify(string.format("Starting opencode session for %s...", cwd), vim.log.levels.INFO)

			local started, detail = ensure_worktree_opencode_session(cwd)
			if not started then
				notify(string.format("Unable to start opencode session: %s", detail), vim.log.levels.WARN)
				return
			end

			vim.defer_fn(function()
				require("opencode.server")
					.get_all()
					:next(function(retry_servers)
						local retry_target = select_best_server_for_cwd(retry_servers, cwd)
						if retry_target == nil then
							notify(
								string.format(
									"Started worktree session for %s but no opencode server was found",
									detail
								),
								vim.log.levels.WARN
							)
							return
						end

						connect_server(retry_target)
						notify(
							string.format(
								"Started opencode session for %s and switched connection to %s",
								detail,
								format_server(retry_target)
							),
							vim.log.levels.INFO
						)
						if opts.on_ready then
							opts.on_ready(retry_target)
						end
					end)
					:catch(function(err)
						notify(
							string.format("Failed to inspect opencode servers: %s", err or "unknown error"),
							vim.log.levels.WARN
						)
					end)
			end, 2000)
		end)
		:catch(function(err)
			notify(string.format("Failed to inspect opencode servers: %s", err or "unknown error"), vim.log.levels.WARN)
		end)
end

return M
