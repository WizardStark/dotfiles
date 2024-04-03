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
--
---@class Mark
---@field workspace_name string
---@field session_name string
---@field path string
---@field pos number[]

---@class State
---@field workspaces Workspace[]
---@field marks Mark[]
---@field toggleterms table
---@field term_count number
---@field current_workspace Workspace
---@field last_workspace Workspace | nil
---@field current_session Session
---@field last_session Session | nil

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

---@type State
local state = {
	marks = {},
	workspaces = {},
	toggleterms = {},
	term_count = 0,
	current_workspace = M.default_workspace,
	last_workspace = nil,
	current_session = M.default_workspace.sessions[0],
	last_session = nil,
}

function M.get()
	return state
end

return M
