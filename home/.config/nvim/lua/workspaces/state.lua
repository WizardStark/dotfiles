local M = {}

---@class Workspace
---@field name string
---@field sessions WorkspaceSession[]
---@field current_session_name string
---@field last_session_name string | nil

---@class WorkspaceSession
---@field name string
---@field dir string
---@field last_file string | nil
---@field last_file_line number | nil
---@field toggled_types string[]
---@field breakpoints table
---@field toggleterms SessionTerminal[]

---@class Mark
---@field name string
---@field display_name string | nil
---@field workspace_name string
---@field session_name string
---@field path string
---@field pos number[]

---@class SessionTerminal
---@field term_direction string
---@field size number
---@field visible boolean
---@field global_id number
---@field local_id number
---@field term_pos string

---@class State
---@field workspaces Workspace[]
---@field marks Mark[]
---@field term_count number
---@field current_workspace Workspace
---@field last_workspace Workspace | nil
---@field current_session WorkspaceSession
---@field last_session WorkspaceSession | nil

---@type Workspace
M.default_workspace = {
	current_session_name = "nvim",
	last_session_name = nil,
	name = "dotfiles",
	sessions = {
		{
			name = "nvim",
			dir = vim.fn.stdpath("config") --[[@as string]],
			toggled_types = {},
			breakpoints = {},
			toggleterms = {},
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
