local prefixifier = require("utils").prefixifier
local P = require("utils").PREFIXES
local funcs = require("legendary").funcs

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
		require("workspaces").load_workspaces,
		prefix = P.work,
		description = "Load workspaces",
	},
})
return {}
