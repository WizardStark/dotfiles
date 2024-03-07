local prefixifier = require("utils").prefixifier
local P = require("utils").PREFIXES
local funcs = require("legendary").funcs

---@param on_success fun(name: string, dir: string)
---@param on_cancel fun()
local function input_new_session(on_success, on_cancel)
	vim.ui.input({
		prompt = "New session name",
		default = "",
		kind = "tabline",
	}, function(name_input)
		if name_input then
			vim.ui.input({
				prompt = "New session directory",
				default = "",
				completion = "dir",
				kind = "tabline",
			}, function(dir_input)
				if dir_input then
					on_success(name_input, dir_input)
				else
					on_cancel()
				end
			end)
		else
			on_cancel()
		end
	end)
end

prefixifier(funcs)({
	{
		function()
			local ok, _ = pcall(dofile, vim.fn.expand("$HOME/.config/lcl/lua/init.lua"))
			if not ok then
				vim.fn.system(
					"mkdir -p ~/.config/lcl/lua && touch ~/.config/lcl/lua/init.lua && echo M={} return M >> ~/.config/lcl/lua/init.lua"
				)
				vim.notify("Please close and reopen vim")
			else
				vim.notify("Local config already exists")
			end
		end,
		prefix = P.misc,
		description = "Create local config file if it does not exist",
	},
	{
		function()
			local ok, _ = pcall(dofile, vim.fn.expand("$HOME/.config/lcl/lua/init.lua"))
			if not ok then
				vim.cmd.e("~/.config/lcl/lua/init.lua")
			else
				vim.notify("Local config does not exist")
			end
		end,
		prefix = P.misc,
		description = "Edit local config",
	},
	{
		function()
			require("gitsigns").stage_buffer()
		end,
		prefix = P.git,
		description = "Git stage buffer",
	},
	{
		function()
			require("gitsigns").reset_buffer()
		end,
		prefix = P.git,
		description = "Git reset buffer",
	},
	{
		function()
			require("gitsigns").undo_stage_hunk()
		end,
		prefix = P.git,
		description = "Git undo stage hunk",
	},
	{
		function()
			require("gitsigns").stage_hunk(require("utils").get_visual_selection_lines())
		end,
		prefix = P.git,
		description = "Git stage visual selection",
	},
	{
		function()
			require("gitsigns").reset_hunk(require("utils").get_visual_selection_lines())
		end,
		prefix = P.git,
		description = "Git reset visual selection",
	},
	{
		function()
			vim.ui.input({
				prompt = "Session number",
				default = "",
				kind = "tabline",
			}, function(idx_input)
				if idx_input then
					require("workspaces").switch_session_by_index(idx_input)
				else
					vim.notify("Switch cancelled")
					return
				end
			end)
		end,
		prefix = P.work,
		description = "Switch session",
	},
	{
		function()
			input_new_session(function(name, dir)
				require("workspaces").create_session(name, dir)
			end, function()
				vim.notify("Creation cancelled")
			end)
		end,
		prefix = P.work,
		description = "Create session",
	},
	{
		function()
			vim.ui.input({
				prompt = "New name",
				default = require("workspaces").get_current_workspace().current_session,
				kind = "tabline",
			}, function(input)
				if input then
					require("workspaces").rename_current_session(input)
				else
					vim.notify("Rename cancelled")
				end
			end)
		end,
		prefix = P.work,
		description = "Rename session",
	},
	{
		function()
			vim.ui.input({
				prompt = "New workspace name",
				default = "",
				kind = "tabline",
			}, function(input)
				local on_cancel = function()
					vim.notify("Creation cancelled")
				end

				if input then
					input_new_session(function(session_name, dir)
						require("workspaces").create_workspace(input, session_name, dir)
					end, on_cancel)
				else
					on_cancel()
				end
			end)
		end,
		prefix = P.work,
		description = "Create workspace",
	},
	{
		require("workspaces").load_workspaces,
		prefix = P.work,
		description = "Load workspaces",
	},
	{
		function()
			vim.ui.input({
				prompt = "New name",
				default = require("workspaces").get_current_workspace().name,
				kind = "tabline",
			}, function(input)
				if input then
					require("workspaces").rename_current_workspace(input)
				else
					vim.notify("Rename cancelled")
				end
			end)
		end,
		prefix = P.work,
		description = "Rename workspace",
	},
})
return {}
