local M = {}

local state = require("workspaces.state")
local Path = require("plenary.path")

M.icons = {
	last = "",
	cur = "",
}

local GIT_DIR_CACHE_TTL_MS = 2000
local WORKTREE_CACHE_TTL_MS = 2000
local git_common_dir_cache = {}
local git_toplevel_cache = {}
local worktree_cache = {}

local function cache_is_fresh(entry, ttl_ms)
	return entry ~= nil and (vim.uv.now() - entry.ts) < ttl_ms
end

---@param workspace Workspace
---@param session_name string
---@return WorkspaceSession | nil
function M.find_session(workspace, session_name)
	for _, v in ipairs(workspace.sessions) do
		if v.name == session_name then
			return v
		end
	end

	return nil
end

---@param session WorkspaceSession
---@param target_name string | nil
---@return WorkspaceTarget | nil
function M.find_target(session, target_name)
	if target_name == nil then
		return nil
	end

	for _, target in ipairs(session.targets or {}) do
		if target.name == target_name then
			return target
		end
	end

	return nil
end

---@param session WorkspaceSession
---@param target WorkspaceTarget
---@return number | nil
function M.find_target_index(session, target)
	for i, value in ipairs(session.targets or {}) do
		if value.name == target.name then
			return i
		end
	end

	return nil
end

---@param workspace Workspace
---@param session WorkspaceSession
---@return number | nil
function M.find_session_index(workspace, session)
	for i, v in ipairs(workspace.sessions) do
		if v.name == session.name then
			return i
		end
	end

	return nil
end

---@param workspace_name string
---@return Workspace | nil
function M.find_workspace(workspace_name)
	for _, v in ipairs(state.get().workspaces) do
		if v.name == workspace_name then
			return v
		end
	end

	return nil
end

---@param workspace_name string
---@return number | nil
function M.find_workspace_index(workspace_name)
	for i, v in ipairs(state.get().workspaces) do
		if v.name == workspace_name then
			return i
		end
	end

	return nil
end

---Verifies is a given session name is valid
---@param name string
---@return boolean
function M.verify_session_name(name)
	if name == nil or name == "" then
		vim.notify("Session names cannot be nil or empty", vim.log.levels.ERROR)
		return false
	end

	return true
end

---Verifies is a given workspace name is valid
---@param name string
---@return boolean
function M.verify_workspace_name(name)
	if name == nil or name == "" then
		vim.notify("Workspace names cannot be nil or empty", vim.log.levels.ERROR)
		return false
	end

	return true
end

---@param name string
---@return string
function M.sanitize_name(name)
	return name:gsub(" ", "-"):gsub("[^%w%._%-]", "-")
end

---@param dir string
---@return string
function M.normalize_dir(dir)
	return vim.fn.fnamemodify(vim.fn.expand(dir), ":p"):gsub(Path.path.sep .. "$", "")
end

---@param session WorkspaceSession
---@return WorkspaceTarget
function M.get_main_target(session)
	local target = M.find_target(session, "main")
	if target ~= nil then
		return target
	end

	---@type WorkspaceTarget
	target = {
		name = "main",
		kind = "directory",
		dir = session.dir,
		branch = nil,
		last_file = nil,
		last_file_line = nil,
		toggled_types = {},
		breakpoints = {},
		toggleterms = {},
	}

	session.targets = session.targets or {}
	table.insert(session.targets, 1, target)
	session.current_target_name = session.current_target_name or target.name

	return target
end

---@param session WorkspaceSession
---@return WorkspaceTarget
function M.get_current_target(session)
	local target = M.find_target(session, session.current_target_name)
	if target ~= nil then
		return target
	end

	target = M.get_main_target(session)
	session.current_target_name = target.name
	return target
end

---@param session WorkspaceSession
---@return string
function M.resolve_session_dir(session)
	return M.get_current_target(session).dir
end

---@param dir string
---@return boolean
function M.is_git_dir(dir)
	local git_path = Path:new(M.normalize_dir(dir)):joinpath(".git")
	return git_path:exists()
end

---@param dir string
---@return string | nil
function M.get_git_common_dir(dir)
	local normalized_dir = M.normalize_dir(dir)
	local cached = git_common_dir_cache[normalized_dir]
	if cache_is_fresh(cached, GIT_DIR_CACHE_TTL_MS) then
		return cached.value
	end

	local output = vim.fn.system({ "git", "-C", normalized_dir, "rev-parse", "--path-format=absolute", "--git-common-dir" })
	if vim.v.shell_error ~= 0 then
		git_common_dir_cache[normalized_dir] = { ts = vim.uv.now(), value = nil }
		return nil
	end

	output = vim.trim(output)
	if output == "" then
		git_common_dir_cache[normalized_dir] = { ts = vim.uv.now(), value = nil }
		return nil
	end

	git_common_dir_cache[normalized_dir] = { ts = vim.uv.now(), value = output }
	return output
end

---@param dir string
---@return string | nil
function M.get_git_toplevel(dir)
	local normalized_dir = M.normalize_dir(dir)
	local cached = git_toplevel_cache[normalized_dir]
	if cache_is_fresh(cached, GIT_DIR_CACHE_TTL_MS) then
		return cached.value
	end

	local output = vim.fn.system({ "git", "-C", normalized_dir, "rev-parse", "--show-toplevel" })
	if vim.v.shell_error ~= 0 then
		git_toplevel_cache[normalized_dir] = { ts = vim.uv.now(), value = nil }
		return nil
	end

	output = vim.trim(output)
	if output == "" then
		git_toplevel_cache[normalized_dir] = { ts = vim.uv.now(), value = nil }
		return nil
	end

	local normalized_output = M.normalize_dir(output)
	local entry = { ts = vim.uv.now(), value = normalized_output }
	git_toplevel_cache[normalized_dir] = entry
	git_toplevel_cache[normalized_output] = entry
	return normalized_output
