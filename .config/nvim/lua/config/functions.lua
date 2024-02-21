return {
	require("legendary").funcs({
		{
			function()
				local ok, _ = pcall(dofile, vim.fn.expand("$HOME/.config/lcl/init.lua"))
				if not ok then
					vim.fn.system(
						"mkdir -p ~/.config/lcl && touch ~/.config/lcl/init.lua && echo M={} return M >> ~/.config/lcl/init.lua"
					)
				end
			end,
			description = "Create local config file if it does not exist",
		},
	}),
}
