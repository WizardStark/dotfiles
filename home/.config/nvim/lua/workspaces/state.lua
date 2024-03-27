local M = {}

---@class Workspace
---@field name string
---@field sessions Session[]
---@field current_session_name string
---@field last_session_name string | nil

---@class Session
---@field name string
---@field dir string
---@field last_file string | nil
---@field last_file_line number | nil
---@field toggled_types string[]
---@field breakpoints table

---@type Workspace
M.default_workspace = {
	current_session_name = "nvim",
	last_session_name = nil,
	name = "dotfiles",
	sessions = {
		{
			name = "nvim",
			dir = "~/dotfiles/home/.config/nvim",
			toggled_types = {},
			breakpoints = {},
		},
	},
}

M.default_workspace_data = {
	current_workspace_name = "dotfiles",
	last_workspace_name = nil,
	---@type Workspace[]
	workspaces = { M.default_workspace },
}

local state = {
	---@type Workspace[]
	workspaces = {},
	---@type table
	toggleterms = {},
	---@type number
	term_count = 0,
	---@type Workspace
	current_workspace = M.default_workspace,
	---@type Workspace | nil
	last_workspace = nil,
	---@type Session
	current_session = M.default_workspace.sessions[0],
	---@type Session | nil
	last_session = nil,
}

function M.set(key, value)
	state[key] = value
end

function M.set_sub(primary_key, sub_key, value)
	state[primary_key][sub_key] = value
end

function M.get()
	return state
end

return M
