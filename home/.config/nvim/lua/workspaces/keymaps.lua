M = {}
local P = require("user.utils").PREFIXES
local mappings = {
	{
		mode = { "n" },
		keys = "<leader><C-\\>",
		callback = function()
			require("workspaces.toggleterms").toggle_active_terms(true)
		end,
		prefix = P.term,
		description = "Toggle all visible terminals",
	},
	{
		mode = { "n" },
		keys = "<leader><C-]>",
		callback = function()
			require("workspaces.toggleterms").toggle_active_terms(true)
		end,
		prefix = P.term,
		description = "Toggle all visible terminals",
	},
	{
		mode = { "n" },
		keys = "<leader><C-->",
		callback = function()
			require("workspaces.toggleterms").toggle_active_terms(true)
		end,
		prefix = P.term,
		description = "Toggle all visible terminals",
	},
	{
		mode = { "n" },
		keys = "<leader>sn",
		callback = function()
			require("workspaces.workspaces").next_session()
		end,
		prefix = P.work,
		description = "Next session",
	},
	{
		mode = { "n" },
		keys = "<leader>sp",
		callback = function()
			require("workspaces.workspaces").previous_session()
		end,
		prefix = P.work,
		description = "Previous session",
	},
	{
		mode = { "n" },
		keys = "<leader>z",
		callback = function()
			require("workspaces.workspaces").alternate_session()
		end,
		prefix = P.work,
		description = "Alternate session",
	},
	{
		mode = { "n" },
		keys = "<leader>sz",
		callback = function()
			require("workspaces.workspaces").alternate_workspace()
		end,
		prefix = P.work,
		description = "Alternate workspace",
	},
	{
		mode = { "n" },
		keys = "<leader>sa",
		callback = function()
			require("workspaces.ui").pick_session()
		end,
		prefix = P.work,
		description = "Pick session",
	},
	{
		mode = { "n" },
		keys = "<leader>scd",
		callback = function()
			require("workspaces.ui").change_current_session_directory_input()
		end,
		prefix = P.work,
		description = "Change session directory",
	},
	{
		mode = { "n" },
		keys = "\\",
		callback = function()
			require("workspaces.workspaces").switch_session_by_index(vim.v.count1)
		end,
		prefix = P.work,
		description = "Switch session by index",
	},
	{
		mode = { "n" },
		keys = "<leader>sw",
		callback = function()
			require("workspaces.ui").pick_workspace()
		end,
		prefix = P.work,
		description = "Pick workspace",
	},
	{
		mode = { "n" },
		keys = "<leader>t",
		callback = function()
			require("workspaces.ui").pick_mark()
		end,
		prefix = P.work,
		description = "Find mark",
	},
	{
		mode = { "n" },
		keys = "<leader>m",
		callback = function()
			require("workspaces.marks").toggle_mark()
		end,
		prefix = P.work,
		description = "Toggle mark",
	},
	{
		mode = { "n" },
		keys = "<leader>scs",
		callback = function()
			require("workspaces.ui").create_session_input()
		end,
		prefix = P.work,
		description = "Create session",
	},
	{
		mode = { "n" },
		keys = "<leader>srs",
		callback = function()
			require("workspaces.ui").rename_current_session_input()
		end,
		prefix = P.work,
		description = "Rename session",
	},
	{
		mode = { "n" },
		keys = "<leader>scw",
		callback = function()
			require("workspaces.ui").create_workspace_input()
		end,
		prefix = P.work,
		description = "Create workspace",
	},
	{
		mode = { "n" },
		keys = "<leader>srw",
		callback = function()
			require("workspaces.ui").rename_current_workspace_input()
		end,
		prefix = P.work,
		description = "Rename workspace",
	},
	{
		mode = { "n" },
		keys = "<leader>sds",
		callback = function()
			require("workspaces.ui").delete_session_input()
		end,
		prefix = P.work,
		description = "Delete session",
	},
	{
		mode = { "n" },
		keys = "<leader>sdw",
		callback = function()
			require("workspaces.ui").delete_workspace_input()
		end,
		prefix = P.work,
		description = "Delete workspace",
	},
}

function M.setup_keymaps()
	local prefixifier = require("user.utils").prefixifier
	local keymaps = require("user.utils").make_keymaps
	prefixifier(keymaps)(mappings)
end

return M
