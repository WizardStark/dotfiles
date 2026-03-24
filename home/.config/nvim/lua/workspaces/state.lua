local M = {}

---@class Workspace
---@field name string
---@field sessions WorkspaceSession[]
---@field current_session_name string
---@field last_session_name string | nil

---@class WorkspaceSession
---@field name string
---@field dir string
---@field current_target_name string
---@field last_target_name string | nil
---@field targets WorkspaceTarget[]

---@class WorkspaceTarget
---@field name string
---@field kind string
---@field dir string
---@field branch string | nil
---@field last_file string | nil
---@field last_file_line number | nil
---@field toggled_types string[]
---@field breakpoints table
---@field toggleterms SessionTerminal[]

---@class SessionTerminal
---@field term_direction string
---@field size number
---@field active boolean
---@field should_display boolean
---@field global_id number
---@field local_id number
---@field term_pos string

---@class State
---@field workspaces Workspace[]
---@field term_count number
---@field current_workspace Workspace
---@field last_workspace Workspace | nil
---@field current_session WorkspaceSession
---@field last_session WorkspaceSession | nil
---@field current_target WorkspaceTarget
---@field last_target WorkspaceTarget | nil

---@type Workspace
M.default_workspace = {
	current_session_name = "nvim",
	last_session_name = nil,
	name = "dotfiles",
	sessions = {
		{
			name = "nvim",
			dir = vim.fn.stdpath("config") --[[@as string]],
			current_target_name = "main",
			last_target_name = nil,
			targets = {
				{
					name = "main",
					kind = "directory",
					dir = vim.fn.stdpath("config") --[[@as string]],
					branch = nil,
					last_file = nil,
					last_file_line = nil,
					toggled_types = {},
					breakpoints = {},
					toggleterms = {},
				},
			},
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
	workspaces = {},
	term_count = 0,
	current_workspace = M.default_workspace,
	last_workspace = nil,
	current_session = M.default_workspace.sessions[1],
	last_session = nil,
	current_target = M.default_workspace.sessions[1].targets[1],
	last_target = nil,
}

function M.get()
	return state
end

return M