end

---@param dir string
---@return WorkspaceTarget[]
function M.list_git_targets(dir)
	local normalized_dir = M.normalize_dir(dir)
	local main_target = {
		name = "main",
		kind = "directory",
		dir = normalized_dir,
		branch = nil,
		last_file = nil,
		last_file_line = nil,
		toggled_types = {},
		breakpoints = {},
		toggleterms = {},
	}

	local repo_root = M.get_git_toplevel(normalized_dir)
	if repo_root == nil then
		return { main_target }
	end

	local relative_dir = vim.fs.relpath(repo_root, normalized_dir)
	if relative_dir == nil then
		relative_dir = ""
	end

	local cached = worktree_cache[repo_root]
	local worktree_entries = nil
	if cache_is_fresh(cached, WORKTREE_CACHE_TTL_MS) then
		worktree_entries = cached.entries
	else
		local output = vim.fn.system({ "git", "-C", repo_root, "worktree", "list", "--porcelain" })
		if vim.v.shell_error ~= 0 then
			return { main_target }
		end

		worktree_entries = {}
		local current = nil
		for line in output:gmatch("[^\r\n]+") do
			if vim.startswith(line, "worktree ") then
				if current ~= nil then
					table.insert(worktree_entries, current)
				end
				current = {
					root = M.normalize_dir(line:sub(#"worktree " + 1)),
					branch = nil,
					name = "main",
				}
			elseif current ~= nil and vim.startswith(line, "branch refs/heads/") then
				local branch = line:sub(#"branch refs/heads/" + 1)
				current.branch = branch
				current.name = branch == "" and current.name or branch
			end
		end
		if current ~= nil then
			table.insert(worktree_entries, current)
		end
		worktree_cache[repo_root] = { ts = vim.uv.now(), entries = worktree_entries }
	end

	local targets = {}
	for _, entry in ipairs(worktree_entries) do
		local target = {
			name = entry.name,
			kind = "git_worktree",
			dir = relative_dir ~= "" and Path:new(entry.root):joinpath(relative_dir).filename or entry.root,
			branch = entry.branch,
			last_file = nil,
			last_file_line = nil,
			toggled_types = {},
			breakpoints = {},
			toggleterms = {},
		}
		if entry.root == repo_root then
			target.name = "main"
			target.kind = "directory"
			target.branch = nil
		elseif target.name == "main" then
			target.name = vim.fn.fnamemodify(entry.root, ":t")
		end
		if target.kind == "directory" then
			main_target = target
		end
		table.insert(targets, target)
	end

	table.sort(targets, function(a, b)
		if a.name == "main" then
			return true
		elseif b.name == "main" then
			return false
		end
		return a.name < b.name
	end)

	return #targets > 0 and targets or { main_target }
end

---@param session WorkspaceSession
---@param discovered_targets WorkspaceTarget[]
---@return WorkspaceTarget[]
---@return boolean
---@return boolean
function M.merge_session_targets(session, discovered_targets)
	session.targets = session.targets or {}

	local previous_targets = session.targets
	local previous_current_target = M.find_target(session, session.current_target_name)
	local previous_last_target = M.find_target(session, session.last_target_name)
	local previous_main_dir = session.dir
	local next_targets = {}
	local matched_targets = {}
	local matched_current_target = nil
	local matched_last_target = nil
	local changed = false

	for _, discovered in ipairs(discovered_targets) do
		local existing = nil

		for _, target in ipairs(previous_targets) do
			if M.normalize_dir(target.dir) == M.normalize_dir(discovered.dir) or target.name == discovered.name then
				existing = target
				matched_targets[target] = true
				break
			end
		end

		if existing ~= nil then
			if
				existing.name ~= discovered.name
				or existing.kind ~= discovered.kind
				or M.normalize_dir(existing.dir) ~= M.normalize_dir(discovered.dir)
				or existing.branch ~= discovered.branch
			then
				changed = true
			end

			existing.name = discovered.name
			existing.kind = discovered.kind
			existing.dir = discovered.dir
			existing.branch = discovered.branch
			existing.toggled_types = existing.toggled_types or {}
			existing.breakpoints = existing.breakpoints or {}
			existing.toggleterms = existing.toggleterms or {}
			table.insert(next_targets, existing)

			if existing == previous_current_target then
				matched_current_target = existing
			end

			if existing == previous_last_target then
				matched_last_target = existing
			end
		else
			changed = true
			discovered.toggled_types = discovered.toggled_types or {}
			discovered.breakpoints = discovered.breakpoints or {}
			discovered.toggleterms = discovered.toggleterms or {}
			table.insert(next_targets, discovered)
		end
	end

	local removed_targets = {}
	for _, target in ipairs(previous_targets) do
		if not matched_targets[target] then
			changed = true
			table.insert(removed_targets, target)
		end
	end

	session.targets = next_targets
	local main_target = M.get_main_target(session)
	session.dir = main_target.dir
	if previous_main_dir ~= session.dir then
		changed = true
	end

	local previous_current_target_name = session.current_target_name
	if matched_current_target ~= nil then
		session.current_target_name = matched_current_target.name
	else
		session.current_target_name = main_target.name
	end
	if previous_current_target_name ~= session.current_target_name then
		changed = true
	end

	local previous_last_target_name = session.last_target_name
	if matched_last_target ~= nil and matched_last_target ~= matched_current_target then
		session.last_target_name = matched_last_target.name
	else
		session.last_target_name = nil
	end
	if previous_last_target_name ~= session.last_target_name then
		changed = true
	end

	return removed_targets, previous_current_target ~= nil and matched_current_target == nil, changed
end

return M
